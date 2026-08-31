@IsTest
public with sharing class BillectaUtilsTest {

  private static HttpRequest baseRequest() {
    HttpRequest req = new HttpRequest();
    req.setEndpoint('callout:Billecta_Test');
    return req;
  }

  @IsTest
  static void testCreateInvoice() {
    Blob body = Blob.valueOf('{"test":true}');

    HttpRequest req = BillectaUtils.CreateInvoice(baseRequest(), body);

    Assert.areEqual('POST', req.getMethod());
    Assert.isTrue(req.getEndpoint().endsWith('/v1/akavia/createinvoice'));
    Assert.areEqual(body.toString(), req.getBody());
  }

  @IsTest
  static void testInvoiceInformation() {
    HttpRequest req = BillectaUtils.InvoiceInformation('invoice-id', baseRequest());

    Assert.areEqual('GET', req.getMethod());
    Assert.isTrue(req.getEndpoint().endsWith('/v1/akavia/InvoiceActionStatus?id=invoice-id'));
  }

  @IsTest
  static void testCancelInvoice() {
    HttpRequest req = BillectaUtils.CancelInvoice('invoice-id', baseRequest());

    Assert.areEqual('POST', req.getMethod());
    Assert.isTrue(req.getEndpoint().endsWith('/v1/akavia/CancelInvoice?id=invoice-id'));
    
  }

  @IsTest
  static void testPauseInvoice() {
    HttpRequest req = BillectaUtils.PauseInvoice(baseRequest(), 'invoice-id');

    Assert.areEqual('PUT', req.getMethod());
    Assert.isTrue(req.getEndpoint().endsWith('/v1/invoice/pause/invoice-id'));
    Assert.areEqual('0', req.getHeader('Content-length'));
  }

  @IsTest
  static void testResumeInvoice() {
    HttpRequest req = BillectaUtils.ResumeInvoice(baseRequest(), 'invoice-id');

    Assert.areEqual('PUT', req.getMethod());
    Assert.isTrue(req.getEndpoint().endsWith('/v1/invoice/resume/invoice-id'));
    Assert.areEqual('0', req.getHeader('Content-length'));
  }

  @IsTest
  static void testSwishPaymentRequest() {
    HttpRequest req = BillectaUtils.SwishPaymentRequest(
      baseRequest(),
      'invoice-id',
      '46701234567'
    );

    Assert.areEqual('POST', req.getMethod());
    Assert.isTrue(
      req.getEndpoint().endsWith('/v1/payments/swish/invoice-id?phone=46701234567')
    );
    Assert.areEqual('0', req.getHeader('Content-length'));
  }

  @IsTest
  static void testSwishPaymentStatus() {
    HttpRequest req = BillectaUtils.SwishPaymentStatus(baseRequest(), 'invoice-id');

    Assert.areEqual('GET', req.getMethod());
    Assert.isTrue(req.getEndpoint().endsWith('/v1/payments/swish/invoice-id'));
    Assert.areEqual('0', req.getHeader('Content-length'));
  }

  @IsTest
  static void testCreateMultipleInvoices() {
    Blob body = Blob.valueOf('{"test":true}');

    HttpRequest req = BillectaUtils.CreateMultipleInvoices(
      baseRequest(),
      body,
      'batch-id'
    );

    Assert.areEqual('POST', req.getMethod());
    Assert.isTrue(req.getEndpoint().endsWith('/v1/akavia/createinvoices/batch-id'));
    Assert.areEqual(body.toString(), req.getBody());
  }

  @IsTest
  static void testCancelMultipleInvoices() {
    Blob body = Blob.valueOf('{"test":true}');

    HttpRequest req = BillectaUtils.CancelMultipleInvoices(baseRequest(), body);

    Assert.areEqual('POST', req.getMethod());
    Assert.isTrue(req.getEndpoint().endsWith('/v1/akavia/CancelInvoices'));
    Assert.areEqual(body.toString(), req.getBody());
  }

  @IsTest
  static void testCreateDebtor() {
    Blob body = Blob.valueOf('{"test":true}');

    HttpRequest req = BillectaUtils.CreateDebtor(baseRequest(), body);

    Assert.areEqual('POST', req.getMethod());
    Assert.isTrue(req.getEndpoint().endsWith('/v1/debtors/debtor'));
    Assert.areEqual(body.toString(), req.getBody());
  }

  @IsTest
  static void testUpdateDebtor() {
    Blob body = Blob.valueOf('{"test":true}');

    HttpRequest req = BillectaUtils.UpdateDebtor(baseRequest(), body);

    Assert.areEqual('PUT', req.getMethod());
    Assert.isTrue(req.getEndpoint().endsWith('/v1/debtors/debtor'));
    Assert.areEqual(body.toString(), req.getBody());
  }

  @IsTest
  static void testDeleteDebtor() {
    HttpRequest req = BillectaUtils.DeleteDebtor(baseRequest(), 'debtor-id');

    Assert.areEqual('DELETE', req.getMethod());
    Assert.isTrue(req.getEndpoint().endsWith('/v1/debtors/debtor/debtor-id'));
  }

  @IsTest
  static void testGetDebtor() {
    HttpRequest req = BillectaUtils.GetDebtor(baseRequest(), 'debtor-id');

    Assert.areEqual('GET', req.getMethod());
    Assert.isTrue(req.getEndpoint().endsWith('/v1/debtors/debtor/debtor-id'));
  }

  @IsTest
  static void testDebtorPaymentStatus() {
    HttpRequest req = BillectaUtils.DebtorPaymentStatus('debtor-id', baseRequest());

    Assert.areEqual('GET', req.getMethod());
    Assert.isTrue(req.getEndpoint().contains('/v1/akavia/DebtorPaymentStatus?id='));
    Assert.isTrue(req.getEndpoint().contains('%7Bdebtor-id%7D'));
  }

  @IsTest
  static void testSendSMS() {
    Blob body = Blob.valueOf('{"sms":true}');

    HttpRequest req = BillectaUtils.SendSMS(baseRequest(), body);

    Assert.areEqual('POST', req.getMethod());
    Assert.isTrue(req.getEndpoint().endsWith('/v1/delivery/sms'));
    Assert.areEqual(body.toString(), req.getBody());
  }

  @IsTest
  static void testInitGetBankAccounts() {
    Billecta__c cred = new Billecta__c(
      Creditor__c = 'creditor-id'
    );

    HttpRequest req = BillectaUtils.initGetBankAccounts(
      baseRequest(),
      'swedbank',
      '740121-0674',
      cred,
      true
    );

    Assert.areEqual('POST', req.getMethod());
    Assert.isTrue(
      req.getEndpoint().endsWith(
        '/v1/bank/accounts/creditor-id?bank=swedbank&ssn=740121-0674&other_device=true'
      )
    );
    Assert.areEqual('0', req.getHeader('Content-length'));
  }

  @IsTest
  static void testGetBankAccountsStatus() {
    HttpRequest req = BillectaUtils.getBankAccountsStatus(baseRequest(), 'public-id');

    Assert.areEqual('GET', req.getMethod());
    Assert.isTrue(req.getEndpoint().endsWith('/v1/bank/accounts/public-id'));
  }

  @IsTest
  static void testInitBankIdSign() {
    Blob body = Blob.valueOf('{"sign":true}');

    HttpRequest req = BillectaUtils.initBankIdSign(baseRequest(), body);

    Assert.areEqual('PUT', req.getMethod());
    Assert.isTrue(req.getEndpoint().endsWith('/v1/bankid/sign'));
    Assert.areEqual(body.toString(), req.getBody());
  }

  @IsTest
  static void testGetBankIDSignStatus() {
    HttpRequest req = BillectaUtils.getBankIDSignStatus(baseRequest(), 'public-id');

    Assert.areEqual('GET', req.getMethod());
    Assert.isTrue(req.getEndpoint().endsWith('/v1/bankid/sign/public-id'));
  }

  @IsTest
  static void testInitBankIdAuthentication() {
    Blob body = Blob.valueOf('{"auth":true}');

    HttpRequest req = BillectaUtils.initBankIdAuthentication(baseRequest(), body);

    Assert.areEqual('PUT', req.getMethod());
    Assert.isTrue(req.getEndpoint().endsWith('/v1/bankid/authentication'));
    Assert.areEqual(body.toString(), req.getBody());
  }

  @IsTest
  static void testGetBankIDAuthenticationStatus() {
    HttpRequest req =
      BillectaUtils.getBankIDAuthenticationStatus(baseRequest(), 'reference-token');

    Assert.areEqual('GET', req.getMethod());
    Assert.isTrue(
      req.getEndpoint().endsWith('/v1/bankid/authentication/reference-token')
    );
  }

  @IsTest
  static void testDebtorPaymentStatuses() {
    HttpRequest req = BillectaUtils.DebtorPaymentStatuses(
      'debtor-id',
      '2026-06-12T00:00:00',
      baseRequest()
    );

    Assert.areEqual('GET', req.getMethod());
    Assert.isTrue(
      req.getEndpoint().endsWith(
        '/v1/akavia/DebtorPaymentStatuses?id=debtor-id&from=2026-06-12T00:00:00'
      )
    );
  }

  @IsTest
  static void testIsDefaultDeliveryMethodKivraTrue() {
    Account acc = new Account();
    acc.DistributionMethod__c = 'Post';
    acc.IsDistributionPostalPaperOnly__c = false;
    acc.PaymentMethod__c = 'BG';

    Assert.areEqual(true, BillectaUtils.isDefaultDeliveryMethodKivra(acc));
  }

  @IsTest
  static void testIsDefaultDeliveryMethodKivraFalseWhenPaperOnly() {
    Account acc = new Account();
    acc.DistributionMethod__c = 'Post';
    acc.IsDistributionPostalPaperOnly__c = true;
    acc.PaymentMethod__c = 'BG';

    Assert.areEqual(false, BillectaUtils.isDefaultDeliveryMethodKivra(acc));
  }

  @IsTest
  static void testIsDefaultDeliveryMethodKivraFalseWhenWrongPaymentMethod() {
    Account acc = new Account();
    acc.DistributionMethod__c = 'Post';
    acc.IsDistributionPostalPaperOnly__c = false;
    acc.PaymentMethod__c = 'AG';

    Assert.areEqual(false, BillectaUtils.isDefaultDeliveryMethodKivra(acc));
  }
}