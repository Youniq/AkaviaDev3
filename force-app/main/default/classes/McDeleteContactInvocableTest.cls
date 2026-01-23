/**
 * @description       : 
 * @author            : Malin Nilsson (Stretch Customer AB)
 * @group             : 
 * @last modified on  : 2024-11-18
 * @last modified by  : Malin Nilsson (Stretch Customer AB)
**/
@isTest
public with sharing class McDeleteContactInvocableTest {
    @TestSetup
    static void makeData(){
        TestDataFactorySetupParams params = new TestDataFactorySetupParams();
        params.numberOfAccounts = 1;       
        TestDataFactory.setupBasicTestData();
        TestDataFactory.setupTestData(params); 
    }


     @isTest
    static void testDeleteSingle(){

        List<Account> accs = [Select Id, syncWithMc__c, deletedFromMc__c from Account];

        for (Account acc : accs) {
            acc.syncWithMc__c = false;
            acc.deletedFromMc__c = false;
        }
        update accs;

        List<Id> accIds = new List<Id>();
        accIds.add(accs[0].Id);

        Map<String, HttpResponse> responseByBodyContent = new Map<String, HttpResponse>();
        responseByBodyContent.put('callout:MarketingCloudInteg', MockHttpResponseGenerator.getTokenResponse());
        HttpResponse defaultResponse = getDeletedMcContactResponse();
        
        test.setMock(
                HttpCalloutMock.class,
                new EchoHttpMock(defaultResponse, responseByBodyContent)
        );

        Test.startTest();
            McDeleteContactInvocable.deleteContactInMc(accIds);
        Test.stopTest();
        

        for(Account a: [Select Id, deletedFromMc__c from Account]){
            System.Assert.isTrue(a.deletedFromMc__c, 'Account not deleted from MC');
        }
    }


     static HttpResponse getDeletedMcContactResponse(){
        HttpResponse res = new HttpResponse();
        res.setHeader('Content-Type', 'application/json');
        res.setBody(
       '{"operationInitiated":true,"operationID":3,"requestServiceMessageID":"21d0d10d-a15a-413c-bc3e-8b43b185e551","resultMessages":[],"serviceMessageID":"acb87f67-ec49-42af-a0bb-987ac6451560"}'
        );
        res.setStatusCode(200);

        return res;
    }

}