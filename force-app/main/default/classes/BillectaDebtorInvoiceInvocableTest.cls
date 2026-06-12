/**
 * @author            : Malin Nilsson (Stretch Customer AB)
 * @group             :
 * @last modified on  : 2026-06-12
 * @last modified by  : Stefan Trieton (Stretch Customer AB)
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
    Date expectedStart = Date.newInstance(twoMonthsAgo.year(), twoMonthsAgo.month(), 1);
    Date expectedEnd = expectedStart.addMonths(1).addDays(-1);

    BillectaCreateInvoice invoice = new BillectaCreateInvoice();
    invoice.MembershipCategory = 'Yrkesverksam';
    invoice.FeeCategory = 'Fullbetalande';
    invoice.HaveIncomeInsurance = true;
    invoice.HaveAkassa = false;
    invoice.IsCreditInvoice = false;
    invoice.SocialSecurityNumber = testAcc.SocialSecurityNumber__c;
    invoice.MemberNumber = testAcc.MemberNumber__c;
    invoice.PeriodStart = twoMonthsAgo;

    BillectaDebtorInvoiceInvocable.Request req =
      new BillectaDebtorInvoiceInvocable.Request();

    req.accountId = testAcc.Id;
    req.retroactiveInvoiceInfo = invoice;

    Test.setMock(
      HttpCalloutMock.class,
      new Billecta_Test.MockHttpResponseGeneratorBillecta()
    );

    Test.startTest();
    BillectaDebtorInvoiceInvocable.createInvoice(
      new List<BillectaDebtorInvoiceInvocable.Request>{ req }
    );
    Test.stopTest();

    Date expectedDueDate = BillectaDebtorInvoiceInvocable.calculateDueDate(Date.today());

    Assert.areEqual(expectedDueDate, invoice.DueDate);
    Assert.areEqual(expectedStart, invoice.PeriodStart);
    Assert.areEqual(expectedEnd, invoice.PeriodEnd);
    Assert.areEqual(true, invoice.UseDebtorBalance);

    Assert.areEqual(1, [
      SELECT COUNT()
      FROM Invoice__c
      WHERE Person__c = :testAcc.Id
    ]);
  }

  @isTest
  static void testCreateRetroInvPensionerGetsTwelveMonths() {
    Account testAcc = [
      SELECT Id, SocialSecurityNumber__c, MemberNumber__c
      FROM Account
      LIMIT 1
    ];

    Date twoMonthsAgo = Date.today().addMonths(-2);
    Date expectedStart = Date.newInstance(twoMonthsAgo.year(), twoMonthsAgo.month(), 1);
    Date expectedEnd = expectedStart.addMonths(12).addDays(-1);

    BillectaCreateInvoice invoice = new BillectaCreateInvoice();
    invoice.MembershipCategory = 'Pensionär';
    invoice.FeeCategory = 'Fullbetalande';
    invoice.HaveIncomeInsurance = true;
    invoice.HaveAkassa = false;
    invoice.IsCreditInvoice = false;
    invoice.SocialSecurityNumber = testAcc.SocialSecurityNumber__c;
    invoice.MemberNumber = testAcc.MemberNumber__c;
    invoice.PeriodStart = twoMonthsAgo;

    BillectaDebtorInvoiceInvocable.Request req =
      new BillectaDebtorInvoiceInvocable.Request();

    req.accountId = testAcc.Id;
    req.retroactiveInvoiceInfo = invoice;

    Test.setMock(
      HttpCalloutMock.class,
      new Billecta_Test.MockHttpResponseGeneratorBillecta()
    );

    Test.startTest();
    BillectaDebtorInvoiceInvocable.createInvoice(
      new List<BillectaDebtorInvoiceInvocable.Request>{ req }
    );
    Test.stopTest();

    Date expectedDueDate = BillectaDebtorInvoiceInvocable.calculateDueDate(Date.today());

    Assert.areEqual(expectedDueDate, invoice.DueDate);
    Assert.areEqual(expectedStart, invoice.PeriodStart);
    Assert.areEqual(expectedEnd, invoice.PeriodEnd);
    Assert.areEqual(true, invoice.UseDebtorBalance);

    Assert.areEqual(1, [
      SELECT COUNT()
      FROM Invoice__c
      WHERE Person__c = :testAcc.Id
    ]);
  }

  @isTest
  static void testCreateInvForCurrentMonthWhenInvoiceInfoIsNull() {
    Account testAcc = [SELECT Id FROM Account LIMIT 1];

    BillectaDebtorInvoiceInvocable.Request req =
      new BillectaDebtorInvoiceInvocable.Request();

    req.accountId = testAcc.Id;
    req.retroactiveInvoiceInfo = null;

    Test.setMock(
      HttpCalloutMock.class,
      new Billecta_Test.MockHttpResponseGeneratorBillecta()
    );

    Test.startTest();
    BillectaDebtorInvoiceInvocable.createInvoice(
      new List<BillectaDebtorInvoiceInvocable.Request>{ req }
    );
    Test.stopTest();

    Assert.areEqual(1, [
      SELECT COUNT()
      FROM Invoice__c
      WHERE Person__c = :testAcc.Id
    ]);
  }

  @isTest
  static void testCreateInvForCurrentMonthWhenPeriodStartIsNull() {
    Account testAcc = [SELECT Id FROM Account LIMIT 1];

    BillectaCreateInvoice invoice = new BillectaCreateInvoice();

    BillectaDebtorInvoiceInvocable.Request req =
      new BillectaDebtorInvoiceInvocable.Request();

    req.accountId = testAcc.Id;
    req.retroactiveInvoiceInfo = invoice;

    Test.setMock(
      HttpCalloutMock.class,
      new Billecta_Test.MockHttpResponseGeneratorBillecta()
    );

    Test.startTest();
    BillectaDebtorInvoiceInvocable.createInvoice(
      new List<BillectaDebtorInvoiceInvocable.Request>{ req }
    );
    Test.stopTest();

    Assert.areEqual(1, [
      SELECT COUNT()
      FROM Invoice__c
      WHERE Person__c = :testAcc.Id
    ]);
  }
}