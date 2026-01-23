@isTest
private class SchedulableDailyPersonBCITest {
  @isTest
  static void testDailyDailyPersonBCI() {
    Test.setMock(
      HttpCalloutMock.class,
      new MockHttpResponseGenerator('BCIMonitoringResponseString')
    );

    Test.startTest();
    SchedulableDailyPersonBCI.scheduleIt();
    Test.stopTest();
  }
}