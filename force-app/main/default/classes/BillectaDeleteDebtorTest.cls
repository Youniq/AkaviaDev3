/**
 * @description       : 
 * @author            : Malin Nilsson (Stretch Customer AB)
 * @group             : 
 * @last modified on  : 2024-12-03
 * @last modified by  : Malin Nilsson (Stretch Customer AB)
**/
@isTest
public with sharing class BillectaDeleteDebtorTest {
    @TestSetup
    static void makeData(){
        TestDataFactorySetupParams params = new TestDataFactorySetupParams();
        params.numberOfAccounts = 1;
        params.addMembershipsToMembers = true;
        TestDataFactory.setupBasicTestData();
        TestDataFactory.setupTestData(params);
    }

    @isTest
    static void TestDeleteDebtorSuccess(){
        Account acc = [SELECT Id, BillectaId__c FROM Account LIMIT 1];
        acc.BillectaId__c = 'TestBillectaId';
        update acc;

        BillectaDeleteDebtorInvocable.Request r = new BillectaDeleteDebtorInvocable.Request();
        r.accountId = acc.Id;
        List<BillectaDeleteDebtorInvocable.Request> reqs = new List<BillectaDeleteDebtorInvocable.Request>();
        reqs.add(r);

         Test.setMock(
            HttpCalloutMock.class,
            new Billecta_Test.MockHttpResponseGeneratorBillectaOK()
            );

        Test.startTest();
            BillectaDeleteDebtorInvocable.DeleteDebtor(reqs);
        Test.stopTest();

        // When successful delete - the Account.BillectaId__c should be deleted.
        Account acc_afterDel = [SELECT Id, BillectaId__c FROM Account LIMIT 1];
        System.Assert.areEqual(null, acc_afterDel.BillectaId__c);
    }

    @isTest
    static void TestDeleteDebtorFail(){
        Account acc = [SELECT Id, BillectaId__c FROM Account LIMIT 1];
        acc.BillectaId__c = 'TestBillectaId';
        update acc;

        BillectaDeleteDebtorInvocable.Request r = new BillectaDeleteDebtorInvocable.Request();
        r.accountId = acc.Id;
        List<BillectaDeleteDebtorInvocable.Request> reqs = new List<BillectaDeleteDebtorInvocable.Request>();
        reqs.add(r);

         Test.setMock(
            HttpCalloutMock.class,
            new Billecta_Test.MockHttpResponseGeneratorBillectaError()
            );

        Test.startTest();
            BillectaDeleteDebtorInvocable.DeleteDebtor(reqs);
        Test.stopTest();

        Callout__c c = [SELECT Id, Status__c, Name FROM Callout__c WHERE type__c like '%Delete Debtor%' LIMIT 1];
        System.Assert.areEqual('Failed', c.Status__c);
   
    }

        @isTest
    static void TestBatchDeleteDebtor(){
        Account acc = [SELECT Id, BillectaId__c FROM Account LIMIT 1];
        acc.BillectaId__c = 'TestBillectaId';
        update acc;

        List<Account> debtorsToDelete = new List<Account>();
        debtorsToDelete.add(acc);

         Test.setMock(
            HttpCalloutMock.class,
            new Billecta_Test.MockHttpResponseGeneratorBillectaOK()
            );

        Test.startTest();
            BillectaDeleteDebtorsBatch batchjob = new BillectaDeleteDebtorsBatch(debtorsToDelete);
            Database.executeBatch(batchjob, 40); 
        Test.stopTest();

        // When successful delete - the Account.BillectaId__c should be deleted.
        Account acc_afterDel = [SELECT Id, BillectaId__c FROM Account where Id =:acc.Id LIMIT 1];
        System.Assert.areEqual(null, acc_afterDel.BillectaId__c);
   
    }
}