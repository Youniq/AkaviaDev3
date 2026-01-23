@isTest
private class SchedulableDownloadMemberBCITest {
  @isTest
  static void testDownloadMemberBCI() {
    Test.setMock(
      HttpCalloutMock.class,
      new MockHttpResponseGenerator('BCIMonitoringResponseString')
    );

    Test.startTest();
    SchedulableDownloadMemberBCI.scheduleIt();
    Test.stopTest();
  }
}