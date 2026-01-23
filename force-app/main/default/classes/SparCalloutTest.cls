/**
 * @description       :
 * @author            : Malin Nilsson (Stretch Customer AB)
 * @group             :
 * @last modified on  : 2025-02-28
 * @last modified by  : Malin Nilsson (Stretch Customer AB)
 **/
@isTest
private class SparCalloutTest {
  @TestSetup
  static void makeData() {
    TestDataFactorySetupParams params = new TestDataFactorySetupParams();
    params.numberOfAccounts = 1;
    TestDataFactory.setupBasicTestData();
    TestDataFactory.setupTestData(params);

    Account a = [
      SELECT Id, SocialSecurityNumber__c, MemberNumber__c
      FROM Account
      LIMIT 1
    ];
    a.SocialSecurityNumber__c = '198101145211';
    a.BCIID__c = '12340';
    a.BasunLastModified__c = system.now();
    update a;
  }

//  @isTest
  // static void testGetAccessToken() {
  //   Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator('token'));
  //   Test.startTest();
  //   String res = SparCallout.getAccessToken();
  //   Test.stopTest();

  //   System.assertEquals('8UT28QKGTiAhjNk5yJj', res);
  // }

  @isTest
  static void testDownloadPersonInfo() {
    Test.setMock(
      HttpCalloutMock.class,
      new MockHttpResponseGenerator('getDownloadPersonInfo')
    );

    Test.startTest();
    SparCallout.ResponseWrapper res = SparCallout.downloadPersonInfo(
      '123',
      null,
      null
    );
    Test.stopTest();
  }

  @isTest
  static void testGetChangesPersonInfo() {
    Test.setMock(
      HttpCalloutMock.class,
      new MockHttpResponseGenerator('getDownloadPersonInfo')
    );
    List<Callout__c> calloutLogs = new List<Callout__c>();

    Test.startTest();
    SparCallout.ResponseWrapper res = SparCallout.getChangesPersonInfo(
      '123',
      'null',
      calloutLogs
    );
    Test.stopTest();
  }

  @isTest
  static void testUpdateList() {
    Test.setMock(
      HttpCalloutMock.class,
      new MockHttpResponseGenerator('getDownloadPersonInfo')
    );
    Test.startTest();
    Boolean res = SparCallout.updateList('123', '4321', 'ADD', null, null);
    Test.stopTest();
  }

  @isTest
  static void testMapPersonAccount() {
    Test.setMock(
      HttpCalloutMock.class,
      new MockHttpResponseGenerator('getDownloadPersonInfo')
    );

    Account a = [
      SELECT Id, SocialSecurityNumber__c, Membernumber__c
      FROM Account
      LIMIT 1
    ];

    Test.startTest();

    SparCallout.MapPersonAccount(
      a,
      PersonData.parse(MockHttpResponseGenerator.personDataString())
    );

    Test.stopTest();
  }

  @isTest
  static void testAddRecordToPortfolio() {
    Test.setMock(
      HttpCalloutMock.class,
      new MockHttpResponseGenerator('getDownloadPersonInfo')
    );

    Account a = [
      SELECT Id, SocialSecurityNumber__c, Membernumber__c
      FROM Account
      LIMIT 1
    ];
    Test.startTest();
    SparCallout.addRecordToPortfolio(Json.serialize(a), 'Defualt');
    Test.stopTest();
  }

  @isTest
  static void testDeletePersonFromProtfolio() {
    Test.setMock(
      HttpCalloutMock.class,
      new MockHttpResponseGenerator('getDownloadPersonInfo')
    );

    Account a = [
      SELECT Id, SocialSecurityNumber__c, Membernumber__c
      FROM Account
      LIMIT 1
    ];

    Test.startTest();
    SparCallout.deletePersonFromProtfolio(Json.serialize(a), 'Defualt');
    Test.stopTest();
  }

  @isTest
  static void testGetRecordFromPortfolio() {
    Test.setMock(
      HttpCalloutMock.class,
      new MockHttpResponseGenerator('getRecordFromPortfolio')
    );

    Account a = [
      SELECT Id, SocialSecurityNumber__c, MemberNumber__c
      FROM Account
      LIMIT 1
    ];

    Test.startTest();
    SparCallout.getRecordFromPortfolio(a, 'Defualt', null);
    Test.stopTest();
  }
}