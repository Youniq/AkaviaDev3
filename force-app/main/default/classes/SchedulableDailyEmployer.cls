global with sharing class SchedulableDailyEmployer implements Schedulable {
  public static final String CRON_EXPR = '0 30 0 1/1 * ? *'; //Daily att 00:30

  global static String scheduleIt() {
    SchedulableDailyEmployer job = new SchedulableDailyEmployer();
      String jobName;
      if(Test.isRunningTest()){
                jobName = 'TestDailyEmployerUpdateBasun';
          }else{
                jobName = 'DailyEmployerUpdateBasun';
          }
        return System.schedule(jobName, CRON_EXPR, job);
  }

  global void execute(SchedulableContext SC) {
    Database.executeBatch(new CompanyBasunBatchable());
    //Database.executeBatch(new CompanyBasunBatchable(),10);
  }
}