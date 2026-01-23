global with sharing class SchedulableRemoveMemberBCI implements Schedulable, Database.AllowsCallouts {
    public static String CRON_EXPR = '0 0 2 1/1 * ? *'; //Daily att 02:00 
    
    global static String scheduleIt() {
        
        CRON_EXPR__mdt [] cronEx = [Select Expression__c  from CRON_EXPR__mdt where MasterLabel = 'SchedulableRemoveMemberBCI'];
        
        if (cronEx.size() > 0)
            CRON_EXPR = cronEx[0].Expression__c;
        
        system.debug(CRON_EXPR);
        SchedulableRemoveMemberBCI job = new SchedulableRemoveMemberBCI();
        String jobName;
        if(Test.isRunningTest())
            jobName = 'TestSchedulableRemoveMemberBCI';
        else
            jobName = 'SchedulableRemoveMemberBCI';
        
        return System.schedule(jobName, CRON_EXPR, job);
    }
    
    global void execute(SchedulableContext SC) {
        RemovePersonFromBCIBatchable cb = new RemovePersonFromBCIBatchable( );
        Database.executeBatch(cb, 5);
    }
}