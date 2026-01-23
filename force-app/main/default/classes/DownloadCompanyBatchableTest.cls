/**
 * @description       :
 * @author            : Malin Nilsson (Stretch Customer AB)
 * @group             :
 * @last modified on  : 2024-09-06
 * @last modified by  : Malin Nilsson (Stretch Customer AB)
 **/
@isTest
private class DownloadCompanyBatchableTest {
  @TestSetup
  static void makeData() {
    TestDataFactorySetupParams params = new TestDataFactorySetupParams();
    params.numberOfEmployerAccounts = 50;
    TestDataFactory.setupBasicTestData();
    TestDataFactory.setupTestData(params);
  }

  @isTest
  static void testDownloadCompanyBatchable() {
    Test.setMock(
      HttpCalloutMock.class,
      new MockHttpResponseGenerator('getCompanyInfo')
    );

    Set<String> companyIds = new Set<String>();
    for (Account acct : [SELECT id FROM Account]) {
      companyIds.add(acct.Id);
    }

    Test.setMock(
      HttpCalloutMock.class,
      new MockHttpResponseGenerator('getCompanyInfo')
    );
    Test.startTest();
    DownloadCompanyBatchable c = new DownloadCompanyBatchable(companyIds);
    Database.executeBatch(c);
    SchedulableDailyWorkplace.scheduleIt();
    Test.stopTest();
  }
}