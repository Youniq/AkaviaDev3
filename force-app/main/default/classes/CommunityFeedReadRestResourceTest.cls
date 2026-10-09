@IsTest
private class CommunityFeedReadRestResourceTest {
  @TestSetup
  static void setup() {
    TestDataFactory.setupBasicTestData();
    TestDataFactorySetupParams params = new TestDataFactorySetupParams();
    params.numberOfAccounts = 1;
    params.numberOfCases = 1;
    params.numberOfCaseFeedItems = 1;
    TestDataFactory.setupTestData(params);
  }

  @IsTest
  static void getFeeds_requiresParams() {
    RestRequest req = new RestRequest();
    RestResponse res = new RestResponse();
    req.requestUri = '/services/apexrest/mina-sidor/v1/feeds';
    req.httpMethod = 'GET';
    RestContext.request = req;
    RestContext.response = res;

    Test.startTest();
    CommunityFeedReadRestResource.getFeeds();
    Test.stopTest();

    System.assertEquals(400, res.statusCode);
  }

  @IsTest
  static void getFeeds_returnsIsRead() {
    Case testCase = [SELECT Id FROM Case LIMIT 1];
    Account person = [
      SELECT Id
      FROM Account
      WHERE IsPersonAccount = TRUE
      LIMIT 1
    ];

    RestRequest req = new RestRequest();
    RestResponse res = new RestResponse();
    req.requestUri = '/services/apexrest/mina-sidor/v1/feeds';
    req.httpMethod = 'GET';
    req.params.put('caseId', testCase.Id);
    req.params.put('accountId', person.Id);
    RestContext.request = req;
    RestContext.response = res;

    Test.startTest();
    CommunityFeedReadRestResource.getFeeds();
    Test.stopTest();

    System.assertEquals(200, res.statusCode);
    List<Object> body = (List<Object>) JSON.deserializeUntyped(
      res.responseBody.toString()
    );
    System.assertEquals(1, body.size());
    Map<String, Object> item = (Map<String, Object>) body[0];
    System.assertEquals(true, item.get('isRead'));
  }

  @IsTest
  static void getFeeds_byAccountId_returnsItems() {
    Account person = [
      SELECT Id
      FROM Account
      WHERE IsPersonAccount = TRUE
      LIMIT 1
    ];

    RestRequest req = new RestRequest();
    RestResponse res = new RestResponse();
    req.requestUri = '/services/apexrest/mina-sidor/v1/feeds';
    req.httpMethod = 'GET';
    req.params.put('accountId', person.Id);
    RestContext.request = req;
    RestContext.response = res;

    Test.startTest();
    CommunityFeedReadRestResource.getFeeds();
    Test.stopTest();

    System.assertEquals(200, res.statusCode);
    List<Object> body = (List<Object>) JSON.deserializeUntyped(
      res.responseBody.toString()
    );
    System.assertEquals(1, body.size());
  }

  @IsTest
  static void patchReadStatus_setsBoolean() {
    Account person = [
      SELECT Id
      FROM Account
      WHERE IsPersonAccount = TRUE
      LIMIT 1
    ];
    FeedItem feed = [SELECT Id FROM FeedItem LIMIT 1];

    RestRequest req = new RestRequest();
    RestResponse res = new RestResponse();
    req.requestUri = '/services/apexrest/mina-sidor/v1/feeds';
    req.httpMethod = 'PATCH';
    req.requestBody = Blob.valueOf(
      JSON.serialize(
        new Map<String, Object>{
          'accountId' => person.Id,
          'feedItemIds' => new List<String>{ feed.Id },
          'isRead' => false
        }
      )
    );
    RestContext.request = req;
    RestContext.response = res;

    Test.startTest();
    CommunityFeedReadRestResource.patchReadStatus();
    Test.stopTest();

    System.assertEquals(200, res.statusCode);
    FeedRead__c stored = [
      SELECT IsRead__c
      FROM FeedRead__c
      WHERE Person__c = :person.Id AND FeedItemId__c = :feed.Id
    ];
    System.assertEquals(false, stored.IsRead__c);
  }
}