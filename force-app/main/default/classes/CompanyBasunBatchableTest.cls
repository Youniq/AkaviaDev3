@isTest
private class CompanyBasunBatchableTest {
  @testSetup
  static void setup() {
    System.debug('*** CompanyBasunBatchableTest Setup() starting ***');
    TestDataFactorySetupParams setupParams = new TestDataFactorySetupParams();
    setupParams.numberOfEmployerAccounts = 100;
    TestDataFactory.setupTestData(setupParams);
  }

  @isTest
  static void testUpdateCompnay() {
    Test.setMock(
      HttpCalloutMock.class,
      new MockHttpResponseGenerator('subscribeCompany')
    );
    Test.startTest();
    CompanyBasunBatchable c = new CompanyBasunBatchable();
    Database.executeBatch(c);
    SchedulableDailyEmployer.scheduleIt();
    Test.stopTest();
  }
}