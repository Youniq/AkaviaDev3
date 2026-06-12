/**
 * @description       :
 * @author            : Malin Nilsson (Stretch Customer AB)
 * @group             :
 * @last modified on  : 2026-06-12
 * @last modified by  : Stefan Trieton (Stretch Customer AB)
 **/
@isTest
public with sharing class BillectaDebtorStatusUpdateHelperTest {
  @TestSetup
  static void makeData() {
    TestDataFactorySetupParams params = new TestDataFactorySetupParams();
    params.numberOfAccounts = 1;

    TestDataFactory.setupBasicTestData();
    TestDataFactory.setupTestData(params);
  }

  @isTest
  static void testGetLastUpdatedWithRecentUpdateAndBillectaId() {
    Account acc = [SELECT Id FROM Account LIMIT 1];

    acc.BillectaID__c = 'billecta-test-id';
    acc.PaymentStatusUpdated__c = System.now().addMinutes(-10);
    update acc;

    BillectaDebtorStatusUpdateHelper result =
      BillectaDebtorStatusUpdateHelper.getLastUpdated(acc.Id);

    Assert.areEqual(true, result.IDExists);
    Assert.areEqual('success', result.icon);
    Assert.isNotNull(result.lastUpdated);
  }

  @isTest
  static void testGetLastUpdatedWithOldUpdate() {
    Account acc = [SELECT Id FROM Account LIMIT 1];

    acc.BillectaID__c = 'billecta-test-id';
    acc.PaymentStatusUpdated__c = System.now().addHours(-2);
    update acc;

    BillectaDebtorStatusUpdateHelper result =
      BillectaDebtorStatusUpdateHelper.getLastUpdated(acc.Id);

    Assert.areEqual(true, result.IDExists);
    Assert.areEqual('warning', result.icon);
  }

  @isTest
  static void testGetLastUpdatedWithoutBillectaId() {
    Account acc = [SELECT Id FROM Account LIMIT 1];

    acc.BillectaID__c = null;
    acc.PaymentStatusUpdated__c = null;
    update acc;

    BillectaDebtorStatusUpdateHelper result =
      BillectaDebtorStatusUpdateHelper.getLastUpdated(acc.Id);

    Assert.areEqual(false, result.IDExists);
    Assert.areEqual('warning', result.icon);
  }

  @isTest
  static void testSendInvoiceCreatesCalloutRecord() {
    Account acc = [SELECT Id FROM Account LIMIT 1];

    Test.startTest();
    String result = BillectaDebtorStatusUpdateHelper.sendInvoice(acc.Id);
    Test.stopTest();

    Assert.areEqual('OK', result);
  }

  @IsTest
  static void testSendRetroactiveInvoiceCreatesCalloutRecord() {
    Account acc = [
      SELECT Id, SocialSecurityNumber__c, MemberNumber__c
      FROM Account
      LIMIT 1
    ];

    BillectaCreateInvoice invoice = new BillectaCreateInvoice();
    invoice.MembershipCategory = 'Yrkesverksam';
    invoice.FeeCategory = 'Fullbetalande';
    invoice.HaveIncomeInsurance = true;
    invoice.HaveAkassa = false;
    invoice.IsCreditInvoice = false;
    invoice.SocialSecurityNumber = acc.SocialSecurityNumber__c;
    invoice.MemberNumber = acc.MemberNumber__c;
    invoice.PeriodStart = Date.today().addMonths(-2);
    invoice.PeriodEnd = invoice.PeriodStart.addMonths(1).addDays(-1);
    invoice.UseDebtorBalance = true;

    Test.startTest();
    String result = BillectaDebtorStatusUpdateHelper.sendRetroactiveInvoice(
      acc.Id,
      invoice
    );
    Test.stopTest();

    Assert.areEqual('OK', result);
  }
}