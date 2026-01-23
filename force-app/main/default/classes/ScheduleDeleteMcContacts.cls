/**
 * @description       : This triggers a callout to Marketing Cloud attempting to delete contacts that are no longer syncing from CRM.
 * @author            : Malin Nilsson (Stretch Customer AB)
 * @group             : 
 * @last modified on  : 2024-11-05
 * @last modified by  : Malin Nilsson (Stretch Customer AB)
**/
public with sharing class ScheduleDeleteMcContacts implements Schedulable {
  private static String CRON_EXPR = '0 15 00 ? * *'; // every day at 00:15 AM

  public static String scheduleIt() {
    ScheduleDeleteMcContacts job = new ScheduleDeleteMcContacts();
    String jobName;
    if (Test.isRunningTest()) {
      jobName = 'MC Contacts - Test Schedule Delete';
    } else {
      jobName = 'MC Contacts - Schedule Delete';
    }
    return System.schedule(jobName, CRON_EXPR, job);
  }

   public void execute(SchedulableContext ctx) {
    initDeleteMcContacts();
  }

    public static void initDeleteMcContacts(){
        McDeleteContactsAsync queueable = new McDeleteContactsAsync();
        Id jobId = System.enqueueJob(queueable);

        Callout__c callout = new Callout__c();
        callout.JobId__c = jobId;
        callout.Type__c = 'Marketing Cloud - Delete contacts';
        // Set the status to 'Queued'
        callout.Status__c = 'Queued';

        insert callout;
    }
}