/**
 * @description       : Test for Invoice Helper
 * @author            : Håkon Kavli
 * @group             : Stretch
 * @last modified on  : 10-20-2021
 * @last modified by  : Håkon Kavli
 **/
@isTest
public with sharing class InvoiceHelperTest {
  @TestSetup
  static void makeData() {
    TestDataFactorySetupParams params = new TestDataFactorySetupParams();
    params.numberOfAccounts = 1;
    params.numberOfPaidInvoices = 10;
    params.numberOfUnpaidInvoices = 3;
    TestDataFactory.setupTestData(params);
  }

  @isTest
  private static void testGetInvoices() {
    Account personAccount = [SELECT Id FROM Account];

    Test.startTest();
    List<Invoice__c> invoices = InvoiceHelper.getInvoices(personAccount.Id, 2);
    System.assertEquals(2, invoices.size(), 'List has two items');
    Test.stopTest();
  }

  @isTest
  private static void testGetUnpaidInvoices() {
    Account personAccount = [SELECT Id FROM Account];

    Test.startTest();
    List<Invoice__c> invoices = InvoiceHelper.getUnpaidInvoices(
      personAccount.Id
    );
    System.assertEquals(3, invoices.size(), 'List has three unpaid invoices');
    Test.stopTest();
  }
}