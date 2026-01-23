/**
 * @description       : 
 * @author            : Malin Nilsson (Stretch Customer AB)
 * @group             : 
 * @last modified on  : 2024-11-18
 * @last modified by  : Malin Nilsson (Stretch Customer AB)
**/
@isTest
public with sharing class ScheduleDeleteMcContactsTest {

    @TestSetup
    static void makeData(){
        TestDataFactorySetupParams params = new TestDataFactorySetupParams();
        params.numberOfAccounts = 2;     
           TestDataFactory.setupBasicTestData();
        TestDataFactory.setupTestData(params);    
    }

    @isTest
    static void testScheduleIt(){
        Test.startTest();

        String jobId = ScheduleDeleteMcContacts.scheduleIt();

        // Get the information from the CronTrigger API object
        CronTrigger ct = [
        SELECT Id, CronExpression, TimesTriggered, NextFireTime
        FROM CronTrigger
        WHERE id = :jobId
        ];

        // Verify the job has not run
        System.assertEquals(0, ct.TimesTriggered);
    }

    @isTest
    static void testRunJob(){

        List<Account> accs = [Select Id, syncWithMc__c, deletedFromMc__c from Account];

        for (Account acc : accs) {
            acc.syncWithMc__c = false;
            acc.deletedFromMc__c = false;
        }

        createDependentCustomSetting();

        Map<String, HttpResponse> responseByBodyContent = new Map<String, HttpResponse>();
        responseByBodyContent.put('callout:MarketingCloudInteg', MockHttpResponseGenerator.getTokenResponse());
        HttpResponse defaultResponse = getDeletedMcContactResponse();
        
        test.setMock(
                HttpCalloutMock.class,
                new EchoHttpMock(defaultResponse, responseByBodyContent)
        );

        Test.startTest();
        ScheduleDeleteMcContacts schedule = new ScheduleDeleteMcContacts();
        schedule.execute(null);
        Test.stopTest();

        for(Account a: [Select Id, deletedFromMc__c from Account]){
            System.Assert.isTrue(a.deletedFromMc__c, 'Account not deleted from MC');
        }
    }


     @isTest
    static void testFailRunJobFromBadCustomSetting(){

        List<Account> accs = [Select Id, syncWithMc__c, deletedFromMc__c from Account];

        for (Account acc : accs) {
            acc.syncWithMc__c = false;
            acc.deletedFromMc__c = false;
        }
        
    
        Test.startTest();
        ScheduleDeleteMcContacts schedule = new ScheduleDeleteMcContacts();
        schedule.execute(null);
        Test.stopTest();

        for(Callout__c c: [Select Id, Status__c, errorLog__c from Callout__c]){
            System.Assert.areEqual(c.status__c, 'Failed');
            System.debug('Callout errorLog: ' + c.errorLog__c);
        }
    }


    static void createDependentCustomSetting() {
        // Access the organization-wide custom setting record
        McSetting__c setting = McSetting__c.getOrgDefaults();

        // Check if the record is null (i.e., it doesn’t exist yet)
        if (setting == null) {
            setting = new McSetting__c();
        }

        setting.ContactDeleteLimit__c = 10;
        upsert setting;
    }


    static HttpResponse getDeletedMcContactResponse(){
        HttpResponse res = new HttpResponse();
        res.setHeader('Content-Type', 'application/json');
        res.setBody(
       '{"operationInitiated":true,"operationID":2,"requestServiceMessageID":"21d0d10d-a15a-413c-bc3e-8b43b185e551","resultMessages":[],"serviceMessageID":"acb87f67-ec49-42af-a0bb-987ac6451560"}'
        );
        res.setStatusCode(200);

        return res;
    }
}