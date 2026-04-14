public with sharing class NewBillectaBankAccountService {

    public class Config {
        public String baseEndpoint;
        public String creditorPublicId;
        public String secureToken;
        public String accountLookupBaseUrl;
        public String clientScriptUrl;
    }

    @TestVisible
    private static Config testConfig;

    private static Config getConfig() {
        if (Test.isRunningTest() && testConfig != null) {
            return testConfig;
        }

        Billecta_Settings__mdt cfg = Billecta_Settings__mdt.getInstance('Default');
        if (cfg == null) {
            throw new AuraHandledException('Billecta settings saknas.');
        }

        Config c = new Config();
        c.baseEndpoint = cfg.Base_Endpoint__c;
        c.creditorPublicId = cfg.Creditor_Public_Id__c;
        c.secureToken = cfg.Secure_Token__c;
        c.accountLookupBaseUrl = cfg.Account_Lookup_Base_Url__c;
        c.clientScriptUrl = cfg.Client_Script_Url__c;
        return c;
    }

    private static void validateConfig(Config cfg) {
        if (cfg == null ||
            String.isBlank(cfg.baseEndpoint) ||
            String.isBlank(cfg.creditorPublicId) ||
            String.isBlank(cfg.secureToken) ||
            String.isBlank(cfg.accountLookupBaseUrl) ||
            String.isBlank(cfg.clientScriptUrl)) {
            throw new AuraHandledException('Billecta settings are not fully configured.');
        }
    }

    @AuraEnabled
    public static NewBillectaDtos.ClientConfigResponse createLookupSession(String personalIdNumber) {
        Config cfg = getConfig();
        validateConfig(cfg);

        HttpRequest req = new HttpRequest();
        req.setMethod('POST');
        req.setEndpoint(cfg.baseEndpoint + '/v1/bankAccount/InitiateRetrieval');
        req.setHeader('Content-Type', 'application/json');
        req.setHeader('Accept', 'application/json');
        req.setHeader('Authorization', buildSecureTokenHeader(cfg.secureToken));

        Map<String, Object> body = new Map<String, Object>{
            'CreditorPublicId' => cfg.creditorPublicId
        };
        if (String.isNotBlank(personalIdNumber)) {
            body.put('PersonalIdNumber', personalIdNumber);
        }
        req.setBody(JSON.serialize(body));

        Http http = new Http();
        HttpResponse res = http.send(req);

        if (res.getStatusCode() < 200 || res.getStatusCode() >= 300) {
            throw new AuraHandledException('Billecta initiate failed: ' + res.getBody());
        }

        Map<String, Object> parsed = (Map<String, Object>)JSON.deserializeUntyped(res.getBody());

        NewBillectaDtos.ClientConfigResponse response = new NewBillectaDtos.ClientConfigResponse();
        response.sessionToken = (String) parsed.get('SessionToken');
        response.sessionId = (String) parsed.get('SessionId');
        response.accountLookupBaseUrl = cfg.accountLookupBaseUrl;
        response.clientScriptUrl = cfg.clientScriptUrl;
        return response;
    }

    private static String buildSecureTokenHeader(String secureToken) {
        return 'SecureToken ' + EncodingUtil.base64Encode(Blob.valueOf(secureToken));
    }
}