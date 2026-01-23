/**
 * @description       :
 * @author            : Malin Nilsson (Stretch Customer AB)
 * @group             :
 * @last modified on  : 2025-07-03
 * @last modified by  : Malin Nilsson (Stretch Customer AB)
 **/
@isTest
public class Billecta_Test {
  @testSetup
  static void setup() {
    System.debug('*** Billecta_Test Setup() starting ***');

    TestDataFactory.setupBasicTestData();
    TestDataFactorySetupParams setupParams = new TestDataFactorySetupParams();
    setupParams.numberOfAccounts = 1;
    setupParams.addMembershipsToMembers = true;
    setupParams.numberOfUnpaidInvoices = 5;
    TestDataFactory.setupTestData(setupParams);
  }

  public class MockHttpResponseGeneratorBillecta implements HttpCalloutMock {
    // Implement this interface method
    public HTTPResponse respond(HTTPRequest request) {
      HttpResponse response = new HttpResponse();
      response.setHeader('Content-Type', 'application/json');
      response.setBody(
        '{"PublicId":"TestBillectaId"},"HasError":false,"ErrorMessage":null}'
      );
      response.setStatusCode(200);
      return response;
    }
  }

  public class MockHttpResponseGeneratorBillectaSwishStatus implements HttpCalloutMock {
    // Implement this interface method
    public HTTPResponse respond(HTTPRequest request) {
      HttpResponse response = new HttpResponse();
      response.setHeader('Content-Type', 'application/json');
      response.setBody(
        ' {"PaymentRequestToken": "877b9313-da55-46ab-b93b-cf8fb893b9c2",' +
        '"Status": "Paid",' +
        '"PaidDate": "2021-01-18 18:28:43+01:00",' +
        '"Created": "2021-01-18 18:26:43+01:00",' +
        '"Amount": {' +
        '"CurrencyCode": "SEK",' +
        '"Value": 10000,' +
        '"ValueForView": 100.0}' +
        '},"HasError":false,"ErrorMessage":null}'
      );
      response.setStatusCode(200);
      return response;
    }
  }

  public class MockHttpResponseGeneratorBillectaOK implements HttpCalloutMock {
    // Implement this interface method
    public HTTPResponse respond(HTTPRequest request) {
      HttpResponse response = new HttpResponse();
      response.setHeader('Content-Type', 'application/json');
      response.setBody('{"OK"},"HasError":false,"ErrorMessage":null}');
      response.setStatusCode(200);
      return response;
    }
  }

  public class MockHttpResponseGeneratorBillectaError implements HttpCalloutMock {
    // Implement this interface method
    public HTTPResponse respond(HTTPRequest request) {
      HttpResponse response = new HttpResponse();
      response.setHeader('Content-Type', 'application/json');
      response.setBody('{"Failed"},"HasError":True,"ErrorMessage":"FAIL"}');
      response.setStatusCode(400);
      return response;
    }
  }

  public class MockHttpResponseGeneratorBillectaDebtorStatus implements HttpCalloutMock {
    // Implement this interface method
    public HTTPResponse respond(HTTPRequest request) {
      HttpResponse response = new HttpResponse();
      response.setHeader('Content-Type', 'application/json');
      response.setBody(
        '{"Balance_c": 100.0,' +
        '"OverdueAmount_c": 50.0,' +
        '"ReminderStatus_c": 0,' +
        '"LatestPaymentDate_c": "",' +
        '"PaymentMethod_c": "BG",' +
        '"DistributionMethod_c": "E-faktura",' +
        '"AutogiroApprovalStatus_c": "",' +
        '"BillectaID_c": "a3861233-0f46-46d2-b36b-37e600751fc9"' +
        '},"HasError":false,"ErrorMessage":null}'
      );
      response.setStatusCode(200);
      return response;
    }
  }

  public class MockHttpResponseGeneratorBillectaInvoiceStatus implements HttpCalloutMock {
    // Implement this interface method
    public HTTPResponse respond(HTTPRequest request) {
      HttpResponse response = new HttpResponse();
      response.setHeader('Content-Type', 'application/json');
      response.setBody(
        '{"DistributionMethod_c": "Post",' +
        '"Amount_c": 270.0,' +
        '"PaymentMethod_c": "BG",' +
        '"RemainingAmount_c": 270.0,' +
        '"PaymentStatus_c": "Ej betald",' +
        '"Name": "46",' +
        '"OCR_c": "322193325523250",' +
        '"ExpirationDate_c": "2020-12-31",' +
        '"InvoiceDate_c": "2020-12-11",' +
        '"InvoiceLink_c": "https:",' +
        '"InvoicePeriodStart_c": "",' +
        '"InvoicePeriodEnd_c": "",' +
        '"PaymentDate_c": "",' +
        '"Reminder1_c": "Ej skickad",' +
        '"Reminder2_c": "Ej skickad",' +
        '"Reminder3_c": "Ej skickad",' +
        '"InvoiceStatus_c": "Skickad",' +
        '"MembershipCategory_c": "Yrkesverksam",' +
        '"FeeCategory_c": "Fullbetalande",' +
        '"AutogiroStatusMessage_c": "",' +
        '"AutogiroStatusMessageDate_c": ""' +
        '}' +
        '},"HasError":false,"ErrorMessage":null}'
      );
      response.setStatusCode(200);
      return response;
    }
  }

  @isTest
  static void testCreateDebtor() {
    System.debug('*** Billecta_Test testCreateDebtor() starting ***');
    List<BillectaInitiateSendDebtor.Request> requests = new List<BillectaInitiateSendDebtor.Request>();

    Account testAcc = [SELECT Id FROM Account LIMIT 1];

    Test.setMock(
      HttpCalloutMock.class,
      new MockHttpResponseGeneratorBillecta()
    );
    Test.startTest();

    BillectaInitiateSendDebtor.Request req = new BillectaInitiateSendDebtor.Request();
    req.recordId = testAcc.Id;
    req.billectaAction = BillectaValidationHelper.ACTION_CREATE;
    requests.add(req);

    List<BillectaInitiateSendDebtor.Response> responses = BillectaInitiateSendDebtor.sendDebtorWithPaymentMethod(requests);

    Test.stopTest();

    Account result = [
      SELECT Id, BillectaID__c
      FROM Account
      WHERE Id = :testAcc.Id
    ];
    System.assertEquals(result.BillectaID__c, 'TestBillectaId');
    System.assertEquals(responses.size(), 1);
    System.assertEquals(responses[0].errorMsg, null);

  }

  @isTest
  static void testUpdateDebtor() {
    System.debug('*** Billecta_Test testUpdateDebtor() starting ***');

    Account testAcc = [
      SELECT Id, FirstName, BillectaID__c
      FROM Account
      LIMIT 1
    ];
    testAcc.FirstName = 'NewName';
    testAcc.BillectaID__c = 'TestBillectaId';
    testAcc.PaymentMethod__c = 'BG';
    testAcc.DistributionMethod__c = 'Post';
    update testAcc;

    List<BillectaInitiateSendDebtor_WithoutPM.Request> requests = new List<BillectaInitiateSendDebtor_WithoutPM.Request>();

    Test.setMock(
      HttpCalloutMock.class,
      new MockHttpResponseGeneratorBillecta()
    );
    Test.startTest();
    BillectaInitiateSendDebtor_WithoutPM.Request req = new BillectaInitiateSendDebtor_WithoutPM.Request();
    req.billectaAction = BillectaValidationHelper.ACTION_UPDATE;
    req.recordId = testAcc.Id;
    requests.add(req);

    BillectaInitiateSendDebtor_WithoutPM.sendDebtorWithoutPaymentMethod(
      requests
    );

    Test.stopTest();
  }

  @isTest
  static void testCreateDebtorBatch() {
    System.debug('*** Billecta_Test testCreateDebtorBatch() starting ***');

    Account testAcc = [SELECT Id FROM Account LIMIT 1];
    Set<Id> testAccs = new Set<Id>();
    testAccs.add(testAcc.Id);

    Test.setMock(
      HttpCalloutMock.class,
      new MockHttpResponseGeneratorBillecta()
    );
    Test.startTest();

    BillectaUpdateDebtorsBatch BC = new BillectaUpdateDebtorsBatch(
      testAccs,
      BillectaValidationHelper.ACTION_CREATE,
      false
    );
    Id batchId = Database.executeBatch(BC, 1);

    Test.stopTest();

    Account result = [
      SELECT Id, BillectaID__c
      FROM Account
      WHERE Id = :testAcc.Id
    ];
    System.assertEquals(result.BillectaID__c, 'TestBillectaId');
  }

  @isTest
  static void testUpdateDebtorBatch() {
    System.debug('*** Billecta_Test testUpdateDebtorBatch() starting ***');
    Account testAcc = [
      SELECT Id, FirstName, BillectaID__c
      FROM Account
      LIMIT 1
    ];

    testAcc.FirstName = 'NewName';
    testAcc.BillectaID__c = 'TestBillectaId';
    testAcc.PaymentMethod__c = 'BG';
    testAcc.DistributionMethod__c = 'Post';
    update testAcc;

    Set<Id> testIds = new Set<Id>();
    testIds.add(testAcc.Id);

    Test.setMock(
      HttpCalloutMock.class,
      new MockHttpResponseGeneratorBillecta()
    );
    Test.startTest();

    BillectaUpdateDebtorsBatch BC = new BillectaUpdateDebtorsBatch(
      testIds,
      BillectaValidationHelper.ACTION_UPDATE,
      false
    );
    Id batchId = Database.executeBatch(BC, 1);

    Test.stopTest();
  }

    @isTest
  static void testUpdateDebtorBatchWExtraMsg() {
    System.debug('*** Billecta_Test testUpdateDebtorBatch() starting ***');

    Account testAcc = [
      SELECT Id, FirstName, BillectaID__c
      FROM Account
      LIMIT 1
    ];
    testAcc.FirstName = 'NewName';
    testAcc.BillectaID__c = 'TestBillectaId';
    testAcc.PaymentMethod__c = 'BG';
    testAcc.DistributionMethod__c = 'Post';
    testAcc.LatestSentPMDetails_Billecta__c = 'Test'; // set to avoid triggering the callout when update testAcc
    update testAcc;

    Set<Id> testAccs = new Set<Id>();
    testAccs.add(testAcc.Id);

    Test.setMock(
      HttpCalloutMock.class,
      new MockHttpResponseGeneratorBillecta()
    );
    Test.startTest();

    BillectaUpdateDebtorsBatch BC = new BillectaUpdateDebtorsBatch(
      testAccs,
      BillectaValidationHelper.ACTION_UPDATE,
      true,
      'Extra Message for Callout Record'
    );
    Id batchId = Database.executeBatch(BC, 1);

    Test.stopTest();

    Account resultAcc = [
      SELECT Id, DistributionMethod__c, LatestSentPMDetails_Billecta__c
      FROM Account
      WHERE Id = :testAcc.Id
    ];

    List<Callout__c> callouts = [
      SELECT Id, ExtraMessage__c, Type__c
      FROM Callout__c
      WHERE Account__c = :testAcc.Id order by CreatedDate desc
    ];
    System.assertEquals(callouts[0].ExtraMessage__c, 'Extra Message for Callout Record');
    System.assertEquals(resultAcc.DistributionMethod__c, 'Kivra');

  }

  @isTest
  static void testUpdateDebtorBatch_invalidAction() {
    System.debug('*** Billecta_Test testUpdateDebtorBatch() starting ***');

    Account testAcc = [
      SELECT Id, FirstName, BillectaID__c
      FROM Account
      LIMIT 1
    ];
    testAcc.FirstName = 'NewName';
    testAcc.BillectaID__c = 'TestBillectaId';
    testAcc.PaymentMethod__c = 'BG';
    testAcc.DistributionMethod__c = 'Post';
    update testAcc;

    Set<Id> testAccs = new Set<Id>();
    testAccs.add(testAcc.Id);

    Test.setMock(
      HttpCalloutMock.class,
      new MockHttpResponseGeneratorBillecta()
    );

    Test.startTest();
    Boolean errorCaught = false;

    try {
      BillectaUpdateDebtorsBatch BC = new BillectaUpdateDebtorsBatch(
        testAccs,
        'invalidBillectaAction',
        false
      );

      Id batchId = Database.executeBatch(BC, 1);
    } catch (Exception e) {
      errorCaught = true;
    }
    Test.stopTest();

    Assert.areEqual(true, errorCaught);
  }

  @isTest
  static void testUpdateDebtorBatch_errIdAlreadyExists() {
    System.debug('*** Billecta_Test testUpdateDebtorBatch() starting ***');

    Account testAcc = [
      SELECT Id, FirstName, BillectaID__c
      FROM Account
      LIMIT 1
    ];
    testAcc.FirstName = 'NewName';
    testAcc.BillectaID__c = 'TestBillectaId';
    testAcc.PaymentMethod__c = 'BG';
    testAcc.DistributionMethod__c = 'Post';
    update testAcc;

    Set<Id> testAccs = new Set<Id>();
    testAccs.add(testAcc.Id);

    Test.setMock(
      HttpCalloutMock.class,
      new MockHttpResponseGeneratorBillecta()
    );
    Test.startTest();

    BillectaUpdateDebtorsBatch BC = new BillectaUpdateDebtorsBatch(
      testAccs,
      BillectaValidationHelper.ACTION_CREATE,
      false
    );
    Id batchId = Database.executeBatch(BC, 1);

    Test.stopTest();

    List<DebugLog__c> logs = [
      SELECT Id, Message__c
      FROM DebugLog__c
      ORDER BY CreatedDate
    ];

    Assert.areEqual(1, logs.size());
  }

  @isTest
  static void testScheduleUpdateBatch() {
    Account testAcc = [
      SELECT Id, BillectaMarkedForUpdate__c
      FROM Account
      LIMIT 1
    ];

    testAcc.BillectaMarkedForUpdate__c = System.now();
    update testAcc;

    Test.setMock(
      HttpCalloutMock.class,
      new MockHttpResponseGeneratorBillecta()
    );

    Test.startTest();
    BillectaSchedulableSendDebtor.scheduleIt();
    Test.stopTest();
  }

  @isTest
  static void testScheduleUpdateDefaultPMBatch() {
    Account testAcc = [
      SELECT Id, DistributionMethod__c
      FROM Account
      LIMIT 1
    ];
    testAcc.BillectaID__c = 'TestBillectaId';

    update testAcc;

    Test.setMock(
      HttpCalloutMock.class,
      new MockHttpResponseGeneratorBillecta()
    );

    Test.startTest();
    BillectaSchedulableSendDebtorDefaultPM.scheduleIt();
    // Execute it
    BillectaSchedulableSendDebtorDefaultPM.runJob();
    Test.stopTest();
  }


  @isTest
  static void testUpdateDebtor_Error() {
    System.debug('*** Billecta_Test testUpdateDebtor_Error() starting ***');

    Account testAcc = [
      SELECT Id, FirstName, BillectaID__c
      FROM Account
      LIMIT 1
    ];
    testAcc.FirstName = 'NewName';
    testAcc.BillectaID__c = 'TestBillectaId';
    testAcc.PaymentMethod__c = 'BG';
    testAcc.DistributionMethod__c = 'Post';
    update testAcc;

    List<BillectaInitiateSendDebtor_WithoutPM.Request> requests = new List<BillectaInitiateSendDebtor_WithoutPM.Request>();

    Test.setMock(
      HttpCalloutMock.class,
      new MockHttpResponseGeneratorBillectaError()
    );
    Test.startTest();
    BillectaInitiateSendDebtor_WithoutPM.Request req = new BillectaInitiateSendDebtor_WithoutPM.Request();
    req.recordId = testAcc.Id;
    req.billectaAction = BillectaValidationHelper.ACTION_UPDATE;
    requests.add(req);

    BillectaInitiateSendDebtor_WithoutPM.sendDebtorWithoutPaymentMethod(
      requests
    );

    Test.stopTest();
  }

  @isTest
  static void testSendDebtor_invalidBillectaAction() {
    System.debug(
      '*** Billecta_Test testSendDebtor_invalidBillectaAction() starting ***'
    );

    Account testAcc = [
      SELECT Id, FirstName, BillectaID__c
      FROM Account
      LIMIT 1
    ];

    List<BillectaInitiateSendDebtor.Request> requests = new List<BillectaInitiateSendDebtor.Request>();
    List<BillectaInitiateSendDebtor.Response> validationErrs = new List<BillectaInitiateSendDebtor.Response>();

    Test.startTest();

    BillectaInitiateSendDebtor.Request r = new BillectaInitiateSendDebtor.Request();
    r.recordId = testAcc.Id;    
    r.billectaAction = 'invalidAction'; // casues error 

    requests.add(r);

    validationErrs = BillectaInitiateSendDebtor.sendDebtorWithPaymentMethod(
      requests
    );

    Test.stopTest();

    System.debug(LoggingLevel.DEBUG, validationErrs);
    Assert.areEqual(1, validationErrs.size());
  }

  @isTest
  static void testSendDebtorNoPM_invalidBillectaAction() {
    System.debug(
      '*** Billecta_Test testSendDebtorNoPM_invalidBillectaAction() starting ***'
    );
    Account testAcc = [
      SELECT Id, FirstName, BillectaID__c
      FROM Account
      LIMIT 1
    ];

    List<BillectaInitiateSendDebtor_WithoutPM.Request> requests = new List<BillectaInitiateSendDebtor_WithoutPM.Request>();
    List<BillectaInitiateSendDebtor_WithoutPM.Response> validationErrs = new List<BillectaInitiateSendDebtor_WithoutPM.Response>();

    Test.startTest();

    BillectaInitiateSendDebtor_WithoutPM.Request r = new BillectaInitiateSendDebtor_WithoutPM.Request();
    r.recordId = testAcc.Id; 
    r.billectaAction = 'invalidAction'; // casues error

    requests.add(r);

    validationErrs = BillectaInitiateSendDebtor_WithoutPM.sendDebtorWithoutPaymentMethod(
      requests
    );

    Test.stopTest();

    System.debug(LoggingLevel.DEBUG, validationErrs);
    Assert.areEqual(1, validationErrs.size());
  }

  @isTest
  static void testCreateDebtor_errIdAlreadyExists() {
    System.debug(
      '*** Billecta_Test testCreateDebtor_errIdAlreadyExists() starting ***'
    );

    Account testAcc = [SELECT Id, BillectaId__c FROM Account LIMIT 1];
    testAcc.BillectaID__c = 'TestBillectaId';
    update testAcc;

    List<BillectaInitiateSendDebtor.Request> requests = new List<BillectaInitiateSendDebtor.Request>();
    List<BillectaInitiateSendDebtor.Response> validationErrs = new List<BillectaInitiateSendDebtor.Response>();

    Test.startTest();
    BillectaInitiateSendDebtor.Request req = new BillectaInitiateSendDebtor.Request();
    req.recordId = testAcc.Id;
    req.billectaAction = BillectaValidationHelper.ACTION_CREATE;
    requests.add(req);

    validationErrs = BillectaInitiateSendDebtor.sendDebtorWithPaymentMethod(
      requests
    );

    Test.stopTest();

    System.debug(LoggingLevel.DEBUG, validationErrs);
    Assert.areEqual(1, validationErrs.size());
  }

  @isTest
  static void testCreateDebtor_errMissingId() {
    System.debug(
      '*** Billecta_Test testCreateDebtor_errMissingId() starting ***'
    );

    Account testAcc = [SELECT Id FROM Account LIMIT 1];

    List<BillectaInitiateSendDebtor.Request> requests = new List<BillectaInitiateSendDebtor.Request>();
    List<BillectaInitiateSendDebtor.Response> validationErrs = new List<BillectaInitiateSendDebtor.Response>();

    Test.startTest();
    BillectaInitiateSendDebtor.Request req = new BillectaInitiateSendDebtor.Request();
    req.recordId = testAcc.Id; // The account has BillectaId = null
    req.billectaAction = BillectaValidationHelper.ACTION_UPDATE;
    requests.add(req);

    validationErrs = BillectaInitiateSendDebtor.sendDebtorWithPaymentMethod(
      requests
    );

    Test.stopTest();

    System.debug(LoggingLevel.DEBUG, validationErrs);
    Assert.areEqual(1, validationErrs.size());
  }

  @isTest
  static void testCreateInvoice() {
    System.debug('*** Billecta_Test testCreateInvoice() starting ***');

    Account testAcc = [SELECT Id FROM Account LIMIT 1];
    List<Invoice__c> beforeTestInvs = [
      SELECT Id, BillectaId__c
      FROM Invoice__c
      WHERE Person__c = :testAcc.Id
    ];

    Test.setMock(
      HttpCalloutMock.class,
      new MockHttpResponseGeneratorBillecta()
    );
    Test.startTest();

    BillectaDebtorStatusUpdateHelper.sendInvoice(testAcc.Id);

    Test.stopTest();

    List<Invoice__c> afterTestInvs = [
      SELECT Id, BillectaId__c
      FROM Invoice__c
      WHERE Person__c = :testAcc.Id
    ];

    // 5 created in test setup and one from this test method
    Integer newInvCount = afterTestInvs.size() - beforeTestInvs.size();
    Assert.areEqual(1, newInvCount);
  }

  @isTest
  static void testCreateMultipleInvoices() {
    System.debug('*** Billecta_Test testCreateMultipleInvoices() starting ***');

    List<Account> testAccs = [
      SELECT
        Id,
        Name,
        SocialSecurityNumber__c,
        MemberNumber__c,
        MembershipCategory__c,
        FeeCategory__c,
        SendToAkassa__c,
        UnemploymentFundThroughAkavia__c
      FROM Account
    ];
    system.debug('In test class : accounts in test: ' + testAccs);
    Invoice__c testInv = new Invoice__c(
      Person__c = testAccs[0].Id,
      BillectaId__c = 'TestBillectaId'
    );
    insert testInv;

    Test.setMock(
      HttpCalloutMock.class,
      new MockHttpResponseGeneratorBillectaOK()
    );
    Test.startTest();

    ApexPages.StandardSetController sc = new ApexPages.StandardSetController(
      testAccs
    );
    sc.setSelected(testAccs);
    BillectaMultipleInvoicesActions obj = new BillectaMultipleInvoicesActions(
      sc
    );

    pageReference ref = obj.CreateInvoices();

    Test.stopTest();
  }

  @isTest
  static void testCreateMultipleInvoicesERROR() {
    System.debug(
      '*** Billecta_Test testCreateMultipleInvoicesERROR() starting ***'
    );

    List<Account> testAccs = [
      SELECT
        Id,
        Name,
        SocialSecurityNumber__c,
        MemberNumber__c,
        MembershipCategory__c,
        FeeCategory__c,
        SendToAkassa__c,
        UnemploymentFundThroughAkavia__c
      FROM Account
    ];

    Invoice__c testInv = new Invoice__c(
      Person__c = testAccs[0].Id,
      BillectaId__c = 'TestBillectaId'
    );
    insert testInv;

    Test.setMock(
      HttpCalloutMock.class,
      new MockHttpResponseGeneratorBillectaError()
    );
    Test.startTest();

    ApexPages.StandardSetController sc = new ApexPages.StandardSetController(
      testAccs
    );
    sc.setSelected(testAccs);
    BillectaMultipleInvoicesActions obj = new BillectaMultipleInvoicesActions(
      sc
    );

    pageReference ref = obj.CreateInvoices();

    Test.stopTest();
  }

  // This tests the functionality used from visual force page (Makulera Fakturor - available from Account List view.)
  @isTest
  static void testCancelMultipleInvoices() {
    System.debug('*** Billecta_Test testCancelMultipleInvoices() starting ***');

    List<Account> testAccs = [SELECT Id FROM Account];

    Test.setMock(
      HttpCalloutMock.class,
      new MockHttpResponseGeneratorBillectaOK()
    );
    Test.startTest();

    ApexPages.StandardSetController sc = new ApexPages.StandardSetController(
      testAccs
    );
    sc.setSelected(testAccs);
    BillectaMultipleInvoicesActions obj = new BillectaMultipleInvoicesActions(
      sc
    );

    pageReference ref = obj.CancelInvoices();

    ref = obj.ReturnToAccounts();

    Test.stopTest();
  }

  // This tests the functionality used from visual force page (Makulera Fakturor - available from Account List view.)
  @isTest
  static void testCancelMultipleInvoicesERROR() {
    System.debug(
      '*** Billecta_Test testCancelMultipleInvoicesERROR() starting ***'
    );

    List<Account> testAccs = [SELECT Id FROM Account];

    Test.setMock(
      HttpCalloutMock.class,
      new MockHttpResponseGeneratorBillectaError()
    );
    Test.startTest();

    ApexPages.StandardSetController sc = new ApexPages.StandardSetController(
      testAccs
    );
    sc.setSelected(testAccs);
    BillectaMultipleInvoicesActions obj = new BillectaMultipleInvoicesActions(
      sc
    );

    pageReference ref = obj.CancelInvoices();

    Test.stopTest();
  }

  @isTest
  static void testCancelMultipleInvoicesInvocable_byAccIds() {
    System.debug(
      '*** Billecta_Test testCancelMultipleInvoicesInvocable_byAccIds() starting ***'
    );

    List<Account> testAccs = [SELECT Id FROM Account];

    Test.setMock(
      HttpCalloutMock.class,
      new MockHttpResponseGeneratorBillectaOK()
    );
    Test.startTest();

    List<Id> inputIds = new List<Id>();
    for (Account a : testAccs) {
      inputIds.add(a.Id);
    }
    BillectaCancelInvociesInvocable.BillectaCancelInvociesInvocable(inputIds);
    Test.stopTest();

    List<Invoice__c> invoices = [SELECT ID, PaymentStatus__c FROM Invoice__c];
    for (Invoice__c i : invoices) {
      Assert.areEqual('Makulerad', i.PaymentStatus__c);
    }
  }

  @isTest
  static void testCancelMultipleInvoicesInvocable_byAccs() {
    System.debug(
      '*** Billecta_Test testCancelMultipleInvoicesInvocable_byAccs() starting ***'
    );

    List<Account> testAccs = [SELECT Id FROM Account];

    Test.setMock(
      HttpCalloutMock.class,
      new MockHttpResponseGeneratorBillectaOK()
    );
    Test.startTest();
    List<Account> accs = [SELECT Id FROM Account];
    BillectaCancelInvociesInvocable inv = new BillectaCancelInvociesInvocable(
      accs
    );
    Test.stopTest();

    List<Invoice__c> invoices = [SELECT ID, PaymentStatus__c FROM Invoice__c];
    for (Invoice__c i : invoices) {
      Assert.areEqual('Makulerad', i.PaymentStatus__c);
    }
  }

  @isTest
  static void testCancelMultipleInvoicesInvocableERROR_byAccIds() {
    System.debug(
      '*** Billecta_Test testCancelMultipleInvoicesInvocableERROR_byAccIds() starting ***'
    );

    List<Account> testAccs = [SELECT Id FROM Account];

    Test.setMock(
      HttpCalloutMock.class,
      new MockHttpResponseGeneratorBillectaError()
    );
    Test.startTest();

    List<Id> inputIds = new List<Id>();
    for (Account a : testAccs) {
      inputIds.add(a.Id);
    }
    BillectaCancelInvociesInvocable.BillectaCancelInvociesInvocable(inputIds);
    Test.stopTest();

    List<Invoice__c> invoices = [SELECT ID, PaymentStatus__c FROM Invoice__c];
    for (Invoice__c i : invoices) {
      Assert.areNotEqual('Makulerad', i.PaymentStatus__c);
    }
  }

  @isTest
  static void testCancelInvoice() {
    System.debug('*** Billecta_Test testCancelInvoice() starting ***');

    Account testAcc = [SELECT Id FROM Account LIMIT 1];
    Invoice__c testInv = [SELECT Id FROM Invoice__c LIMIT 1];
    Test.setMock(
      HttpCalloutMock.class,
      new MockHttpResponseGeneratorBillectaOK()
    );
    Test.startTest();

    BillectaInvoiceUpdateHelper obj = new BillectaInvoiceUpdateHelper();
    obj = BillectaInvoiceUpdateHelper.cancelInvoice(testInv.Id);

    Test.stopTest();

    List<Invoice__c> testInvs = [
      SELECT Id, PaymentStatus__c
      FROM Invoice__c
      WHERE Person__c = :testAcc.Id AND PaymentStatus__c = 'Makulerad'
    ];

    System.assertEquals(1, testInvs.size());
    System.assertEquals(testInvs[0].PaymentStatus__c, 'Makulerad');
  }

  @isTest
  static void testCancelInvoiceError() {
    System.debug('*** Billecta_Test testCancelInvoiceError() starting ***');

    Account testAcc = [SELECT Id FROM Account LIMIT 1];
    Invoice__c testInv = [SELECT Id FROM Invoice__c LIMIT 1];

    Test.setMock(
      HttpCalloutMock.class,
      new MockHttpResponseGeneratorBillectaError()
    );
    Test.startTest();

    BillectaInvoiceUpdateHelper obj = new BillectaInvoiceUpdateHelper();
    obj = BillectaInvoiceUpdateHelper.cancelInvoice(testInv.Id);

    Test.stopTest();

    List<Invoice__c> testInvs = [
      SELECT Id, PaymentStatus__c
      FROM Invoice__c
      WHERE Person__c = :testAcc.Id AND Id = :testInv.Id
    ];

    System.assertEquals(1, testInvs.size());
    System.assertNotEquals(testInvs[0].PaymentStatus__c, 'Makulerad');

    List<DebugLog__c> DL = [SELECT Id FROM DebugLog__c];

    System.assertEquals(1, DL.size());
  }

  @isTest
  static void testPauseInvoice() {
    System.debug('*** Billecta_Test testPauseInvoice() starting ***');

    Account testAcc = [SELECT Id FROM Account LIMIT 1];

    List<String> accIds = new List<String>();
    accIds.add(testAcc.Id);

    Test.setMock(
      HttpCalloutMock.class,
      new MockHttpResponseGeneratorBillectaOK()
    );
    Test.startTest();

    BillectaInitiatePauseInvoice.pauseInvoice(accIds);

    Test.stopTest();

    List<Invoice__c> testInvs = [
      SELECT Id, PaymentStatus__c
      FROM Invoice__c
      WHERE Person__c = :testAcc.Id
    ];

    System.assertEquals(5, testInvs.size());
    System.assertEquals(testInvs[0].PaymentStatus__c, 'Pausad');
  }

  @isTest
  static void testResumeInvoice() {
    System.debug('*** Billecta_Test testResumeInvoice() starting ***');

    Account testAcc = [SELECT Id FROM Account LIMIT 1];
    List<Invoice__c> testInvs = [SELECT Id FROM Invoice__c];

    for (Invoice__c i : testInvs) {
      i.PaymentStatus__c = 'Pausad';
    }

    update testInvs;

    List<String> accIds = new List<String>();
    accIds.add(testAcc.Id);

    Test.setMock(
      HttpCalloutMock.class,
      new MockHttpResponseGeneratorBillectaOK()
    );
    Test.startTest();

    // There are no functionality here that acutually do resumes a paused invoice. This functionality seems to not be completed
    BillectaInitiateResumeInvoice.resumeInvoice(accIds);

    Test.stopTest();

    // List<Invoice__c> testInvsResult = [
    //   SELECT Id, PaymentStatus__c
    //   FROM Invoice__c
    //   WHERE Person__c = :testAcc.Id AND PaymentStatus__c = 'Ej betald'
    // ];

    //System.assertEquals(5, testInvsResult.size());
    // System.assertEquals(testInvsResult[0].PaymentStatus__c, 'Ej betald');
  }
  @isTest
  static void testInitSwishPayment() {
    System.debug('*** Billecta_Test testInitSwishPayment() starting ***');

    Account testAcc = [SELECT Id FROM Account LIMIT 1];
    Invoice__c testInv = new Invoice__c(
      Person__c = testAcc.Id,
      BillectaId__c = 'TestBillectaId'
    );
    insert testInv;

    Test.setMock(
      HttpCalloutMock.class,
      new MockHttpResponseGeneratorBillecta()
    );
    Test.startTest();

    BillectaInvoiceUpdateHelper obj = new BillectaInvoiceUpdateHelper();
    obj = BillectaInvoiceUpdateHelper.initSwishPayment(testInv.Id);

    BillectaSwishHelper obj2 = BillectaSwishHelper.initData(testInv.Id);
    String result = BillectaSwishHelper.initSwishPayment(obj2);

    Test.stopTest();

    System.assertEquals('Waiting', obj.Status);
    System.assertEquals('TestBillectaId', result);
  }

  @isTest
  static void testInitSwishPaymentERROR() {
    System.debug('*** Billecta_Test testInitSwishPaymentERROR() starting ***');

    Account testAcc = [SELECT Id FROM Account LIMIT 1];
    Invoice__c testInv = new Invoice__c(
      Person__c = testAcc.Id,
      BillectaId__c = 'TestBillectaId'
    );
    insert testInv;

    Test.setMock(
      HttpCalloutMock.class,
      new MockHttpResponseGeneratorBillectaError()
    );
    Test.startTest();

    BillectaInvoiceUpdateHelper obj = new BillectaInvoiceUpdateHelper();
    obj = BillectaInvoiceUpdateHelper.initSwishPayment(testInv.Id);

    BillectaSwishHelper obj2 = BillectaSwishHelper.initData(testInv.Id);
    String result = BillectaSwishHelper.initSwishPayment(obj2);

    Test.stopTest();

    System.assertEquals('Failed', obj.Status);
    System.assertEquals(result.contains('Failed'), true);
  }

  @isTest
  static void testGetSwishPaymentStatus() {
    System.debug('*** Billecta_Test testGetSwishPaymentStatus() starting ***');

    Account testAcc = [SELECT Id FROM Account LIMIT 1];
    Invoice__c testInv = new Invoice__c(
      Person__c = testAcc.Id,
      BillectaId__c = 'TestBillectaId'
    );
    insert testInv;

    Test.setMock(
      HttpCalloutMock.class,
      new MockHttpResponseGeneratorBillectaSwishStatus()
    );
    Test.startTest();

    BillectaInvoiceUpdateHelper obj = new BillectaInvoiceUpdateHelper();
    obj.Status = 'Waiting';
    obj = BillectaInvoiceUpdateHelper.getSwishRequestStatus(
      obj,
      'TestPuplicId'
    );

    BillectaSwishHelper obj2 = BillectaSwishHelper.initData(testInv.Id);
    obj2.Status = 'Waiting';
    obj2 = BillectaSwishHelper.getSwishRequestStatus(obj2, 'TestPuplicId');

    Test.stopTest();

    System.assertEquals('Paid', obj.Status);
    System.assertEquals('Paid', obj2.Status);
  }

  @isTest
  static void testGetSwishPaymentStatusERROR() {
    System.debug(
      '*** Billecta_Test testGetSwishPaymentStatusERROR() starting ***'
    );

    Account testAcc = [SELECT Id FROM Account LIMIT 1];
    Invoice__c testInv = new Invoice__c(
      Person__c = testAcc.Id,
      BillectaId__c = 'TestBillectaId'
    );
    insert testInv;

    Test.setMock(
      HttpCalloutMock.class,
      new MockHttpResponseGeneratorBillectaError()
    );
    Test.startTest();

    BillectaInvoiceUpdateHelper obj = new BillectaInvoiceUpdateHelper();
    obj.Status = 'Waiting';
    obj = BillectaInvoiceUpdateHelper.getSwishRequestStatus(
      obj,
      'TestPuplicId'
    );

    BillectaSwishHelper obj2 = BillectaSwishHelper.initData(testInv.Id);
    obj2.Status = 'Waiting';
    obj2 = BillectaSwishHelper.getSwishRequestStatus(obj2, 'TestPuplicId');

    Test.stopTest();

    System.assertEquals('Failed', obj.Status);
    System.assertEquals('Failed', obj2.Status);
  }

  @isTest
  static void testUpdateDebtorStatus() {
    System.debug('*** Billecta_Test testUpdateDebtorStatus() starting ***');

    Account testAcc = [SELECT Id FROM Account LIMIT 1];

    Test.setMock(
      HttpCalloutMock.class,
      new MockHttpResponseGeneratorBillectaDebtorStatus()
    );
    Test.startTest();

    BillectaDebtorStatusUpdateHelper obj = new BillectaDebtorStatusUpdateHelper();
    obj = BillectaDebtorStatusUpdateHelper.getUpdatedInfo(testAcc.Id);

    Test.stopTest();

    testAcc = [
      SELECT
        Id,
        Balance__c,
        OverdueAmount__c,
        ReminderStatus__c,
        LatestPaymentDate__c,
        PaymentMethod__c,
        DistributionMethod__c,
        AutogiroApprovalStatus__c,
        PaymentStatusUpdated__c
      FROM Account
      WHERE Id = :testAcc.Id
    ];

    System.assertEquals(100, testAcc.Balance__c);
    System.assertEquals(50, testAcc.OverdueAmount__c);
  }

  @isTest
  static void testUpdateDebtorStatusError() {
    System.debug(
      '*** Billecta_Test testUpdateDebtorStatusError() starting ***'
    );

    Account testAcc = [SELECT Id FROM Account LIMIT 1];

    Test.setMock(
      HttpCalloutMock.class,
      new MockHttpResponseGeneratorBillectaError()
    );
    Test.startTest();

    BillectaDebtorStatusUpdateHelper obj = new BillectaDebtorStatusUpdateHelper();
    obj = BillectaDebtorStatusUpdateHelper.getUpdatedInfo(testAcc.Id);

    Test.stopTest();

    testAcc = [
      SELECT Id, Balance__c, OverdueAmount__c
      FROM Account
      WHERE Id = :testAcc.Id
    ];

    List<DebugLog__c> DL = [SELECT Id FROM DebugLog__c];

    System.assertEquals(0, testAcc.Balance__c);
    System.assertEquals(null, testAcc.OverdueAmount__c);

    System.assertEquals(1, DL.size());
  }

  @isTest
  static void testUpdateInvoiceStatus() {
    System.debug('*** Billecta_Test testUpdateInvoiceStatus() starting ***');

    Account testAcc = [SELECT Id FROM Account LIMIT 1];
    Invoice__c testInv = new Invoice__c(
      Person__c = testAcc.Id,
      BillectaId__c = 'TestBillectaId'
    );
    insert testInv;

    Test.setMock(
      HttpCalloutMock.class,
      new MockHttpResponseGeneratorBillectaInvoiceStatus()
    );
    Test.startTest();

    BillectaInvoiceUpdateHelper obj = new BillectaInvoiceUpdateHelper();
    obj = BillectaInvoiceUpdateHelper.getUpdatedInfo(testInv.Id);

    Test.stopTest();

    testInv = [
      SELECT
        Id,
        BillectaID__c,
        FeeCategory__c,
        Amount__c,
        PaymentStatus__c,
        DistributionMethod__c,
        PaymentMethod__c,
        InvoiceDate__c,
        InvoiceLink__c,
        Name,
        InvoiceStatus__c,
        ExpirationDate__c,
        PaymentDate__c,
        MembershipCategory__c,
        OCR__c,
        Person__c,
        Reminder1__c,
        Reminder2__c,
        Reminder3__c,
        RemainingAmount__c,
        UpdatedFromBillecta__c
      FROM Invoice__c
      WHERE Id = :testInv.Id
    ];

    System.assertEquals(270, testInv.Amount__c);
  }

  @isTest
  static void testUpdateInvoiceStatusError() {
    System.debug(
      '*** Billecta_Test testUpdateInvoiceStatusError() starting ***'
    );

    Account testAcc = [SELECT Id FROM Account LIMIT 1];
    Invoice__c testInv = new Invoice__c(
      Person__c = testAcc.Id,
      BillectaId__c = 'TestBillectaId'
    );
    insert testInv;

    Test.setMock(
      HttpCalloutMock.class,
      new MockHttpResponseGeneratorBillectaError()
    );
    Test.startTest();

    BillectaInvoiceUpdateHelper obj = new BillectaInvoiceUpdateHelper();
    obj = BillectaInvoiceUpdateHelper.getUpdatedInfo(testInv.Id);

    Test.stopTest();
    System.assertEquals('Failed', obj.Status);
  }

  @isTest
  static void testSendSMS() {
    System.debug('*** Billecta_Test testSendSMS() starting ***');

    System.debug('*** Billecta_Test testUpdateDebtorStatus() starting ***');

    Account testAcc = [SELECT Id FROM Account LIMIT 1];

    Test.setMock(
      HttpCalloutMock.class,
      new MockHttpResponseGeneratorBillectaOK()
    );
    Test.startTest();

    String response = BillectaDebtorStatusUpdateHelper.SendSMS(testAcc.Id);

    Test.stopTest();

    System.assertEquals('OK', response);
  }

  @isTest
  static void testSendSMSError() {
    System.debug('*** Billecta_Test testSendSMSError() starting ***');

    Account testAcc = [SELECT Id FROM Account LIMIT 1];

    Test.setMock(
      HttpCalloutMock.class,
      new MockHttpResponseGeneratorBillectaError()
    );
    Test.startTest();

    String response = BillectaDebtorStatusUpdateHelper.SendSMS(testAcc.Id);

    Test.stopTest();

    System.assertEquals('Failed', response);
  }

  @isTest
  static void testAccountGetLastUpdated() {
    System.debug('*** Billecta_Test testAccountGetLastUpdated() starting ***');

    Account testAcc = [SELECT Id FROM Account LIMIT 1];
    testAcc.PaymentStatusUpdated__c = system.now().addHours(-2);
    update testAcc;

    Test.startTest();

    BillectaDebtorStatusUpdateHelper obj = new BillectaDebtorStatusUpdateHelper();
    obj = BillectaDebtorStatusUpdateHelper.getLastUpdated(testAcc.Id);

    Test.stopTest();

    System.assertEquals('warning', obj.icon);
  }

  @isTest
  static void testInvoiceGetLastUpdated() {
    System.debug('*** Billecta_Test testInvoiceGetLastUpdated() starting ***');

    Account testAcc = [SELECT Id FROM Account LIMIT 1];
    Invoice__c testInv = new Invoice__c(
      Person__c = testAcc.Id,
      BillectaId__c = 'TestBillectaId',
      UpdatedFromBillecta__c = system.now().addHours(-2)
    );
    insert testInv;

    Test.startTest();

    BillectaInvoiceUpdateHelper obj = new BillectaInvoiceUpdateHelper();
    obj = BillectaInvoiceUpdateHelper.getLastUpdated(testInv.Id);

    Test.stopTest();

    System.assertEquals('warning', obj.icon);
  }
}