/**
 * @description       :
 * @author            : Malin Nilsson (Stretch Customer AB)
 * @group             :
 * @last modified on  : 2024-10-25
 * @last modified by  : Malin Nilsson (Stretch Customer AB)
 **/
@isTest
public class CommunityCaseControllerWSharingTest {
  @testSetup
  static void setup() {
    System.debug(
      '*** CommunityCaseControllerWSharingTest Setup() starting ***'
    );

    TestDataFactorySetupParams params = new TestDataFactorySetupParams();
    params.numberOfAccounts = 1;
    params.numberOfCases = 1;
    params.numberOfCaseFiles = 1;

    TestDataFactory.setupBasicTestData();
    TestDataFactory.setupTestData(params);
  }

  @isTest
  static void TestGetCaseWithOwnerOOO() {
    // Set OOO values on running user, aka case owner
    ID uId = UserInfo.getUserId();
    User u = new User();
    u.Id = uId;
    u.OutOfOfficeFrom__c = Date.today().addDays(-1); // Makes IsOutOfOffice__c = true
    u.OutOfOfficeTo__c = Date.today().addDays(10);
    u.OutOfOfficeAutoResponderText__c = 'Owners OOO Message.';

    update u;

    // Add ownerUser as caseOwner
    Case caseInTest = [SELECT Id, OwnerId FROM Case LIMIT 1];
    caseInTest.OwnerId = uId; // Set case owner to current user as the default case owner can be something else.
    update caseInTest;

    test.startTest();
    CommunityCaseModel caseFromMethod = CommunityCaseControllerWSharing.getCase(
      caseInTest.Id
    );
    test.stopTest();

    Assert.areNotEqual(null, caseFromMethod.CaseRecord.CaseNumber);
    Assert.areEqual(true, caseFromMethod.ownerIsOutOfOffice);
  }

  @isTest
  static void TestGetCaseWithoutOwnerOOO() {
    Case caseInTest = [SELECT Id FROM Case LIMIT 1];
    test.startTest();
    CommunityCaseModel caseFromMethod = CommunityCaseControllerWSharing.getCase(
      caseInTest.Id
    );
    test.stopTest();

    System.assertNotEquals(null, caseFromMethod.CaseRecord.CaseNumber);
  }

  @isTest
  static void TestFailGetCase() {
    test.startTest();
    CommunityCaseModel caseFromMethod = CommunityCaseControllerWSharing.getCase(
      null
    );
    test.stopTest();

    System.assertEquals(null, caseFromMethod);
  }

  @isTest
  static void TestGetAccountCases() {
    Account accountInTest = [SELECT Id FROM Account LIMIT 1];

    test.startTest();
    List<Case> casesFromMethod = CommunityCaseControllerWSharing.getAccountCases(
      accountInTest.Id
    );
    test.stopTest();

    System.assertEquals(1, casesFromMethod.size());
  }

  @isTest
  static void TestGetAccountNewestCase() {
    Account accountInTest = [SELECT Id FROM Account LIMIT 1];

    test.startTest();
    Case caseFromMethod = CommunityCaseControllerWSharing.getAccountNewestCase(
      accountInTest.Id
    );
    test.stopTest();

    System.assertNotEquals(null, caseFromMethod.CaseNumber);
  }

  @isTest
  static void TestFailGetAccountNewestCase() {
    test.startTest();
    Case caseFromMethod = CommunityCaseControllerWSharing.getAccountNewestCase(
      null
    );
    test.stopTest();

    System.assertEquals(null, caseFromMethod);
  }

  @isTest
  static void TestCreateNewCase() {
    //Start test
    Test.startTest();

    // call your method
    Contact con = [SELECT Id FROM Contact LIMIT 1];
    Case newCase = new Case();
    newCase.ContactId = con.Id;
    newCase.Subject = 'Hej';

    Boolean result = CommunityCaseControllerWSharing.createNewCase(newCase);

    Test.stopTest();

    //assert correct data
    System.assertEquals(true, result);
  }

  @isTest
  static void TestCatchCreateNewCase() {
    //Start test
    Test.startTest();

    // call your method
    try {
      Boolean result = CommunityCaseControllerWSharing.createNewCase(null);
    } catch (Exception e) {
      //assert correct data
      Boolean errorCaught = e != null;
      System.assertEquals(true, errorCaught);
    }

    Test.stopTest();
  }

  @isTest
  static void TestGetCaseRTByDeveloperName() {
    //Start test
    Test.startTest();
    // call your method
    String rtId = CommunityCaseControllerWSharing.getCaseRecordTypeIdByDeveloperName(
      'ServiceCase'
    );
    Test.stopTest();
    //assert correct data
    System.assertEquals(true, rtId != null);
  }

  @isTest
  static void TestGetCaseRTNameById() {
    //Start test
    Test.startTest();
    // call your method
    Case testCase = [SELECT Id, RecordTypeId FROM Case LIMIT 1];
    List<RecordType> result = CommunityCaseControllerWSharing.getCaseRecordTypeNameById(
      testCase.RecordTypeId
    );
    Test.stopTest();
    //assert correct data
    System.assertEquals(1, result.size());
  }

  @isTest
  static void TestGetFilesContentVersion() {
    ContentVersion contentDoc = [
      SELECT Id, ContentDocumentId
      FROM ContentVersion
      LIMIT 1
    ];
    List<String> contentDocIds = new List<String>{
      contentDoc.ContentDocumentId
    };

    Test.startTest();
    List<ContentVersion> docs = CommunityCaseControllerWSharing.getFilesContentVersion(
      contentDocIds
    );
    Test.stopTest();

    System.assertEquals(1, docs.size());
  }

  @isTest
  static void TestaddFeedItemToCase() {
    //Start test
    Test.startTest();
    // call your method
    Case testCase = [SELECT Id FROM Case LIMIT 1];
    FeedItem result = CommunityCaseControllerWSharing.addFeedItemToCase(
      testCase.Id,
      'A new post message to case. Testclass.'
    );
    Test.stopTest();
    //assert correct data
    System.assertNotEquals(
      null,
      result,
      'Could not add feed item to case during test'
    );
  }
}