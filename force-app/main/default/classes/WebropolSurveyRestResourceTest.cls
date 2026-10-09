@IsTest
private class WebropolSurveyRestResourceTest {
  @TestSetup
  static void setupData() {
    TestDataFactory.setupBasicTestData();
    TestDataFactorySetupParams params = new TestDataFactorySetupParams();
    params.numberOfAccounts = 1;
    TestDataFactory.setupTestData(params);
  }

  @IsTest
  static void postPersonalLink_byAccountId_returnsLink() {
    Account person = [
      SELECT Id, MemberNumber__c, PersonEmail
      FROM Account
      WHERE IsPersonAccount = TRUE
      LIMIT 1
    ];
    person.MemberNumber__c = '8462';
    person.PersonEmail = 'rest.test@example.com';
    update person;

    WebropolClient.clearTokenCacheForTest();
    Test.setMock(
      HttpCalloutMock.class,
      WebropolHttpCalloutMock.successDefaults()
    );

    RestRequest req = new RestRequest();
    RestResponse res = new RestResponse();
    req.requestUri = '/services/apexrest/webropol/v1/personal-link';
    req.httpMethod = 'POST';
    req.requestBody = Blob.valueOf(
      JSON.serialize(
        new Map<String, Object>{
          'accountId' => person.Id,
          'settingsDeveloperName' => 'Default',
          'createIfMissing' => true
        }
      )
    );
    RestContext.request = req;
    RestContext.response = res;

    Test.startTest();
    WebropolSurveyRestResource.postPersonalLink();
    Test.stopTest();

    System.assertEquals(200, res.statusCode);
    Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(
      res.responseBody.toString()
    );
    System.assertEquals(true, body.get('success'));
    System.assert(
      String.valueOf(body.get('personalLink')).contains('webropolsurveys.com')
    );
  }

  @IsTest
  static void postPersonalLink_byMemberId_returnsLink() {
    WebropolClient.clearTokenCacheForTest();
    Test.setMock(
      HttpCalloutMock.class,
      WebropolHttpCalloutMock.successDefaults()
    );

    RestRequest req = new RestRequest();
    RestResponse res = new RestResponse();
    req.httpMethod = 'POST';
    req.requestBody = Blob.valueOf(
      JSON.serialize(
        new Map<String, Object>{
          'memberId' => '8462',
          'email' => 'rest.test@example.com',
          'createIfMissing' => true
        }
      )
    );
    RestContext.request = req;
    RestContext.response = res;

    Test.startTest();
    WebropolSurveyRestResource.postPersonalLink();
    Test.stopTest();

    System.assertEquals(200, res.statusCode);
  }

  @IsTest
  static void postPersonalLink_newRecipient_returns202() {
    WebropolClient.clearTokenCacheForTest();
    Test.setMock(
      HttpCalloutMock.class,
      new WebropolEnsureLinkCalloutMock(
        '8462',
        'https://link.webropolsurveys.com/R/CREATED'
      )
    );

    RestRequest req = new RestRequest();
    RestResponse res = new RestResponse();
    req.httpMethod = 'POST';
    req.requestBody = Blob.valueOf(
      JSON.serialize(
        new Map<String, Object>{
          'memberId' => '8462',
          'email' => 'new.member@example.com',
          'createIfMissing' => true
        }
      )
    );
    RestContext.request = req;
    RestContext.response = res;

    Test.startTest();
    WebropolSurveyRestResource.postPersonalLink();
    Test.stopTest();

    System.assertEquals(202, res.statusCode);
    System.assertEquals(
      String.valueOf(WebropolSurveyRestResource.RETRY_AFTER_SECONDS),
      res.headers.get('Retry-After')
    );
    Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(
      res.responseBody.toString()
    );
    System.assertEquals(true, body.get('pending'));
    System.assertEquals(true, body.get('createdRecipient'));
    System.assertEquals(null, body.get('personalLink'));
  }

  @IsTest
  static void postPersonalLink_invalidJson_returns400() {
    RestRequest req = new RestRequest();
    RestResponse res = new RestResponse();
    req.httpMethod = 'POST';
    req.requestBody = Blob.valueOf('not-json');
    RestContext.request = req;
    RestContext.response = res;

    Test.startTest();
    WebropolSurveyRestResource.postPersonalLink();
    Test.stopTest();

    System.assertEquals(400, res.statusCode);
  }

  @IsTest
  static void postPersonalLink_missingIdentifiers_returns400() {
    RestRequest req = new RestRequest();
    RestResponse res = new RestResponse();
    req.httpMethod = 'POST';
    req.requestBody = Blob.valueOf('{}');
    RestContext.request = req;
    RestContext.response = res;

    Test.startTest();
    WebropolSurveyRestResource.postPersonalLink();
    Test.stopTest();

    System.assertEquals(400, res.statusCode);
  }

  @IsTest
  static void postPersonalLink_missingBody_returns400() {
    RestRequest req = new RestRequest();
    RestResponse res = new RestResponse();
    req.httpMethod = 'POST';
    RestContext.request = req;
    RestContext.response = res;

    Test.startTest();
    WebropolSurveyRestResource.postPersonalLink();
    Test.stopTest();

    System.assertEquals(400, res.statusCode);
  }

  @IsTest
  static void postPersonalLink_invalidAccountId_returns400() {
    RestRequest req = new RestRequest();
    RestResponse res = new RestResponse();
    req.httpMethod = 'POST';
    req.requestBody = Blob.valueOf(
      '{"accountId":"not-an-id","createIfMissing":false}'
    );
    RestContext.request = req;
    RestContext.response = res;

    Test.startTest();
    WebropolSurveyRestResource.postPersonalLink();
    Test.stopTest();

    System.assertEquals(400, res.statusCode);
    Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(
      res.responseBody.toString()
    );
    System.assertEquals(false, body.get('success'));
    System.assertEquals('Ogiltigt accountId', body.get('message'));
  }

  @IsTest
  static void postPersonalLink_missingEmail_returns400() {
    Account person = [
      SELECT Id
      FROM Account
      WHERE IsPersonAccount = TRUE
      LIMIT 1
    ];
    person.MemberNumber__c = '8462';
    person.PersonEmail = null;
    update person;

    RestRequest req = new RestRequest();
    RestResponse res = new RestResponse();
    req.httpMethod = 'POST';
    req.requestBody = Blob.valueOf(
      JSON.serialize(
        new Map<String, Object>{
          'accountId' => person.Id,
          'createIfMissing' => false
        }
      )
    );
    RestContext.request = req;
    RestContext.response = res;

    Test.startTest();
    WebropolSurveyRestResource.postPersonalLink();
    Test.stopTest();

    System.assertEquals(400, res.statusCode);
    Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(
      res.responseBody.toString()
    );
    System.assertEquals(false, body.get('success'));
    System.assert(
      String.valueOf(body.get('message')).contains('E-post'),
      String.valueOf(body.get('message'))
    );
  }

  @IsTest
  static void postPersonalLink_unknownAccount_returns404() {
    User anyUser = [SELECT Id FROM User LIMIT 1];
    RestRequest req = new RestRequest();
    RestResponse res = new RestResponse();
    req.httpMethod = 'POST';
    req.requestBody = Blob.valueOf(
      JSON.serialize(
        new Map<String, Object>{
          'accountId' => anyUser.Id,
          'createIfMissing' => false
        }
      )
    );
    RestContext.request = req;
    RestContext.response = res;

    Test.startTest();
    WebropolSurveyRestResource.postPersonalLink();
    Test.stopTest();

    System.assertEquals(404, res.statusCode);
    Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(
      res.responseBody.toString()
    );
    System.assertEquals(false, body.get('success'));
    System.assert(
      String.valueOf(body.get('message')).contains('hittades inte'),
      String.valueOf(body.get('message'))
    );
  }

  @IsTest
  static void postPersonalLink_missingRecipient_returns404() {
    WebropolClient.clearTokenCacheForTest();
    Test.setMock(
      HttpCalloutMock.class,
      WebropolHttpCalloutMock.emptyRecipients()
    );

    RestRequest req = new RestRequest();
    RestResponse res = new RestResponse();
    req.httpMethod = 'POST';
    req.requestBody = Blob.valueOf(
      JSON.serialize(
        new Map<String, Object>{
          'memberId' => '8462',
          'email' => 'missing.recipient@example.com',
          'createIfMissing' => false
        }
      )
    );
    RestContext.request = req;
    RestContext.response = res;

    Test.startTest();
    WebropolSurveyRestResource.postPersonalLink();
    Test.stopTest();

    System.assertEquals(404, res.statusCode);
    Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(
      res.responseBody.toString()
    );
    System.assertEquals(false, body.get('success'));
    System.assertEquals(false, body.get('createdRecipient'));
  }

  @IsTest
  static void postPersonalLink_webropolDown_returns502() {
    WebropolClient.clearTokenCacheForTest();
    Test.setMock(
      HttpCalloutMock.class,
      WebropolHttpCalloutMock.tokenFailure()
    );

    RestRequest req = new RestRequest();
    RestResponse res = new RestResponse();
    req.httpMethod = 'POST';
    req.requestBody = Blob.valueOf(
      JSON.serialize(
        new Map<String, Object>{
          'memberId' => '8462',
          'email' => 'rest.test@example.com',
          'createIfMissing' => false
        }
      )
    );
    RestContext.request = req;
    RestContext.response = res;

    Test.startTest();
    WebropolSurveyRestResource.postPersonalLink();
    Test.stopTest();

    System.assertEquals(502, res.statusCode);
    Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(
      res.responseBody.toString()
    );
    System.assertEquals(false, body.get('success'));
    System.assert(
      String.valueOf(body.get('message')).contains('Webropol'),
      String.valueOf(body.get('message'))
    );
  }
}