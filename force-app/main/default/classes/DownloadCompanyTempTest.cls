/**
 * @description       :
 * @author            : Malin Nilsson (Stretch Customer AB)
 * @group             :
 * @last modified on  : 2024-09-06
 * @last modified by  : Malin Nilsson (Stretch Customer AB)
 **/
@isTest
private class DownloadCompanyTempTest {
  @TestSetup
  private static void setupTestData() {
    TestDataFactorySetupParams params = new TestDataFactorySetupParams();
    params.numberOfEmployerAccounts = 50;
    params.numberOfWorkplaceAccounts = 20;

    TestDataFactory.setupBasicTestData();
    TestDataFactory.setupTestData(params);
  }

  @isTest
  static void testCompanyTemp() {
    Id recordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName()
      .get('Employer')
      .getRecordTypeId();

    List<Account> employers = [
      SELECT ID, BasunID__c
      FROM Account
      WHERE recordTypeId = :recordTypeId
    ];

    for (Account a : employers) {
      a.BasunLastModified__c = null;
    }
    update employers;

    Test.setMock(
      HttpCalloutMock.class,
      new MockHttpResponseGenerator('getCompanyInfo')
    );
    Test.startTest();
    DownloadCompanyTemp c = new DownloadCompanyTemp();
    Database.executeBatch(c);
    Test.stopTest();
  }

  @isTest
  static void testWorksiteTemp() {
    Test.setMock(
      HttpCalloutMock.class,
      new MockHttpResponseGenerator('getCompanyInfo')
    );

    Id recordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName()
      .get('Employer')
      .getRecordTypeId();

    List<Account> employers = [
      SELECT ID, BasunID__c
      FROM Account
      WHERE recordTypeId = :recordTypeId
    ];
    Account a = employers[0];
    a.BasunID__c = '987654321';
    update a;

    Test.setMock(
      HttpCalloutMock.class,
      new MockHttpResponseGenerator('getWorksiteInfo')
    );
    Test.startTest();
    DownloadWorksiteTemp c = new DownloadWorksiteTemp();
    Database.executeBatch(c);
    Test.stopTest();
  }
}