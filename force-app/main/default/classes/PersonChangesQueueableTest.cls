/**
 * @description       :
 * @author            : Malin Nilsson (Stretch Customer AB)
 * @group             :
 * @last modified on  : 2024-04-23
 * @last modified by  : Malin Nilsson (Stretch Customer AB)
 **/
@isTest
private class PersonChangesQueueableTest {
  @isTest
  static void testGetPersonChanges() {
    Test.setMock(
      HttpCalloutMock.class,
      new MockHttpResponseGenerator('BCIMonitoringResponseString')
    );

    Test.startTest();
    System.enqueueJob(new PersonChangesQueueable(null));
    Test.stopTest();

    for (DebugLog__c log : [SELECT Id, Message__c FROM DebugLog__c]) {
      System.debug(log);
    }

    for (Callout__c callout : [SELECT Id, Response__c FROM Callout__c]) {
      System.debug(callout);
    }
  }

  @isTest
  static void testGetPersonChangesFalse() {
    Test.setMock(
      HttpCalloutMock.class,
      new MockHttpResponseGenerator('BCIMonitoringResponseFalse')
    );

    Test.startTest();
    System.enqueueJob(new PersonChangesQueueable(null));
    Test.stopTest();
  }
}