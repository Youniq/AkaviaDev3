global with sharing class SchedulableDailyWorkplace implements Schedulable {
  public static final String CRON_EXPR = '0 0 3 1/1 * ? *'; //Daily att 03:00

  global static String scheduleIt() {
    SchedulableDailyWorkplace job = new SchedulableDailyWorkplace();
      String jobName;
      if(Test.isRunningTest()){
                jobName = 'TestDailyWorkplaceUpdateBasun';
          }else{
                jobName = 'DailyWorkplaceUpdateBasun';
          }
        return System.schedule(jobName, CRON_EXPR, job);
  }

  global void execute(SchedulableContext SC) {
    Database.executeBatch(new WorksiteBasunBatchable());
     // Database.executeBatch(new WorksiteBasunBatchable(),10);
  }
}