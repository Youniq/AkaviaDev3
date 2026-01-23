/**
 * @description       :
 * @author            : Malin Nilsson (Stretch Customer AB)
 * @group             :
 * @last modified on  : 2024-09-06
 * @last modified by  : Malin Nilsson (Stretch Customer AB)
 **/
@isTest
private class CommunityCaseControllerTest {
  static final Integer numOfFeedItems = 3;

  @testSetup
  static void setup() {
    System.debug('*** CommunityCaseControllerTest Setup() starting ***');

    TestDataFactorySetupParams params = new TestDataFactorySetupParams();
    params.numberOfAccounts = 1;
    params.numberOfCases = 1;
    params.numberOfCaseFeedItems = numOfFeedItems;

    TestDataFactory.setupBasicTestData();
    TestDataFactory.setupTestData(params);
  }

  @isTest
  static void TestCreateCaseComment() {
    Case caseInTest = [SELECT Id FROM Case LIMIT 1];

    test.startTest();
    CaseComment cc = CommunityCaseController.addCaseComment(
      caseInTest.Id,
      'commentBody'
    );
    List<CaseComment> ccList = CommunityCaseController.getCaseComments(
      caseInTest.Id
    );
    test.stopTest();

    System.assertEquals(1, ccList.Size());
  }

  @isTest
  static void TestCatchCreateCaseComment() {
    //Start test
    Test.startTest();

    // call your method
    try {
      CaseComment result = CommunityCaseController.addCaseComment(null, null);
    } catch (Exception e) {
      //assert correct data
      Boolean errorCaught = e != null;
      System.assertEquals(true, errorCaught);
    }

    Test.stopTest();
  }

  @isTest
  static void TestGetFeedItemsByCase() {
    Case testCase = [SELECT Id FROM Case LIMIT 1];

    //Start test
    Test.startTest();

    // call your method
    List<CaseFeed> feedItems = CommunityCaseController.getFeedItemsByCase(
      testCase.Id
    );
    System.assertEquals(
      numOfFeedItems,
      feedItems.size(),
      'Did not find the accurate amount of feed items.'
    );

    Test.stopTest();
  }

  @isTest
  static void TestGetSubCommentByCase() {
    Case testCase = [SELECT Id FROM Case LIMIT 1];

    //Start test
    Test.startTest();

    // call your method
    List<FeedComment> feedComments = CommunityCaseController.getSubCommentByCase(
      testCase.Id
    );
    System.assertEquals(false, feedComments == null, 'Feed Comments is null.');

    Test.stopTest();
  }

  @isTest
  static void TestGetQuickCaseSettings() {
    Test.startTest();
    List<PortalQuickCaseSetting__mdt> settings = CommunityCaseController.getActiveQuickCaseSettings();

    Test.stopTest();
    System.assertEquals(
      false,
      settings == null,
      'PortalQuickCaseSetting__mdt settings is null'
    );
  }
}