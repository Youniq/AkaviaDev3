public with sharing class NewBillectaBankAccountService {

    @AuraEnabled
    public static BillectaDtos.ClientConfigResponse createLookupSession(String personalIdNumber) {
        Billecta_Settings__mdt cfg = Billecta_Settings__mdt.getInstance('Default');
        if (cfg == null) {
            throw new AuraHandledException('Billecta settings saknas. Skapa metadata-posten Default.');
        }
        if (String.isBlank(cfg.Base_Endpoint__c) ||
            String.isBlank(cfg.Creditor_Public_Id__c) ||
            String.isBlank(cfg.Secure_Token__c) ||
            String.isBlank(cfg.Account_Lookup_Base_Url__c) ||
            String.isBlank(cfg.Client_Script_Url__c)) {
            throw new AuraHandledException('Billecta settings är inte komplett konfigurerade.');
        }

        HttpRequest req = new HttpRequest();
        req.setMethod('POST');
        req.setEndpoint(cfg.Base_Endpoint__c + '/v1/bankAccount/InitiateRetrieval');
        req.setHeader('Content-Type', 'application/json');
        req.setHeader('Accept', 'application/json');
        req.setHeader('Authorization', buildSecureTokenHeader(cfg.Secure_Token__c));
        req.setTimeout(120000);

        Map<String, Object> body = new Map<String, Object>();
        body.put('CreditorPublicId', cfg.Creditor_Public_Id__c);
        if (String.isNotBlank(personalIdNumber)) {
            body.put('PersonalIdNumber', personalIdNumber);
        }

        req.setBody(JSON.serialize(body));

        Http http = new Http();
        HttpResponse res = http.send(req);

        if (res.getStatusCode() < 200 || res.getStatusCode() >= 300) {
            throw new AuraHandledException(
                'Billecta initiate failed. HTTP ' + res.getStatusCode() + ': ' + res.getBody()
            );
        }

        Map<String, Object> parsed = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());

        BillectaDtos.ClientConfigResponse response = new BillectaDtos.ClientConfigResponse();
        response.sessionToken = (String) parsed.get('SessionToken');
        response.sessionId = (String) parsed.get('SessionId');
        response.accountLookupBaseUrl = cfg.Account_Lookup_Base_Url__c;
        response.clientScriptUrl = cfg.Client_Script_Url__c;
        return response;
    }

    private static String buildSecureTokenHeader(String secureToken) {
        Blob tokenBlob = Blob.valueOf(secureToken);
        return 'SecureToken ' + EncodingUtil.base64Encode(tokenBlob);
    }
}