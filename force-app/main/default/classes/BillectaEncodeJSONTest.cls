@IsTest
public with sharing class BillectaEncodeJSONTest {

  @TestSetup
  static void makeData() {
    TestDataFactorySetupParams params = new TestDataFactorySetupParams();
    params.numberOfAccounts = 1;

    TestDataFactory.setupBasicTestData();
    TestDataFactory.setupTestData(params);
  }

  @IsTest
  static void testEncodeCreateDebtor() {

    Account acc = [
      SELECT Id,
        BillectaID__c,
        SocialSecurityNumber__c,
        FirstName,
        LastName,
        CurrentCOAdress__c,
        CurrentStreetAdress__c,
        CurrentZipCode__c,
        CurrentCity__c,
        CurrentCountryCode__c,
        PersonMobilePhone,
        PersonEmail,
        MemberNumber__c,
        ProtectedIdentity__c,
        DistributionMethod__c,
        PaymentMethod__c
      FROM Account
      LIMIT 1
    ];

    acc.PaymentMethod__c = 'BG';
    acc.DistributionMethod__c = 'Post';

    Blob result = BillectaEncodeJSON.encodeCreateDebtor(
      acc,
      'creditor-id'
    );

    String jsonBody = result.toString();

    Assert.isTrue(jsonBody.contains('"CreditorPublicId":"creditor-id"'));
    Assert.isTrue(jsonBody.contains('"DebtorExternalId":"' + acc.Id + '"'));
    Assert.isTrue(jsonBody.contains('"DebtorNo":"' + acc.MemberNumber__c + '"'));
    Assert.isTrue(jsonBody.contains('"IsActive":true'));
  }

  @IsTest
  static void testEncodeUpdateDebtor() {

    Account acc = [
      SELECT Id,
        BillectaID__c,
        SocialSecurityNumber__c,
        FirstName,
        LastName,
        CurrentCOAdress__c,
        CurrentStreetAdress__c,
        CurrentZipCode__c,
        CurrentCity__c,
        CurrentCountryCode__c,
        PersonMobilePhone,
        PersonEmail,
        MemberNumber__c,
        ProtectedIdentity__c,
        DistributionMethod__c,
        PaymentMethod__c,
        IsDistributionPostalPaperOnly__c,
        EinvoiceBank__c
      FROM Account
      LIMIT 1
    ];

    BillectaCreateDebtor.DebtorView debtor =
      new BillectaCreateDebtor.DebtorView();

    Blob result = BillectaEncodeJSON.encodeUpdateDebtor(
      acc,
      debtor,
      true
    );

    String jsonBody = result.toString();

    Assert.isTrue(jsonBody.contains('"DebtorExternalId":"' + acc.Id + '"'));
    Assert.isTrue(jsonBody.contains('"DebtorNo":"' + acc.MemberNumber__c + '"'));
  }

  @IsTest
  static void testEncodeAkaviaInvoiceActionView() {

    Account acc = [
      SELECT Id,
        SocialSecurityNumber__c,
        MemberNumber__c,
        MembershipCategory__c,
        FeeCategory__c,
        UnemploymentFundThroughAkavia__c
      FROM Account
      LIMIT 1
    ];

    Blob result = BillectaEncodeJSON.encodeAkaviaInvoiceActionView(
      acc,
      true,
      'creditor-id'
    );

    String jsonBody = result.toString();

    Assert.isTrue(jsonBody.contains('"CreditorPublicId":"creditor-id"'));
    Assert.isTrue(jsonBody.contains('"ExternalId":"' + acc.Id + '"'));
    Assert.isTrue(jsonBody.contains('"HaveIncomeInsurance":true'));
  }

  @IsTest
  static void testEncodeAkaviaRetroactiveInvoice() {

    Account acc = [
      SELECT Id,
        SocialSecurityNumber__c,
        MemberNumber__c
      FROM Account
      LIMIT 1
    ];

    BillectaCreateInvoice retro = new BillectaCreateInvoice();

    retro.MembershipCategory = 'Yrkesverksam';
    retro.FeeCategory = 'Fullbetalande';
    retro.HaveIncomeInsurance = true;
    retro.HaveAkassa = false;
    retro.UseDebtorBalance = true;
    retro.PeriodStart = Date.today().addMonths(-2);
    retro.PeriodEnd = Date.today().addMonths(-1);
    retro.DueDate = Date.today().addDays(14);

    Blob result = BillectaEncodeJSON.encodeAkaviaRetroactiveInvoice(
      acc,
      retro,
      'creditor-id'
    );

    String jsonBody = result.toString();

    Assert.isTrue(jsonBody.contains('"CreditorPublicId":"creditor-id"'));
    Assert.isTrue(jsonBody.contains('"ExternalId":"' + acc.Id + '"'));
    Assert.isTrue(jsonBody.contains('"MemberNumber":"' + acc.MemberNumber__c + '"'));
    Assert.isTrue(jsonBody.contains('"UseDebtorBalance":true'));
  }

  @IsTest
  static void testEncodeSMS() {

    Account acc = [
      SELECT PersonMobilePhone
      FROM Account
      LIMIT 1
    ];

    Blob result = BillectaEncodeJSON.encodeSMS(
      acc,
      'creditor-id'
    );

    String jsonBody = result.toString();

    Assert.isTrue(jsonBody.contains('"CreditorPublicId":"creditor-id"'));
    Assert.isTrue(jsonBody.contains('"ReceiverPhone":"' + acc.PersonMobilePhone + '"'));
  }

  @IsTest
  static void testEncodeBankIDRequest() {

    Blob result = BillectaEncodeJSON.encodeBankIDRequest(
      'creditor-id',
      '740121-0674'
    );

    String jsonBody = result.toString();

    Assert.isTrue(jsonBody.contains('"CreditorPublicId":"creditor-id"'));
    Assert.isTrue(jsonBody.contains('"SSN":"740121-0674"'));
    Assert.isTrue(jsonBody.contains('"TokenStartRequired":true'));
  }

  @IsTest
  static void testEncodeBankIDAuthenticationRequest() {

    Blob result = BillectaEncodeJSON.encodeBankIDAuthenticationRequest(
      'creditor-id',
      '740121-0674'
    );

    String jsonBody = result.toString();

    Assert.isTrue(jsonBody.contains('"CreditorPublicId":"creditor-id"'));
    Assert.isTrue(jsonBody.contains('"SSN":"740121-0674"'));
  }

  @IsTest
  static void testEncodeCreateDebtorAutogiro() {

    Account acc = [
      SELECT Id,
        BillectaID__c,
        SocialSecurityNumber__c,
        FirstName,
        LastName,
        CurrentCOAdress__c,
        CurrentStreetAdress__c,
        CurrentZipCode__c,
        CurrentCity__c,
        CurrentCountryCode__c,
        PersonMobilePhone,
        PersonEmail,
        MemberNumber__c,
        ProtectedIdentity__c,
        DistributionMethod__c,
        PaymentMethod__c,
        IsDistributionPostalPaperOnly__c,
        AG_BankAccountNumber__c,
        AG_BankClearingNumber__c,
        AutogiroBank__c,
        AutogiroApprovalStatus__c
      FROM Account
      LIMIT 1
    ];

    acc.PaymentMethod__c = 'AG';
    acc.AG_BankAccountNumber__c = '123456789';
    acc.AG_BankClearingNumber__c = '1234';
    acc.AutogiroBank__c = 'Swedbank';
    acc.AutogiroApprovalStatus__c = 'Approved';

    Blob result = BillectaEncodeJSON.encodeCreateDebtor(
      acc,
      'creditor-id'
    );

    String jsonBody = result.toString();

    Assert.isTrue(jsonBody.contains('"Autogiro"'));
    Assert.isTrue(jsonBody.contains('"AccountNo":"123456789"'));
    Assert.isTrue(jsonBody.contains('"ClearingNo":"1234"'));
    Assert.isTrue(jsonBody.contains('"PaymentServiceSupplier":"Swedbank"'));
  }

  @IsTest
  static void testEncodeCreateDebtorKivra() {

    Account acc = [
      SELECT Id,
        BillectaID__c,
        SocialSecurityNumber__c,
        FirstName,
        LastName,
        CurrentCOAdress__c,
        CurrentStreetAdress__c,
        CurrentZipCode__c,
        CurrentCity__c,
        CurrentCountryCode__c,
        PersonMobilePhone,
        PersonEmail,
        MemberNumber__c,
        ProtectedIdentity__c,
        DistributionMethod__c,
        PaymentMethod__c,
        IsDistributionPostalPaperOnly__c
      FROM Account
      LIMIT 1
    ];

    acc.BillectaID__c = 'billecta-id';
    acc.PaymentMethod__c = 'BG';
    acc.DistributionMethod__c = 'Post';
    acc.IsDistributionPostalPaperOnly__c = false;

    Blob result = BillectaEncodeJSON.encodeCreateDebtor(
      acc,
      'creditor-id'
    );

    String jsonBody = result.toString();

    Assert.isTrue(jsonBody.contains('"DeliveryMethod":"Kivra"'));
  }
}