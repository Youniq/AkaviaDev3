@IsTest
public with sharing class BillectaSendInvoiceAsyncTest {

  private class MockBillectaCreateInvoiceResponse implements HttpCalloutMock {
    public HTTPResponse respond(HTTPRequest req) {
      HttpResponse res = new HttpResponse();
      res.setStatusCode(201);
      res.setHeader('Content-Type', 'application/json');
      res.setBody('{"PublicId":"test-billecta-invoice-id"}');
      return res;
    }
  }

  private class MockBillectaFailedResponse implements HttpCalloutMock {
    public HTTPResponse respond(HTTPRequest req) {
      HttpResponse res = new HttpResponse();
      res.setStatusCode(400);
      res.setHeader('Content-Type', 'application/json');
      res.setBody('{"error":"Bad request"}');
      return res;
    }
  }

  @TestSetup
  static void makeData() {
    TestDataFactorySetupParams params = new TestDataFactorySetupParams();
    params.numberOfAccounts = 1;

    TestDataFactory.setupBasicTestData();
    TestDataFactory.setupTestData(params);
  }

  @IsTest
  static void testCreateInvoiceCreatesInvoiceAndUpdatesCallout() {
    Account acc = [
      SELECT Id,
        MembershipCategory__c,
        FeeCategory__c,
        BillectaID__c,
        MemberNumber__c,
        SocialSecurityNumber__c,
        UnemploymentFundThroughAkavia__c,
        (
          SELECT Id
          FROM MembershipBenefits__r
          WHERE Status__c = 'Aktiv'
          AND BenefitName__c = 'Inkomstförsäkring'
        )
      FROM Account
      LIMIT 1
    ];

    Test.startTest();

    BillectaSendInvoiceAsync job = new BillectaSendInvoiceAsync(acc);
    Id jobId = System.enqueueJob(job);

    insert new Callout__c(
      jobId__c = jobId,
      Type__c = 'Billecta - Create Invoice',
      Account__c = acc.Id,
      Status__c = 'Queued'
    );

    Test.setMock(HttpCalloutMock.class, new MockBillectaCreateInvoiceResponse());

    Test.stopTest();

    Callout__c co = [
      SELECT Id,
        Status__c,
        Response__c,
        sentOn__c,
        Duration__c,
        errorLog__c
      FROM Callout__c
      WHERE jobId__c = :jobId
      LIMIT 1
    ];

    Assert.areEqual('OK', co.Status__c);
    Assert.areEqual(null, co.errorLog__c);
    Assert.isNotNull(co.Response__c);
    Assert.isNotNull(co.sentOn__c);
    Assert.isNotNull(co.Duration__c);

    List<Invoice__c> invoices = [
      SELECT Id,
        Person__c,
        BillectaID__c,
        MembershipCategory__c,
        FeeCategory__c
      FROM Invoice__c
      WHERE Person__c = :acc.Id
    ];

    Assert.areEqual(1, invoices.size());
    Assert.areEqual('test-billecta-invoice-id', invoices[0].BillectaID__c);
  }

  @IsTest
  static void testCreateRetroactiveInvoiceCreatesInvoiceAndUpdatesCallout() {
    Account acc = [
      SELECT Id,
        MembershipCategory__c,
        FeeCategory__c,
        BillectaID__c,
        MemberNumber__c,
        SocialSecurityNumber__c,
        UnemploymentFundThroughAkavia__c,
        (
          SELECT Id
          FROM MembershipBenefits__r
          WHERE Status__c = 'Aktiv'
          AND BenefitName__c = 'Inkomstförsäkring'
        )
      FROM Account
      LIMIT 1
    ];

    BillectaCreateInvoice retro = new BillectaCreateInvoice();
    retro.MembershipCategory = 'Yrkesverksam';
    retro.FeeCategory = 'Fullbetalande';
    retro.HaveIncomeInsurance = true;
    retro.HaveAkassa = false;
    retro.IsCreditInvoice = false;
    retro.SocialSecurityNumber = acc.SocialSecurityNumber__c;
    retro.MemberNumber = acc.MemberNumber__c;
    retro.PeriodStart = Date.today().addMonths(-2);
    retro.PeriodEnd = retro.PeriodStart.addMonths(1).addDays(-1);
    retro.UseDebtorBalance = true;

    Test.startTest();

    BillectaSendInvoiceAsync job = new BillectaSendInvoiceAsync(acc, retro);
    Id jobId = System.enqueueJob(job);

    insert new Callout__c(
      jobId__c = jobId,
      Type__c = 'Billecta - Create Retroactive Invoice',
      Account__c = acc.Id,
      Status__c = 'Queued'
    );

    Test.setMock(HttpCalloutMock.class, new MockBillectaCreateInvoiceResponse());

    Test.stopTest();

    Callout__c co = [
      SELECT Id,
        Status__c,
        Response__c,
        sentOn__c,
        Duration__c,
        errorLog__c
      FROM Callout__c
      WHERE jobId__c = :jobId
      LIMIT 1
    ];

    Assert.areEqual('OK', co.Status__c);
    Assert.areEqual(null, co.errorLog__c);
    Assert.isNotNull(co.Response__c);

    List<Invoice__c> invoices = [
      SELECT Id, Person__c, BillectaID__c
      FROM Invoice__c
      WHERE Person__c = :acc.Id
    ];

    Assert.areEqual(1, invoices.size());
    Assert.areEqual('test-billecta-invoice-id', invoices[0].BillectaID__c);
  }

  @IsTest
  static void testFailedBillectaResponseSetsCalloutFailed() {
    Account acc = [
      SELECT Id,
        MembershipCategory__c,
        FeeCategory__c,
        BillectaID__c,
        MemberNumber__c,
        SocialSecurityNumber__c,
        UnemploymentFundThroughAkavia__c,
        (
          SELECT Id
          FROM MembershipBenefits__r
          WHERE Status__c = 'Aktiv'
          AND BenefitName__c = 'Inkomstförsäkring'
        )
      FROM Account
      LIMIT 1
    ];

    Test.startTest();

    BillectaSendInvoiceAsync job = new BillectaSendInvoiceAsync(acc);
    Id jobId = System.enqueueJob(job);

    insert new Callout__c(
      jobId__c = jobId,
      Type__c = 'Billecta - Create Invoice',
      Account__c = acc.Id,
      Status__c = 'Queued'
    );

    Test.setMock(HttpCalloutMock.class, new MockBillectaFailedResponse());

    Test.stopTest();

    Callout__c co = [
      SELECT Id,
        Status__c,
        errorLog__c,
        Response__c
      FROM Callout__c
      WHERE jobId__c = :jobId
      LIMIT 1
    ];

    Assert.areEqual('Failed', co.Status__c);
    Assert.isNotNull(co.errorLog__c);

    Assert.areEqual(0, [
      SELECT COUNT()
      FROM Invoice__c
      WHERE Person__c = :acc.Id
    ]);
  }
}