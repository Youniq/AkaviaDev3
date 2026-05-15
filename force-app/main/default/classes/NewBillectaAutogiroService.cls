public with sharing class NewBillectaAutogiroService {

    public class StartAutogiroBankChangeResponse {
        @AuraEnabled public String sessionToken;
        @AuraEnabled public String sessionId;
        @AuraEnabled public String accountLookupBaseUrl;
        @AuraEnabled public Id autogiroChangeLogId;
    }

    @AuraEnabled
    public static StartAutogiroBankChangeResponse startAutogiroChange(Id accountId) {
        if (accountId == null) {
            throw new AuraHandledException('AccountId is required.');
        }

        Account pa = [
            SELECT Id, Name, IsPersonAccount, SocialSecurityNumber__c
            FROM Account
            WHERE Id = :accountId
            LIMIT 1
        ];

        if (!pa.IsPersonAccount) {
            throw new AuraHandledException('Record is not a Person Account.');
        }

        String personalIdNumber = formatPersonalIdNumberForBillecta(pa.SocialSecurityNumber__c);

        if (String.isBlank(personalIdNumber)) {
            throw new AuraHandledException('Personnummer saknas på personkontot.');
        }

        NewBillectaDtos.ClientConfigResponse billectaResponse =
            NewBillectaBankAccountService.createLookupSession(personalIdNumber);

        Autogiro_Change_Log__c logRec = new Autogiro_Change_Log__c();
        logRec.Account__c = pa.Id;
        logRec.Status__c = 'Started';
        logRec.Billecta_Session_Id__c = billectaResponse.sessionId;
        logRec.Started_At__c = System.now();
        insert logRec;

        StartAutogiroBankChangeResponse response = new StartAutogiroBankChangeResponse();
        response.sessionToken = billectaResponse.sessionToken;
        response.sessionId = billectaResponse.sessionId;
        response.accountLookupBaseUrl = billectaResponse.accountLookupBaseUrl;
        response.autogiroChangeLogId = logRec.Id;
        return response;
    }

    @AuraEnabled
    public static Id completeAutogiroChange(
        Id autogiroChangeLogId,
        String sessionState,
        String clearingNo,
        String accountNo,
        String bank,
        String bankName,
        String autogiroJson
    ) {
        if (autogiroChangeLogId == null) {
            throw new AuraHandledException('autogiroChangeLogId is required.');
        }

        Autogiro_Change_Log__c logRec = [
            SELECT Id, Account__c, Status__c, Started_At__c
            FROM Autogiro_Change_Log__c
            WHERE Id = :autogiroChangeLogId
            LIMIT 1
        ];

        Map<String, Object> autogiro = parseAutogiroJson(autogiroJson);

        String finalAccountNo = getStringValue(autogiro, 'AccountNo', accountNo);
        String finalClearingNo = getStringValue(autogiro, 'ClearingNo', clearingNo);
        String finalBank = getStringValue(autogiro, 'PaymentServiceSupplier', bank);
        String finalBankName = String.isNotBlank(bankName) ? bankName : finalBank;
        String finalStage = getStringValue(autogiro, 'Stage', 'Completed');

        logRec.Status__c = 'Completed';
        logRec.Session_State__c = sessionState;
        logRec.Clearing_Number__c = finalClearingNo;
        logRec.Account_Number__c = finalAccountNo;
        logRec.Bank_Code__c = finalBank;
        logRec.Bank_Name__c = finalBankName;
        logRec.Error_Message__c = null;
        logRec.Completed_At__c = System.now();
        logRec.AutogiroJson__c = autogiroJson;

        Account acc = new Account(Id = logRec.Account__c);
        acc.AG_BankAccountNumber__c = finalAccountNo;
        acc.AG_BankClearingNumber__c = finalClearingNo;
        acc.AutogiroApprovalStatus__c = finalStage;

        // Resolve bank code to picklist value, check both label and api name
        String resolvedBank = resolvePicklistValue(
            Account.AutogiroBank__c,
            finalBank
        );

        if (resolvedBank != null) {
            acc.AutogiroBank__c = resolvedBank;
        }

        update new List<SObject>{ logRec, acc };

        return logRec.Id;
    }

    @AuraEnabled
    public static Id failAutogiroChange(
        Id autogiroChangeLogId,
        String status,
        String sessionState,
        String errorMessage
    ) {
        if (autogiroChangeLogId == null) {
            throw new AuraHandledException('autogiroChangeLogId is required.');
        }

        Autogiro_Change_Log__c logRec = [
            SELECT Id, Status__c, Started_At__c
            FROM Autogiro_Change_Log__c
            WHERE Id = :autogiroChangeLogId
            LIMIT 1
        ];

        logRec.Status__c = String.isBlank(status) ? 'Failed' : status;
        logRec.Session_State__c = sessionState;
        logRec.Error_Message__c = errorMessage;
        logRec.Completed_At__c = System.now();

        update logRec;
        return logRec.Id;
    }

    private static Map<String, Object> parseAutogiroJson(String autogiroJson) {
        if (String.isBlank(autogiroJson)) {
            return null;
        }

        Map<String, Object> parsed = (Map<String, Object>) JSON.deserializeUntyped(autogiroJson);

        if (parsed != null && parsed.containsKey('Autogiro')) {
            return (Map<String, Object>) parsed.get('Autogiro');
        }

        return parsed;
    }

    private static String getStringValue(Map<String, Object> values, String key, String fallback) {
        if (values == null || !values.containsKey(key) || values.get(key) == null) {
            return fallback;
        }

        return String.valueOf(values.get(key));
    }

    private static String formatPersonalIdNumberForBillecta(String value) {
        if (String.isBlank(value)) {
            return null;
        }

        String digits = value.replaceAll('[^0-9]', '');

        if (digits.length() == 12) {
            return digits.substring(2, 8) + '-' + digits.substring(8, 12);
        }

        if (digits.length() == 10) {
            return digits.substring(0, 6) + '-' + digits.substring(6, 10);
        }

        if (Pattern.matches('^[0-9]{6}-[0-9]{4}$', value.trim())) {
            return value.trim();
        }

        throw new AuraHandledException('Personnummer har fel format. Förväntat format är yyMMdd-xxxx.');
    }

    private static String resolvePicklistValue(
        Schema.SObjectField field,
        String incomingValue
    ) {
        if (String.isBlank(incomingValue)) {
            return null;
        }

        String normalizedIncoming = incomingValue.trim().toLowerCase();

        for (Schema.PicklistEntry entry : field.getDescribe().getPicklistValues()) {

            String value = entry.getValue();
            String label = entry.getLabel();

            if (
                (value != null && value.trim().toLowerCase() == normalizedIncoming) ||
                (label != null && label.trim().toLowerCase() == normalizedIncoming)
            ) {
                return value;
            }
        }

        return null;
    }
}