/**
 * @description       :
 * @author            : Malin Nilsson (Stretch Customer AB)
 * @group             :
 * @last modified on  : 2024-06-11
 * @last modified by  : Malin Nilsson (Stretch Customer AB)
 **/
@isTest
public with sharing class BillectaDebtorInvoiceInvocableTest {
  @TestSetup
  static void makeData() {
    TestDataFactorySetupParams params = new TestDataFactorySetupParams();
    params.numberOfAccounts = 1;

    TestDataFactory.setupBasicTestData();
    TestDataFactory.setupTestData(params);
  }

  @isTest
  static void testCreateRetroInv() {
    Account testAcc = [
      SELECT Id, SocialSecurityNumber__c, MemberNumber__c
      FROM Account
      LIMIT 1
    ];
    Date twoMonthsAgo = Date.today().addMonths(-2);

    BillectaDebtorInvoiceInvocable.Request req = new BillectaDebtorInvoiceInvocable.Request();
    req.retroactiveInvoiceInfo = new BillectaCreateInvoice();
    req.retroactiveInvoiceInfo.MembershipCategory = 'Yrkesverksam';
    req.retroactiveInvoiceInfo.FeeCategory = 'Fullbetalande';
    req.retroactiveInvoiceInfo.HaveIncomeInsurance = true;
    req.retroactiveInvoiceInfo.HaveAkassa = false;
    req.retroactiveInvoiceInfo.IsCreditInvoice = false;
    req.retroactiveInvoiceInfo.SocialSecurityNumber = testAcc.SocialSecurityNumber__c;
    req.retroactiveInvoiceInfo.MemberNumber = testAcc.MemberNumber__c;
    req.retroactiveInvoiceInfo.PeriodStart = Date.newInstance(
      twoMonthsAgo.year(),
      twoMonthsAgo.month(),
      1
    );
    req.retroactiveInvoiceInfo.PeriodEnd = Date.newInstance(
        twoMonthsAgo.year(),
        twoMonthsAgo.month() + 1,
        1
      )
      .addDays(-1);

    req.accountId = testAcc.Id;

    Test.setMock(
      HttpCalloutMock.class,
      new Billecta_Test.MockHttpResponseGeneratorBillecta()
    );

    Test.startTest();
    BillectaDebtorInvoiceInvocable.createInvoice(
      new List<BillectaDebtorInvoiceInvocable.Request>{ req }
    );
    Test.stopTest();

    List<Invoice__c> afterTestInvs = [
      SELECT Id, BillectaId__c
      FROM Invoice__c
      WHERE Person__c = :testAcc.Id
    ];

    Assert.areEqual(1, afterTestInvs.size());
  }

  @isTest
  static void testCreateRetroInvBadDate() {
    Account testAcc = [
      SELECT Id, SocialSecurityNumber__c, MemberNumber__c
      FROM Account
      LIMIT 1
    ];
    Date sevenMonthsAgo = Date.today().addMonths(-7); // Must be between 1-6 months ago

    BillectaDebtorInvoiceInvocable.Request req = new BillectaDebtorInvoiceInvocable.Request();
    req.retroactiveInvoiceInfo = new BillectaCreateInvoice();
    req.retroactiveInvoiceInfo.MembershipCategory = 'Yrkesverksam';
    req.retroactiveInvoiceInfo.FeeCategory = 'Fullbetalande';
    req.retroactiveInvoiceInfo.HaveIncomeInsurance = true;
    req.retroactiveInvoiceInfo.HaveAkassa = false;
    req.retroactiveInvoiceInfo.IsCreditInvoice = false;
    req.retroactiveInvoiceInfo.SocialSecurityNumber = testAcc.SocialSecurityNumber__c;
    req.retroactiveInvoiceInfo.MemberNumber = testAcc.MemberNumber__c;
    req.retroactiveInvoiceInfo.PeriodStart = Date.newInstance(
      sevenMonthsAgo.year(),
      sevenMonthsAgo.month(),
      1
    );
    req.retroactiveInvoiceInfo.PeriodEnd = Date.newInstance(
        sevenMonthsAgo.year(),
        sevenMonthsAgo.month() + 1,
        1
      )
      .addDays(-1);

    req.accountId = testAcc.Id;

    Test.setMock(
      HttpCalloutMock.class,
      new Billecta_Test.MockHttpResponseGeneratorBillecta()
    );

    Boolean caughtError = false;
    Test.startTest();
    try {
      BillectaDebtorInvoiceInvocable.createInvoice(
        new List<BillectaDebtorInvoiceInvocable.Request>{ req }
      );
    } catch (Exception e) {
      caughtError = true;
    }

    Test.stopTest();

    Assert.areEqual(true, caughtError);
  }

  @isTest
  static void testCreateInvForCurrentMonth() {
    Account testAcc = [SELECT Id FROM Account LIMIT 1];

    BillectaDebtorInvoiceInvocable.Request req = new BillectaDebtorInvoiceInvocable.Request();
    req.accountId = testAcc.Id;

    Test.setMock(
      HttpCalloutMock.class,
      new Billecta_Test.MockHttpResponseGeneratorBillecta()
    );

    Test.startTest();
    BillectaDebtorInvoiceInvocable.createInvoice(
      new List<BillectaDebtorInvoiceInvocable.Request>{ req }
    );
    Test.stopTest();

    List<Invoice__c> afterTestInvs = [
      SELECT Id, BillectaId__c
      FROM Invoice__c
      WHERE Person__c = :testAcc.Id
    ];

    Assert.areEqual(1, afterTestInvs.size());
  }
}