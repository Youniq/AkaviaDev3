/**
 * @description       : Moved Tests from Billecta_Test to here because that class was too long + caused unessesary complications with deployment versions
 * @author            : Malin Nilsson (Stretch Customer AB)
 * @group             :
 * @last modified on  : 2025-07-03
 * @last modified by  : Malin Nilsson (Stretch Customer AB)
 **/
@isTest
public with sharing class BillectaBankAccountHelperTest {
  @testSetup
  static void setup() {
    System.debug('*** Billecta_Test Setup() starting ***');

    TestDataFactory.setupBasicTestData();
    TestDataFactorySetupParams setupParams = new TestDataFactorySetupParams();
    setupParams.numberOfAccounts = 1;
    TestDataFactory.setupTestData(setupParams);
  }

  @isTest
  static void testInitGetAccountNumbers() {
    System.debug('*** Billecta_Test testInitGetAccountNumbers() starting ***');

    Account testAcc = [SELECT Id FROM Account LIMIT 1];

    Test.setMock(
      HttpCalloutMock.class,
      new Billecta_Test.MockHttpResponseGeneratorBillecta()
    );
    Test.startTest();

    BillectaBankAccountHelper obj = new BillectaBankAccountHelper();
    obj = BillectaBankAccountHelper.initData(testAcc.Id);

    obj.theAccount.PaymentMethod__c = 'AG';
    obj.theAccount.AutogiroBank__c = 'SEB';

    BillectaBankAccountHelper result = BillectaBankAccountHelper.initGetBankAccounts(
      obj,
      false
    );

    Test.stopTest();

    System.assertEquals('TestBillectaId', result.PublicId);
  }

  @isTest
  static void testInitGetAccountNumbers_Error() {
    System.debug('*** Billecta_Test testInitGetAccountNumbers() starting ***');

    Account testAcc = [SELECT Id FROM Account LIMIT 1];

    Test.setMock(
      HttpCalloutMock.class,
      new Billecta_Test.MockHttpResponseGeneratorBillectaError()
    );
    Test.startTest();

    BillectaBankAccountHelper obj = new BillectaBankAccountHelper();
    obj = BillectaBankAccountHelper.initData(testAcc.Id);

    obj.theAccount.PaymentMethod__c = 'AG';
    obj.theAccount.AutogiroBank__c = 'SEB';

    BillectaBankAccountHelper result = BillectaBankAccountHelper.initGetBankAccounts(
      obj,
      false
    );

    Test.stopTest();

    List<DebugLog__c> logs = [SELECT Id FROM DebugLog__c];
    Assert.areNotEqual(null, logs);
  }

  @isTest
  static void testGetAccountNumbersStatus() {
    System.debug(
      '*** Billecta_Test testGetAccountNumbersStatus() starting ***'
    );

    Account testAcc = [SELECT Id FROM Account LIMIT 1];

    Test.setMock(
      HttpCalloutMock.class,
      new MockHttpResponseGeneratorBillectaGetBankAccounts()
    );
    Test.startTest();

    BillectaBankAccountHelper obj = new BillectaBankAccountHelper();
    obj = BillectaBankAccountHelper.initData(testAcc.Id);

    obj.theAccount.PaymentMethod__c = 'AG';
    obj.theAccount.AutogiroBank__c = 'SEB';

    obj = BillectaBankAccountHelper.getBankAccountsStatus(
      obj,
      'TestBillectaId'
    );

    Test.stopTest();

    System.assertEquals(1, obj.bankAccounts.size());
    System.assertEquals('1234-12344560', obj.bankAccounts[0]);
  }

  @isTest
  static void testGetAccountNumbersStatus_Error() {
    System.debug(
      '*** Billecta_Test testGetAccountNumbersStatus() starting ***'
    );

    Account testAcc = [SELECT Id FROM Account LIMIT 1];

    Test.setMock(
      HttpCalloutMock.class,
      new Billecta_Test.MockHttpResponseGeneratorBillectaError()
    );
    Test.startTest();

    BillectaBankAccountHelper obj = new BillectaBankAccountHelper();
    obj = BillectaBankAccountHelper.initData(testAcc.Id);

    obj.theAccount.PaymentMethod__c = 'AG';
    obj.theAccount.AutogiroBank__c = 'SEB';

    obj = BillectaBankAccountHelper.getBankAccountsStatus(
      obj,
      'TestBillectaId'
    );

    Test.stopTest();

    List<DebugLog__c> logs = [SELECT Id FROM DebugLog__c];
    Assert.areNotEqual(null, logs);
  }

  @isTest
  static void testGetAccountNumbersStatus_Waiting() {
    System.debug(
      '*** Billecta_Test testGetAccountNumbersStatus() starting ***'
    );

    Account testAcc = [SELECT Id FROM Account LIMIT 1];

    Test.setMock(
      HttpCalloutMock.class,
      new MockHttpResponseGeneratorBillectaGetBankAccounts_Waiting()
    );
    Test.startTest();

    BillectaBankAccountHelper obj = new BillectaBankAccountHelper();
    obj = BillectaBankAccountHelper.initData(testAcc.Id);

    obj.theAccount.PaymentMethod__c = 'AG';
    obj.theAccount.AutogiroBank__c = 'SEB';

    obj = BillectaBankAccountHelper.getBankAccountsStatus(
      obj,
      'TestBillectaId'
    );

    Test.stopTest();

    System.assertEquals(null, obj.bankAccounts);
  }

  @isTest
  static void testInitBankIDSign() {
    System.debug('*** Billecta_Test testInitBankIDSign() starting ***');

    Account testAcc = [SELECT Id FROM Account LIMIT 1];

    Test.setMock(
      HttpCalloutMock.class,
      new MockHttpResponseGeneratorBillectaGetBankIDSignStatus()
    );
    Test.startTest();

    BillectaBankAccountHelper obj = new BillectaBankAccountHelper();
    obj = BillectaBankAccountHelper.initData(testAcc.Id);

    obj.theAccount.PaymentMethod__c = 'AG';
    obj.theAccount.AutogiroBank__c = 'SEB';

    BillectaBankAccountHelper result = BillectaBankAccountHelper.initBankIDSign(
      obj
    );

    Test.stopTest();

    System.assertEquals(
      '10b2cbe4-36bf-47a6-9aff-afb05371acc3',
      result.PublicId
    );
  }

  @isTest
  static void testInitBankIDSign_Error() {
    System.debug('*** Billecta_Test testInitBankIDSign() starting ***');

    Account testAcc = [SELECT Id FROM Account LIMIT 1];

    Test.setMock(
      HttpCalloutMock.class,
      new Billecta_Test.MockHttpResponseGeneratorBillectaError()
    );
    Test.startTest();

    BillectaBankAccountHelper obj = new BillectaBankAccountHelper();
    obj = BillectaBankAccountHelper.initData(testAcc.Id);

    obj.theAccount.PaymentMethod__c = 'AG';
    obj.theAccount.AutogiroBank__c = 'SEB';

    BillectaBankAccountHelper result = BillectaBankAccountHelper.initBankIDSign(
      obj
    );

    Test.stopTest();

    List<DebugLog__c> logs = [SELECT Id FROM DebugLog__c];
    Assert.areNotEqual(null, logs);
  }

  @isTest
  static void testGetBankIDSignStatus() {
    System.debug('*** Billecta_Test testGetBankIDSignStatus() starting ***');

    Account testAcc = [SELECT Id FROM Account LIMIT 1];

    Test.setMock(
      HttpCalloutMock.class,
      new MockHttpResponseGeneratorBillectaGetBankIDSignStatus()
    );
    Test.startTest();

    BillectaBankAccountHelper obj = new BillectaBankAccountHelper();
    obj = BillectaBankAccountHelper.initData(testAcc.Id);

    obj.theAccount.PaymentMethod__c = 'AG';
    obj.theAccount.AutogiroBank__c = 'SEB';

    obj = BillectaBankAccountHelper.getBankIDSignStatus(
      obj,
      '10b2cbe4-36bf-47a6-9aff-afb05371acc3'
    );

    Test.stopTest();

    System.assertEquals('Complete', obj.Status);
    System.assertEquals(
      '10b2cbe4-36bf-47a6-9aff-afb05371acc3',
      obj.theAccount.AG_BankIDSignToken__c
    );
  }

  @isTest
  static void testGetBankIDSignStatus_Error() {
    System.debug(
      '*** Billecta_Test testGetBankIDSignStatus_Error() starting ***'
    );

    Account testAcc = [SELECT Id FROM Account LIMIT 1];

    Test.setMock(
      HttpCalloutMock.class,
      new Billecta_Test.MockHttpResponseGeneratorBillectaError()
    );
    Test.startTest();

    BillectaBankAccountHelper obj = new BillectaBankAccountHelper();
    obj = BillectaBankAccountHelper.initData(testAcc.Id);

    obj.theAccount.PaymentMethod__c = 'AG';
    obj.theAccount.AutogiroBank__c = 'SEB';

    obj = BillectaBankAccountHelper.getBankIDSignStatus(
      obj,
      '10b2cbe4-36bf-47a6-9aff-afb05371acc3'
    );

    Test.stopTest();

    System.assertEquals('Failed', obj.Status);
  }

  @isTest
  static void testSaveAutoGiro() {
    System.debug('*** Billecta_Test testSaveAutoGiro() starting ***');

    Account testAcc = [SELECT Id FROM Account LIMIT 1];

    Test.startTest();

    BillectaBankAccountHelper obj = new BillectaBankAccountHelper();
    obj = BillectaBankAccountHelper.initData(testAcc.Id);

    obj.theAccount.PaymentMethod__c = 'Autogiro';
    obj.theAccount.AutogiroBank__c = 'SEB';
    obj.theAccount.AG_BankIDSignToken__c = 'token';
    obj.theAccount.EinvoiceBank__c = 'SHB';
    obj.theAccount.DistributionMethod__c = 'Kivra';

    obj = BillectaBankAccountHelper.savePaymentMethod(obj, '1234-12344560');

    Test.stopTest();

    testAcc = [
      SELECT
        Id,
        BillectaID__c,
        PaymentMethod__c,
        AutogiroBank__c,
        EinvoiceBank__c,
        AG_BankAccountNumber__c,
        AG_BankClearingNumber__c,
        SocialSecurityNumber__c,
        DistributionMethod__c,
        AG_BankIDSignToken__c
      FROM Account
      WHERE ID = :testAcc.Id
    ];

    System.assertEquals('AG', testAcc.PaymentMethod__c);
    System.assertEquals('1234', testAcc.AG_BankClearingNumber__c);
    System.assertEquals('12344560', testAcc.AG_BankAccountNumber__c);
    System.assertEquals('token', testAcc.AG_BankIDSignToken__c);
    System.assertEquals(null, testAcc.EinvoiceBank__c);
    System.assertEquals('Ingen leverans', testAcc.DistributionMethod__c);
  }

  @isTest
  static void testSaveEInvoice() {
    System.debug('*** Billecta_Test testSaveEInvoice() starting ***');

    Account testAcc = [SELECT Id FROM Account LIMIT 1];

    Test.startTest();

    BillectaBankAccountHelper obj = new BillectaBankAccountHelper();
    obj = BillectaBankAccountHelper.initData(testAcc.Id);

    obj.theAccount.PaymentMethod__c = 'Bankgiro (faktura)';
    obj.theAccount.AutogiroBank__c = 'SEB';
    obj.theAccount.AG_BankIDSignToken__c = 'token';
    obj.theAccount.EinvoiceBank__c = 'SEB';
    obj.theAccount.DistributionMethod__c = 'E-faktura';

    obj = BillectaBankAccountHelper.savePaymentMethod(obj, '1234-12344560');

    Test.stopTest();

    testAcc = [
      SELECT
        Id,
        BillectaID__c,
        PaymentMethod__c,
        AutogiroBank__c,
        EinvoiceBank__c,
        AG_BankAccountNumber__c,
        AG_BankClearingNumber__c,
        SocialSecurityNumber__c,
        DistributionMethod__c,
        AG_BankIDSignToken__c
      FROM Account
      WHERE ID = :testAcc.Id
    ];

    System.assertEquals('BG', testAcc.PaymentMethod__c);
    System.assertEquals(null, testAcc.AG_BankClearingNumber__c);
    System.assertEquals(null, testAcc.AG_BankAccountNumber__c);
    System.assertEquals(null, testAcc.AG_BankIDSignToken__c);
    System.assertEquals('SEB', testAcc.EinvoiceBank__c);
    System.assertEquals('E-faktura', testAcc.DistributionMethod__c);
  }

  public class MockHttpResponseGeneratorBillectaGetBankAccounts implements HttpCalloutMock {
    // Implement this interface method
    public HTTPResponse respond(HTTPRequest request) {
      HttpResponse response = new HttpResponse();
      response.setHeader('Content-Type', 'application/json');
      response.setBody(
        '{"PublicId": "e58143d4-8e7e-4fdc-9f2d-5267708d594e",' +
        '"Bank": "SEB",' +
        '"SSN": "19820101-1234",' +
        '"QR": null,' +
        '"Status": "Success",' +
        '"AccountNumbers": [{' +
        '"Number": "1234,12344560",' +
        '"ClearingNo": "1234",' +
        '"AccountNo": "12344560",' +
        '"Name": null,' +
        '"Type": null,' +
        '"AutogiroCompatible": "Unapproved",' +
        '"Balance": null,' +
        '"Iban": null,' +
        '"HolderName": null}],' +
        '"BankIdAutostartToken": null,' +
        '"IsBankIdAutostartTokenRequired": false,' +
        '"FailureMessage": null,' +
        '"FailureCode": null' +
        '}' +
        '},"HasError":false,"ErrorMessage":null}'
      );
      response.setStatusCode(200);
      return response;
    }
  }

  public class MockHttpResponseGeneratorBillectaGetBankAccounts_Waiting implements HttpCalloutMock {
    // Implement this interface method
    public HTTPResponse respond(HTTPRequest request) {
      HttpResponse response = new HttpResponse();
      response.setHeader('Content-Type', 'application/json');
      response.setBody(
        '{"PublicId": "e58143d4-8e7e-4fdc-9f2d-5267708d594e",' +
        '"Bank": "SEB",' +
        '"SSN": "19820101-1234",' +
        '"QR": null,' +
        '"Status": "Waiting",' +
        '"AccountNumbers": [{' +
        '"Number": "1234,12344560",' +
        '"ClearingNo": "1234",' +
        '"AccountNo": "12344560",' +
        '"Name": null,' +
        '"Type": null,' +
        '"AutogiroCompatible": "Unapproved",' +
        '"Balance": null,' +
        '"Iban": null,' +
        '"HolderName": null}],' +
        '"BankIdAutostartToken": null,' +
        '"IsBankIdAutostartTokenRequired": false,' +
        '"FailureMessage": null,' +
        '"FailureCode": null' +
        '}' +
        '},"HasError":false,"ErrorMessage":null}'
      );
      response.setStatusCode(200);
      return response;
    }
  }

  public class MockHttpResponseGeneratorBillectaGetBankIDSignStatus implements HttpCalloutMock {
    // Implement this interface method
    public HTTPResponse respond(HTTPRequest request) {
      HttpResponse response = new HttpResponse();
      response.setHeader('Content-Type', 'application/json');
      response.setBody(
        '{"Status": "Complete",' +
        '"SSN": "198001011234",' +
        '"ReferenceToken": "10b2cbe4-36bf-47a6-9aff-afb05371acc3",' +
        '"AutoStartToken": "9eb9cdad-1ff7-49de-9402-29dc0c268cd1",' +
        '"QR": null,' +
        '"GivenName": "John",' +
        '"Surname": "Doe",' +
        '"IpAddress": "196.1.1.23",' +
        '"Name": "John Doe",' +
        '"NotAfter": "2021-05-26 16:32:28+02:00",' +
        '"NotBefore": "2020-11-07 16:32:28+01:00",' +
        '"OcspResponse": null,' +
        '"Signature": null,' +
        '"Created": "0001-01-01 00:00:00+01:00",' +
        '"HintCode": null}' +
        '},"HasError":false,"ErrorMessage":null}'
      );
      response.setStatusCode(200);
      return response;
    }
  }
}