@IsTest
private class CommunityFeedReadServiceTest {
  @TestSetup
  static void setup() {
    TestDataFactory.setupBasicTestData();
    TestDataFactorySetupParams params = new TestDataFactorySetupParams();
    params.numberOfAccounts = 1;
    params.numberOfCases = 1;
    params.numberOfCaseFeedItems = 2;
    TestDataFactory.setupTestData(params);
  }

  @IsTest
  static void getFeedItemsByCase_marksOwnPostsAsRead() {
    Case testCase = [SELECT Id FROM Case LIMIT 1];
    Account person = [
      SELECT Id
      FROM Account
      WHERE IsPersonAccount = TRUE
      LIMIT 1
    ];

    Test.startTest();
    List<CommunityFeedItem> items = CommunityFeedReadService.getFeedItemsByCase(
      testCase.Id,
      person.Id
    );
    Test.stopTest();

    System.assertEquals(2, items.size());
    for (CommunityFeedItem item : items) {
      System.assertEquals(
        true,
        item.isRead,
        'Posts created by the running user default to read.'
      );
    }
  }

  @IsTest
  static void setReadStatus_persistsBooleanPerMember() {
    Case testCase = [SELECT Id FROM Case LIMIT 1];
    Account person = [
      SELECT Id
      FROM Account
      WHERE IsPersonAccount = TRUE
      LIMIT 1
    ];
    FeedItem feed = [SELECT Id FROM FeedItem WHERE ParentId = :testCase.Id LIMIT 1];

    Test.startTest();
    CommunityFeedReadService.setReadStatus(
      new List<String>{ feed.Id },
      person.Id,
      false
    );
    List<CommunityFeedItem> unread = CommunityFeedReadService.getFeedItemsByCase(
      testCase.Id,
      person.Id
    );
    CommunityFeedReadService.setReadStatus(
      new List<String>{ feed.Id },
      person.Id,
      true
    );
    List<CommunityFeedItem> read = CommunityFeedReadService.getFeedItemsByCase(
      testCase.Id,
      person.Id
    );
    Test.stopTest();

    CommunityFeedItem unreadMatch;
    CommunityFeedItem readMatch;
    for (CommunityFeedItem item : unread) {
      if (item.Id == feed.Id) {
        unreadMatch = item;
      }
    }
    for (CommunityFeedItem item : read) {
      if (item.Id == feed.Id) {
        readMatch = item;
      }
    }

    System.assertEquals(false, unreadMatch.isRead);
    System.assertEquals(true, readMatch.isRead);

    FeedRead__c stored = [
      SELECT IsRead__c
      FROM FeedRead__c
      WHERE Person__c = :person.Id AND FeedItemId__c = :feed.Id
      LIMIT 1
    ];
    System.assertEquals(true, stored.IsRead__c);
  }

  @IsTest
  static void getFeedItemsByCase_hidesCaseWhenHideForMember() {
    Case testCase = [SELECT Id FROM Case LIMIT 1];
    testCase.HideForMember__c = true;
    update testCase;

    Account person = [
      SELECT Id
      FROM Account
      WHERE IsPersonAccount = TRUE
      LIMIT 1
    ];

    Test.startTest();
    List<CommunityFeedItem> items = CommunityFeedReadService.getFeedItemsByCase(
      testCase.Id,
      person.Id
    );
    Test.stopTest();

    System.assertEquals(
      0,
      items.size(),
      'Feed items on cases hidden from members must not be returned.'
    );
  }

  @IsTest
  static void getFeedItemsForMember_returnsVisibleCasePosts() {
    Account person = [
      SELECT Id
      FROM Account
      WHERE IsPersonAccount = TRUE
      LIMIT 1
    ];

    Test.startTest();
    List<CommunityFeedItem> items = CommunityFeedReadService.getFeedItemsForMember(
      person.Id
    );
    Test.stopTest();

    System.assertEquals(2, items.size());
    System.assertEquals(false, String.isBlank(items[0].caseSubject));
  }

  @IsTest
  static void setReadStatus_ignoresBlankAccount() {
    FeedItem feed = [SELECT Id FROM FeedItem LIMIT 1];

    Test.startTest();
    CommunityFeedReadService.setReadStatus(
      new List<String>{ feed.Id },
      null,
      true
    );
    Test.stopTest();

    System.assertEquals(0, [SELECT COUNT() FROM FeedRead__c]);
  }
}