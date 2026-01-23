/**
 * Unit tests to cover:
 * -TransferEmploymentsInvocable
 * -BatchableUpsertSObject
 * -SaveResultInvocable
 * 
 * @author Jenny Blomberg
 * @since 2023-02-23
 */
@isTest
public with sharing class TransferEmploymentsInvocableTest {

    @TestSetup
    static void makeData(){
        TestDataFactorySetupParams params = new TestDataFactorySetupParams();
        params.numberOfAccounts = 10;
        params.numberOfWorkplaceAccounts = 2;
        params.addEmploymentsToMembers = true;

        TestDataFactory.setupBasicTestData();
        TestDataFactory.setupTestData(params);
    }

    @isTest
    static void TransferEmploymentsInvocableTest_MoveExisting() {

        List<Account> workplaces = [SELECT Id, (SELECT Id FROM BusinessEmployments__r) FROM Account WHERE RecordTypeName__c = 'Workplace'];
        Id oldWorkplaceId;
        Id newWorkplaceId;
        for(Account workplace: workplaces){
            if(workplace.BusinessEmployments__r.size() > 0){
                oldWorkplaceId = workplace.Id;
                System.debug('Old');
            }
            if(workplace.BusinessEmployments__r.size() == 0){
                newWorkplaceId = workplace.Id;
                System.debug('New');
            }
        }

        List<TransferEmploymentsInvocable.Request> requestList = new List<TransferEmploymentsInvocable.Request>();
        TransferEmploymentsInvocable.Request req = new TransferEmploymentsInvocable.Request();
        req.oldWorkPlaceId = oldWorkplaceId;
        req.newWorkPlaceId = newWorkplaceId;
        req.moveExisting = true;

        requestList.add(req);

        Test.startTest();
        List<TransferEmploymentsInvocable.Result> results = TransferEmploymentsInvocable.TransferEmploymentsInvocable(requestList);
        Test.stopTest();

        Integer expected = 0;
        Integer actual = [SELECT Id FROM Employment__c WHERE Workplace__c =: oldWorkplaceId].size();

        System.assertEquals(expected, actual);

        expected = 10; 
        actual = [SELECT Id FROM Employment__c WHERE Workplace__c =: newWorkplaceId].size();

        System.assertEquals(expected, actual);
    }

    @isTest
    static void TransferEmploymentsInvocableTest_CreateNew() {

        List<Account> workplaces = [SELECT Id, (SELECT Id FROM BusinessEmployments__r) FROM Account WHERE RecordTypeName__c = 'Workplace'];
        Id oldWorkplaceId;
        Id newWorkplaceId;
        for(Account workplace: workplaces){
            if(workplace.BusinessEmployments__r.size() > 0){
                oldWorkplaceId = workplace.Id;
                System.debug('Old');
            }
            if(workplace.BusinessEmployments__r.size() == 0){
                newWorkplaceId = workplace.Id;
                System.debug('New');
            }
        }

        List<TransferEmploymentsInvocable.Request> requestList = new List<TransferEmploymentsInvocable.Request>();
        TransferEmploymentsInvocable.Request req = new TransferEmploymentsInvocable.Request();
        req.oldWorkPlaceId = oldWorkplaceId;
        req.newWorkPlaceId = newWorkplaceId;
        req.moveExisting = false;
        req.StartDate = Date.today();

        requestList.add(req);

        Test.startTest();
        List<TransferEmploymentsInvocable.Result> results = TransferEmploymentsInvocable.TransferEmploymentsInvocable(requestList);
        Test.stopTest();

        Integer expected = 10;
        Integer actual = [SELECT Id FROM Employment__c WHERE Workplace__c =: oldWorkplaceId].size();

        System.assertEquals(expected, actual);

        expected = 10; 
        actual = [SELECT Id FROM Employment__c WHERE Workplace__c =: newWorkplaceId].size();

        System.assertEquals(expected, actual);
    }

    @isTest
    static void SaveResultInvocable_ErrorOnInsert() {

        List<Employment__c> employments = [SELECT Id, Person__c FROM Employment__c];
        
        SaveResultInvocable.Request req = new SaveResultInvocable.Request();
        req.records = employments;
        req.dmlOperationType = 'insert';

        List<SaveResultInvocable.Request> reqlist = new List<SaveResultInvocable.Request>();
        reqlist.add(req);
        Test.startTest();
        List<SaveResultInvocable.Result> results = SaveResultInvocable.SaveResultInvocable(reqlist);
        Test.stopTest();

        Integer expected = 10;
        Integer actual = results[0].errorMessages.size();

        System.assertEquals(expected, actual);
    }
}