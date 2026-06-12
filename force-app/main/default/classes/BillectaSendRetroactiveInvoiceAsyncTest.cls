@IsTest
public with sharing class BillectaSendRetroactiveInvoiceAsyncTest {

  private class MockBillectaSuccessResponse implements HttpCalloutMock {
    public HTTPResponse respond(HTTPRequest req) {
      HttpResponse res = new HttpResponse();
      res.setStatusCode(201);
      res.setHeader('Content-Type', 'application/json');
      res.setBody('{"PublicId":"retroactive-invoice-id"}');
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
  static void testExecuteSuccessUpdatesCalloutOk() {
    Account acc = [
      SELECT Id, SocialSecurityNumber__c, MemberNumber__c
      FROM Account
      LIMIT 1
    ];

    Callout__c co = new Callout__c(
      Account__c = acc.Id,
      Type__c = 'Billecta - Create Retroactive Invoice',
      Status__c = 'Queued'
    );
    insert co;

    BillectaCreateInvoice retro = createRetroactiveInvoice(acc);

    Test.setMock(HttpCalloutMock.class, new MockBillectaSuccessResponse());

    Test.startTest();
    System.enqueueJob(
      new BillectaSendRetroactiveInvoiceAsync(
        acc.Id,
        co.Id,
        retro
      )
    );
    Test.stopTest();

    Callout__c updatedCo = [
      SELECT Id,
        Status__c,
        Response__c,
        Request__c,
        Path__c,
        ErrorLog__c,
        SentOn__c,
        Duration__c
      FROM Callout__c
      WHERE Id = :co.Id
    ];

    Assert.areEqual('OK', updatedCo.Status__c);
    Assert.areEqual('{"PublicId":"retroactive-invoice-id"}', updatedCo.Response__c);
    Assert.isNotNull(updatedCo.Request__c);
    Assert.isNotNull(updatedCo.Path__c);
    Assert.areEqual(null, updatedCo.ErrorLog__c);
    Assert.isNotNull(updatedCo.SentOn__c);
    Assert.isNotNull(updatedCo.Duration__c);
  }

  @IsTest
  static void testExecuteFailedResponseUpdatesCalloutFailed() {
    Account acc = [
      SELECT Id, SocialSecurityNumber__c, MemberNumber__c
      FROM Account
      LIMIT 1
    ];

    Callout__c co = new Callout__c(
      Account__c = acc.Id,
      Type__c = 'Billecta - Create Retroactive Invoice',
      Status__c = 'Queued'
    );
    insert co;

    BillectaCreateInvoice retro = createRetroactiveInvoice(acc);

    Test.setMock(HttpCalloutMock.class, new MockBillectaFailedResponse());

    Test.startTest();
    System.enqueueJob(
      new BillectaSendRetroactiveInvoiceAsync(
        acc.Id,
        co.Id,
        retro
      )
    );
    Test.stopTest();

    Callout__c updatedCo = [
      SELECT Id,
        Status__c,
        Response__c,
        ErrorLog__c,
        SentOn__c,
        Duration__c
      FROM Callout__c
      WHERE Id = :co.Id
    ];

    Assert.areEqual('Failed', updatedCo.Status__c);
    Assert.areEqual('{"error":"Bad request"}', updatedCo.Response__c);
    Assert.areEqual('{"error":"Bad request"}', updatedCo.ErrorLog__c);
    Assert.isNotNull(updatedCo.SentOn__c);
    Assert.isNotNull(updatedCo.Duration__c);
  }

  private static BillectaCreateInvoice createRetroactiveInvoice(Account acc) {
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
    retro.DueDate = Date.today().addDays(14);
    retro.UseDebtorBalance = true;

    return retro;
  }
}