/**
 * @description       :
 * @author            : Malin Nilsson (Stretch Customer AB)
 * @group             :
 * @last modified on  : 2024-09-25
 * @last modified by  : Malin Nilsson (Stretch Customer AB)
 **/
global with sharing class SchedulableDailyPersonBCI implements Schedulable, Database.AllowsCallouts {
  public static final String CRON_EXPR = '0 30 1 1/1 * ? *'; //Daily att 01:30

  global static String scheduleIt() {
    SchedulableDailyPersonBCI job = new SchedulableDailyPersonBCI();
    String jobName;
    if (Test.isRunningTest()) {
      jobName = 'TestDailyUpdatePersonByBCI';
    } else {
      jobName = 'DailyUpdatePersonByBCI';
    }
    return System.schedule(jobName, CRON_EXPR, job);
  }

  global void execute(SchedulableContext SC) {
    String cachedCursor = null;

    bisnode__c bisnodeSetting = bisnode__c.getOrgDefaults();

    if (bisnodeSetting != null) {
      cachedCursor = bisnodeSetting.BisnodeCursor__c;
    }

    ID jobID = System.enqueueJob(new PersonChangesQueueable(cachedCursor));
  }
}