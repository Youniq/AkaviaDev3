/**
 * @description       :
 * @author            : Malin Nilsson (Stretch Customer AB)
 * @group             :
 * @last modified on  : 2024-04-02
 * @last modified by  : Malin Nilsson (Stretch Customer AB)
 **/
@isTest
private class DownloadPersonPendingBatchableTest {
  @TestSetup
  static void makeData() {
    TestDataFactorySetupParams params = new TestDataFactorySetupParams();
    params.numberOfAccounts = 1;
    params.addMembershipsToMembers = true;

    TestDataFactory.setupBasicTestData();
    TestDataFactory.setupTestData(params);

    Account aa = [
      SELECT id, membershipStatus__c, LatestMembership__c
      FROM account
    ];
    Membership__c mm = [SELECT Id FROM Membership__c WHERE Person__c = :aa.Id];
    aa.LatestMembership__c = mm.Id;
    update aa;
  }

  @isTest
  static void testDownloadPerson() {
    Test.setMock(
      HttpCalloutMock.class,
      new MockHttpResponseGenerator('getRecordFromPortfolio')

      // getDownloadPersonInfo
    );
    Test.startTest();
    DownloadPersonPendingBatchable c = new DownloadPersonPendingBatchable();
    Database.executeBatch(c);
    Test.stopTest();
  }

  @isTest
  static void testDownloadPersonFail() {
    Test.setMock(
      HttpCalloutMock.class,
      new MockHttpResponseGenerator('responseCode500')
    );
    Test.startTest();
    DownloadPersonPendingBatchable c = new DownloadPersonPendingBatchable();
    Database.executeBatch(c);
    Test.stopTest();
  }

  @isTest
  static void testRemoveBCI() {
    // Makes Account.MembershipStatus__c = 'Avslutad'
    Membership__c mem = [SELECT Id, EndDate__c FROM Membership__c LIMIT 1];
    mem.EndDate__c = System.today().addDays(-1);
    update mem;

    // Make sure that account has BCI ID, otherwise it will not be found by the query in RemovePersonFromBCIBatchable.
    Account acc = [
      SELECT Id, BCIID__c
      FROM Account
      WHERE LatestMembership__c = :mem.Id
    ];
    acc.BCIID__c = 'akjhdh';
    update acc;

    Test.setMock(
      HttpCalloutMock.class,
      new MockHttpResponseGenerator('getDownloadPersonInfo')
    );
    Test.startTest();
    RemovePersonFromBCIBatchable c = new RemovePersonFromBCIBatchable();
    Database.executeBatch(c);
    Test.stopTest();
  }

  @isTest
  static void testRemoveBCIFail() {
    // Makes Account.MembershipStatus__c = 'Avslutad'
    Membership__c mem = [SELECT Id, EndDate__c FROM Membership__c LIMIT 1];
    mem.EndDate__c = System.today().addDays(-1);
    update mem;

    // Make sure that account has BCI ID, otherwise it will not be found by the query in RemovePersonFromBCIBatchable.
    Account acc = [
      SELECT Id, BCIID__c
      FROM Account
      WHERE LatestMembership__c = :mem.Id
    ];
    acc.BCIID__c = 'akjhdh';
    update acc;

    Test.setMock(
      HttpCalloutMock.class,
      new MockHttpResponseGenerator('responseCode500')
    );
    Test.startTest();
    RemovePersonFromBCIBatchable c = new RemovePersonFromBCIBatchable();
    Database.executeBatch(c);
    Test.stopTest();
  }
}