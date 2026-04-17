public with sharing class NewBillectaAutogiroService {

    public class StartAutogiroBankChangeResponse {
        @AuraEnabled public String sessionToken;
        @AuraEnabled public String sessionId;
        @AuraEnabled public String accountLookupBaseUrl;
        @AuraEnabled public String clientScriptUrl;
        @AuraEnabled public Id autogiroChangeLogId;
    }

    @AuraEnabled
    public static StartAutogiroBankChangeResponse startAutogiroChange(
        Id accountId,
        String personalIdNumber
    ) {
        if (accountId == null) {
            throw new AuraHandledException('AccountId is required.');
        }

        Account pa = [
            SELECT Id, Name, IsPersonAccount, PersonContactId
            FROM Account
            WHERE Id = :accountId
            LIMIT 1
        ];

        if (!pa.IsPersonAccount) {
            throw new AuraHandledException('Record is not a Person Account.');
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
        response.clientScriptUrl = billectaResponse.clientScriptUrl;
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
        String bankName
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

        logRec.Status__c = 'Completed';
        logRec.Session_State__c = sessionState;
        logRec.Clearing_Number__c = clearingNo;
        logRec.Account_Number__c = accountNo;
        logRec.Bank_Code__c = bank;
        logRec.Bank_Name__c = bankName;
        logRec.Error_Message__c = null;
        logRec.Completed_At__c = System.now();

        update logRec;
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
}