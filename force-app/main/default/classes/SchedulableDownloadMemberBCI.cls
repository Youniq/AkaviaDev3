global with sharing class SchedulableDownloadMemberBCI implements Schedulable, Database.AllowsCallouts {
    public static String CRON_EXPR = '0 0 1 1/1 * ? *'; //Daily att 01:00 
    
    global static String scheduleIt() {
        
        CRON_EXPR__mdt [] cronEx = [Select Expression__c  from CRON_EXPR__mdt where MasterLabel = 'SchedulableDownloadMemberBCI'];
        
        if (cronEx.size() > 0)
            CRON_EXPR = cronEx[0].Expression__c;
        
        system.debug(CRON_EXPR);
        SchedulableDownloadMemberBCI job = new SchedulableDownloadMemberBCI();
        String jobName;
        if(Test.isRunningTest())
            jobName = 'TestSchedulableDownloadMemberBCI';
        else
            jobName = 'SchedulableDownloadMemberBCI';
        
        return System.schedule(jobName, CRON_EXPR, job);
    }
    
    global void execute(SchedulableContext SC) {
        DownloadPersonPendingBatchable cb = new DownloadPersonPendingBatchable( );
        Database.executeBatch(cb, 5);
    }
}