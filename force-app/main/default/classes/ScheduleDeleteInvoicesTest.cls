@isTest
public with sharing class ScheduleDeleteInvoicesTest {
  static testMethod void test() {
    Test.startTest();

    String jobId = ScheduleDeleteInvoices.scheduleIt();

    // Get the information from the CronTrigger API object
    CronTrigger ct = [
      SELECT Id, CronExpression, TimesTriggered, NextFireTime
      FROM CronTrigger
      WHERE id = :jobId
    ];

    // Verify the job has not run
    System.assertEquals(0, ct.TimesTriggered);
    Test.stopTest();
  }
}