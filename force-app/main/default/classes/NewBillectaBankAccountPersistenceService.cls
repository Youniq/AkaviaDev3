public with sharing class NewBillectaBankAccountPersistenceService {

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