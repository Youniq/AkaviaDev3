/**
 * @description       : Test class for RecordDeletionScheduler
 * @author            : Malin Nilsson (Stretch Customer AB)
 * @group             : 
 * @last modified on  : 2025-04-15
 * @last modified by  : Malin Nilsson (Stretch Customer AB)
**/
@isTest
private class RecordDeletionSchedulerTest {
    @TestSetup
    static void setup() {
        // Clean up any existing scheduled jobs
        List<CronTrigger> existingJobs = [
            SELECT Id 
            FROM CronTrigger 
            WHERE CronJobDetail.Name LIKE 'RecordDeletionScheduler%'
        ];
        for (CronTrigger job : existingJobs) {
            System.abortJob(job.Id);
        }
    }
    
    @isTest
    static void testScheduleAll() {
        Test.startTest();
        
        // Call the scheduleAll method
        RecordDeletionScheduler.scheduleAll();
        
        Test.stopTest();
        
        // Verify that the jobs were scheduled
        List<CronTrigger> scheduledJobs = [
            SELECT Id, CronExpression, CronJobDetail.Name 
            FROM CronTrigger 
            WHERE CronJobDetail.Name LIKE 'RecordDeletionScheduler%'
        ];
        for (CronTrigger job : scheduledJobs) {
            system.debug(job.CronJobDetail.Name);
            system.debug(job.Id);

        }
        
        System.assertEquals(4, scheduledJobs.size(), 'Expected 4 scheduled jobs');
        
        // Verify the job names and cron expressions
        for (CronTrigger job : scheduledJobs) {
            System.assert(
                job.CronJobDetail.Name.contains('Task') || 
                job.CronJobDetail.Name.contains('EmailMessage')||
                job.CronJobDetail.Name.contains('Invoice') ||
                job.CronJobDetail.Name.contains('IndividualEmailResult'),
                'Job name should contain either Task || EmailMessage || Invoice || IndividualEmailResult '
            );
        }
        
        // Clean up the scheduled jobs
        for (CronTrigger job : scheduledJobs) {
            System.abortJob(job.Id);
        }
    }
    
    @isTest
    static void testExecuteTaskDeletion() {
        // Create test data
        List<Task> testTasks = new List<Task>();
        for (Integer i = 0; i < 5; i++) {
            testTasks.add(new Task(
                Subject = 'Test Task ' + i,
                ActivityDate = Date.today().addDays(-1)
            ));
        }
        insert testTasks;
        
        Test.startTest();
        RecordDeletionScheduler scheduler = new RecordDeletionScheduler('Task', '0 30 03 ? * *');
        scheduler.execute(null);
        Test.stopTest();
        
        // Verify that the batch job was executed
        List<AsyncApexJob> jobs = [
            SELECT Id, Status, JobType 
            FROM AsyncApexJob 
            WHERE JobType = 'BatchApex'
        ];
        
        System.assertEquals(1, jobs.size(), 'Expected 1 batch job');
    }
    
    @isTest
    static void testExecuteEmailMessageDeletion() {
        // Create test data
        List<EmailMessage> testEmails = new List<EmailMessage>();
        for (Integer i = 0; i < 5; i++) {
            testEmails.add(new EmailMessage(
                Subject = 'Test Email ' + i,
                TextBody = 'Test Body ' + i
            ));
        }
        insert testEmails;
        
        Test.startTest();
        RecordDeletionScheduler scheduler = new RecordDeletionScheduler('EmailMessage', '0 45 03 ? * *');
        scheduler.execute(null);
        Test.stopTest();
        
        // Verify that the batch job was executed
        List<AsyncApexJob> jobs = [
            SELECT Id, Status, JobType 
            FROM AsyncApexJob 
            WHERE JobType = 'BatchApex'
        ];
        
        System.assertEquals(1, jobs.size(), 'Expected 1 batch job');
    }
    
    @isTest
    static void testExecuteInvalidObject() {
        Test.startTest();
        RecordDeletionScheduler scheduler = new RecordDeletionScheduler('InvalidObject', '0 30 03 ? * *');
        scheduler.execute(null);
        Test.stopTest();
        
        // Verify that no batch job was executed for invalid object
        List<AsyncApexJob> jobs = [
            SELECT Id, Status, JobType 
            FROM AsyncApexJob 
            WHERE JobType = 'BatchApex'
        ];
        
        System.assertEquals(0, jobs.size(), 'Expected no batch jobs for invalid object');
    }
}