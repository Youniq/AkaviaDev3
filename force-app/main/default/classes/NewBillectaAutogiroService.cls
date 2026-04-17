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
            SELECT Id, Account__c, Status__c
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
            SELECT Id
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

    @AuraEnabled
    public static Id saveSuccessfulLookup(
        Id relatedRecordId,
        String sessionState,
        String clearingNo,
        String accountNo,
        String bank,
        String bankName
    ) {
        Billecta_Bank_Account_Result__c rec = new Billecta_Bank_Account_Result__c();
        rec.Related_Record_Id__c = relatedRecordId != null ? String.valueOf(relatedRecordId) : null;
        rec.Session_State__c = sessionState;
        rec.Clearing_Number__c = clearingNo;
        rec.Account_Number__c = accountNo;
        rec.Bank_Code__c = bank;
        rec.Bank_Name__c = bankName;
        rec.Status__c = 'Success';
        rec.Lookup_Timestamp__c = System.now();
        insert rec;
        return rec.Id;
    }

    @AuraEnabled
    public static Id saveFailedLookup(
        Id relatedRecordId,
        String status,
        String sessionState,
        String errorMessage
    ) {
        Billecta_Bank_Account_Result__c rec = new Billecta_Bank_Account_Result__c();
        rec.Related_Record_Id__c = relatedRecordId != null ? String.valueOf(relatedRecordId) : null;
        rec.Status__c = status;
        rec.Session_State__c = sessionState;
        rec.Error_Message__c = errorMessage;
        rec.Lookup_Timestamp__c = System.now();
        insert rec;
        return rec.Id;
    }
}