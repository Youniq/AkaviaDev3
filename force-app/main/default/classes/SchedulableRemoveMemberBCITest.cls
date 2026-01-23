@isTest
private class SchedulableRemoveMemberBCITest {
  @isTest
  static void testRemoveMemberBCI() {
    Test.setMock(
      HttpCalloutMock.class,
      new MockHttpResponseGenerator('BCIMonitoringResponseString')
    );

    Test.startTest();
    SchedulableRemoveMemberBCI.scheduleIt();
    Test.stopTest();
  }
}