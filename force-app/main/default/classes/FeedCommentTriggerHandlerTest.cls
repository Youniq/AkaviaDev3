/**
 * @description       :
 * @author            : Malin Nilsson (Stretch Customer AB)
 * @group             :
 * @last modified on  : 2024-02-12
 * @last modified by  : Malin Nilsson (Stretch Customer AB)
 **/
@isTest
public with sharing class FeedCommentTriggerHandlerTest {
  @TestSetup
  // Method to create a test case with associated feed item and feed comments
  private static void makeData() {
    TestDataFactorySetupParams params = new TestDataFactorySetupParams();
    params.numberOfCases = 1;

    TestDataFactory.setupTestData(params);
    Case testCase = [SELECT Id FROM Case LIMIT 1];

    FeedItem item = new FeedItem(
      ParentId = testCase.Id,
      Body = 'Test Feed Item Body',
      Visibility = 'AllUsers'
    );

    insert item;
  }

  @isTest
  private static void testFeedCommentTriggerHandler() {
    FeedItem testFeedItem = [SELECT Id FROM FeedItem LIMIT 1];

    // Create feed comments related to the feed item
    List<FeedComment> feedComments = new List<FeedComment>();

    for (Integer i = 0; i < 2; i++) {
      FeedComment comment = new FeedComment(
        FeedItemId = testFeedItem.Id,
        CommentBody = 'Test Feed Comment ' + String.valueOf(i)
      );
      feedComments.add(comment);
    }

    Test.startTest();
    insert feedComments;
    Test.stopTest();
  }
}