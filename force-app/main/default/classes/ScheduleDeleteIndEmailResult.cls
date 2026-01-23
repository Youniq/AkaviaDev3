public class ScheduleDeleteIndEmailResult implements Schedulable {
 private static String CRON_EXPR = '0 30 02 ? * *'; // every day at 02:30 AM
    
 public static String scheduleIt() {
    ScheduleDeleteIndEmailResult job = new ScheduleDeleteIndEmailResult();
      String jobName;
      if(Test.isRunningTest()){
                jobName = 'Individual_Email_Result_-_Test_Schedule_Delete';
          }else{
                jobName = 'Individual_Email_Result_-_Schedule_Delete';
          }
        return System.schedule(jobName, CRON_EXPR, job);
  }
    
    public void execute (SchedulableContext ctx) {
        String query = 'select id from et4ae5__IndividualEmailResult__c where CreatedDate < N_DAYS_AGO:93 limit 100000';
        TEMP_BatchDelete b = new TEMP_BatchDelete(query);
        Database.executeBatch(b);
    }
}