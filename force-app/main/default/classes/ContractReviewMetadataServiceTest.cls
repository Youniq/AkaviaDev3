@IsTest
private class ContractReviewMetadataServiceTest {
  // ─── Mock ───────────────────────────────────────────────────────

  private static final String FAKE_JOB_ID = '0Af000000000001AAA';

  private class MockDeploymentHandler extends ContractReviewMetadataService.DeploymentHandler {
    public Metadata.DeployContainer capturedContainer;

    public override String enqueue(Metadata.DeployContainer container) {
      this.capturedContainer = container;
      return FAKE_JOB_ID;
    }
  }

  private static MockDeploymentHandler installMock() {
    MockDeploymentHandler mock = new MockDeploymentHandler();
    ContractReviewMetadataService.handler = mock;
    return mock;
  }

  // ─── deployBundledRecords ───────────────────────────────────────

  @IsTest
  static void deployBundledRecords_singleRecord_returnsJobId() {
    MockDeploymentHandler mock = installMock();

    List<Map<String, Object>> records = new List<Map<String, Object>>{
      new Map<String, Object>{
        'sObjectName' => 'ContractReviewTemplate__mdt',
        'developerName' => 'Bundled_01',
        'label' => 'Bundled 01',
        'fields' => new Map<String, Object>{
          'Description__c' => 'Bundled description'
        }
      }
    };

    String result = ContractReviewMetadataService.deployBundledRecords(records);

    System.assertEquals(FAKE_JOB_ID, result);
    System.assertNotEquals(null, mock.capturedContainer);
  }

  @IsTest
  static void deployBundledRecords_multipleRecords_returnsJobId() {
    installMock();

    List<Map<String, Object>> records = new List<Map<String, Object>>{
      new Map<String, Object>{
        'sObjectName' => 'ContractReviewTemplate__mdt',
        'developerName' => 'Bundled_01',
        'label' => 'Bundled 01',
        'fields' => null
      },
      new Map<String, Object>{
        'sObjectName' => 'ContractReviewCriterion__mdt',
        'developerName' => 'Bundled_02',
        'label' => 'Bundled 02',
        'fields' => new Map<String, Object>{ 'Sequence__c' => 1 }
      }
    };

    String result = ContractReviewMetadataService.deployBundledRecords(records);

    System.assertEquals(FAKE_JOB_ID, result);
  }

  @IsTest
  static void deployBundledRecords_nullList_throws() {
    installMock();
    try {
      ContractReviewMetadataService.deployBundledRecords(null);
      System.assert(false, 'Expected AuraHandledException');
    } catch (AuraHandledException e) {
      System.assertNotEquals(null, e);
    }
  }

  @IsTest
  static void deployBundledRecords_emptyList_throws() {
    installMock();
    try {
      ContractReviewMetadataService.deployBundledRecords(
        new List<Map<String, Object>>()
      );
      System.assert(false, 'Expected AuraHandledException');
    } catch (AuraHandledException e) {
      System.assertNotEquals(null, e);
    }
  }

  @IsTest
  static void deployBundledRecords_blankDevName_throws() {
    installMock();
    try {
      List<Map<String, Object>> records = new List<Map<String, Object>>{
        new Map<String, Object>{
          'sObjectName' => 'ContractReviewTemplate__mdt',
          'developerName' => '',
          'label' => 'Some Label',
          'fields' => null
        }
      };
      ContractReviewMetadataService.deployBundledRecords(records);
      System.assert(false, 'Expected AuraHandledException');
    } catch (AuraHandledException e) {
      System.assertNotEquals(null, e);
    }
  }

  // ─── sObjectName whitelist ────────────────────────────────────

  @IsTest
  static void deployBundledRecords_disallowedSObjectName_throws() {
    installMock();
    try {
      List<Map<String, Object>> records = new List<Map<String, Object>>{
        new Map<String, Object>{
          'sObjectName' => 'Account',
          'developerName' => 'Hacked_01',
          'label' => 'Hacked 01',
          'fields' => null
        }
      };
      ContractReviewMetadataService.deployBundledRecords(records);
      System.assert(false, 'Expected AuraHandledException');
    } catch (AuraHandledException e) {
      System.assertNotEquals(null, e);
    }
  }

  @IsTest
  static void deployBundledRecords_blankSObjectName_throws() {
    installMock();
    try {
      List<Map<String, Object>> records = new List<Map<String, Object>>{
        new Map<String, Object>{
          'sObjectName' => '',
          'developerName' => 'Blank_01',
          'label' => 'Blank 01',
          'fields' => null
        }
      };
      ContractReviewMetadataService.deployBundledRecords(records);
      System.assert(false, 'Expected AuraHandledException');
    } catch (AuraHandledException e) {
      System.assertNotEquals(null, e);
    }
  }

  // ─── System.runAs coverage ──────────────────────────────────────

  @IsTest
  static void deployBundledRecords_runAsStandardUser() {
    Profile stdProfile = [
      SELECT Id
      FROM Profile
      WHERE Name = 'Standard User'
      LIMIT 1
    ];
    User testUser = new User(
      Alias = 'crsvc',
      Email = 'crsvc@example.com',
      EmailEncodingKey = 'UTF-8',
      LastName = 'CRService',
      LanguageLocaleKey = 'en_US',
      LocaleSidKey = 'en_US',
      ProfileId = stdProfile.Id,
      TimeZoneSidKey = 'America/New_York',
      UserName = 'crsvc.' + System.currentTimeMillis() + '@example.com'
    );
    insert testUser;

    installMock();

    System.runAs(testUser) {
      List<Map<String, Object>> records = new List<Map<String, Object>>{
        new Map<String, Object>{
          'sObjectName' => 'ContractReviewTemplate__mdt',
          'developerName' => 'RunAs_Template',
          'label' => 'RunAs Template',
          'fields' => new Map<String, Object>{ 'Description__c' => 'Desc' }
        }
      };
      String result = ContractReviewMetadataService.deployBundledRecords(
        records
      );
      System.assertEquals(FAKE_JOB_ID, result);
    }
  }

  // ─── checkDeployStatus ──────────────────────────────────────────

  private class DeployStatusMock implements HttpCalloutMock {
    private final Integer statusCode;
    private final String body;

    DeployStatusMock(Integer statusCode, String body) {
      this.statusCode = statusCode;
      this.body = body;
    }

    public HttpResponse respond(HttpRequest req) {
      HttpResponse res = new HttpResponse();
      res.setStatusCode(this.statusCode);
      res.setBody(this.body);
      return res;
    }
  }

  @IsTest
  static void checkDeployStatus_blankJobId_throws() {
    try {
      ContractReviewMetadataService.checkDeployStatus('');
      System.assert(false, 'Expected AuraHandledException');
    } catch (AuraHandledException e) {
      System.assertNotEquals(null, e);
    }
  }

  @IsTest
  static void checkDeployStatus_nullJobId_throws() {
    try {
      ContractReviewMetadataService.checkDeployStatus(null);
      System.assert(false, 'Expected AuraHandledException');
    } catch (AuraHandledException e) {
      System.assertNotEquals(null, e);
    }
  }

  @IsTest
  static void checkDeployStatus_succeeded_returnsSucceeded() {
    String responseBody =
      '{"size":1,"totalSize":1,"done":true,"records":[' +
      '{"Id":"' +
      FAKE_JOB_ID +
      '","Status":"Succeeded","ErrorMessage":null}]}';
    Test.setMock(
      HttpCalloutMock.class,
      new DeployStatusMock(200, responseBody)
    );

    Test.startTest();
    Map<String, String> result = ContractReviewMetadataService.checkDeployStatus(
      FAKE_JOB_ID
    );
    Test.stopTest();

    System.assertEquals('Succeeded', result.get('status'));
    System.assertEquals('', result.get('errorMessage'));
  }

  @IsTest
  static void checkDeployStatus_failed_returnsFailedWithMessage() {
    String responseBody =
      '{"size":1,"totalSize":1,"done":true,"records":[' +
      '{"Id":"' +
      FAKE_JOB_ID +
      '","Status":"Failed","ErrorMessage":"Component failure"}]}';
    Test.setMock(
      HttpCalloutMock.class,
      new DeployStatusMock(200, responseBody)
    );

    Test.startTest();
    Map<String, String> result = ContractReviewMetadataService.checkDeployStatus(
      FAKE_JOB_ID
    );
    Test.stopTest();

    System.assertEquals('Failed', result.get('status'));
    System.assertEquals('Component failure', result.get('errorMessage'));
  }

  @IsTest
  static void checkDeployStatus_nonExistentJob_returnsNotFound() {
    String responseBody = '{"size":0,"totalSize":0,"done":true,"records":[]}';
    Test.setMock(
      HttpCalloutMock.class,
      new DeployStatusMock(200, responseBody)
    );

    Test.startTest();
    Map<String, String> result = ContractReviewMetadataService.checkDeployStatus(
      FAKE_JOB_ID
    );
    Test.stopTest();

    System.assertEquals('NotFound', result.get('status'));
    System.assertNotEquals(null, result.get('errorMessage'));
  }

  @IsTest
  static void checkDeployStatus_httpError_returnsNotFound() {
    Test.setMock(
      HttpCalloutMock.class,
      new DeployStatusMock(401, '{"error":"Unauthorized"}')
    );

    Test.startTest();
    Map<String, String> result = ContractReviewMetadataService.checkDeployStatus(
      FAKE_JOB_ID
    );
    Test.stopTest();

    System.assertEquals('NotFound', result.get('status'));
    System.assert(result.get('errorMessage').contains('HTTP 401'));
  }

  @IsTest
  static void checkDeployStatus_malformedId_throws() {
    try {
      ContractReviewMetadataService.checkDeployStatus('not-a-valid-id!');
      System.assert(false, 'Expected AuraHandledException');
    } catch (AuraHandledException e) {
      System.assertNotEquals(null, e);
    }
  }
}