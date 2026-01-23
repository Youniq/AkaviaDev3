@isTest
public class ScheduleDeleteIndEmailResultTest {
    
static testmethod void test() {
   Test.startTest();

    String jobId = ScheduleDeleteIndEmailResult.scheduleIt();

      // Get the information from the CronTrigger API object
      CronTrigger ct = [SELECT Id, CronExpression, TimesTriggered, 
      NextFireTime FROM CronTrigger WHERE id = :jobId];

      // Verify the job has not run
      System.assertEquals(0, ct.TimesTriggered);
   	  Test.stopTest();

   }
}