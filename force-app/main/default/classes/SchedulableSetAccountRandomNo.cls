/**
 * @description       : 
 * @author            : Malin Nilsson (Stretch Customer AB)
 * @group             : 
 * @last modified on  : 2025-01-09
 * @last modified by  : Malin Nilsson (Stretch Customer AB)
**/
public with sharing class SchedulableSetAccountRandomNo implements Schedulable {

    private static String CRON_EXPR = '0 30 01 ? * *'; // every day at 01:30 AM

    public static String scheduleIt() {
        SchedulableSetAccountRandomNo job = new SchedulableSetAccountRandomNo();
        String jobName;
        if(Test.isRunningTest())
            jobName = 'Test_SchedulableSetAccountRandomNo';
        else
            jobName = 'Schedulable Set Account Random No';
        
        return System.schedule(jobName, CRON_EXPR, job);
    }

    public void execute(SchedulableContext sc) {
       runBatch();
    }

    public static void runBatch(){
        // Instantiate and execute the batch class
        SetAccountRandomNoBatch batch = new SetAccountRandomNoBatch();
        Database.executeBatch(batch, 200); // Specify batch size (default is 200)
    }
}