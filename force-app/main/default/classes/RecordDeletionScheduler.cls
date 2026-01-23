/**
 * @description       : Scheduler class for record deletion jobs
 * @author            : Malin Nilsson (Stretch Customer AB)
 * @group             : 
 * @last modified on  : 2025-04-15
 * @last modified by  : Malin Nilsson (Stretch Customer AB)
**/
global class RecordDeletionScheduler implements Schedulable {
    private static String CRON_EXPR1 = '0 30 03 ? * *'; // every day at 03:30 AM
    private static String CRON_EXPR2 = '0 45 03 ? * *'; // every day at 03:45 AM
    private static String CRON_EXPR3 = '0 00 04 ? * *'; // every day at 04:00 AM
    private static String CRON_EXPR4 = '0 15 04 ? * *'; // every day at 04:15 AM
    private String objectApiName;
    private String cronExpression;
    private String jobName; 

    public RecordDeletionScheduler(String objectApiName, String cronExpression) {
        this.objectApiName = objectApiName;
        this.cronExpression = cronExpression;

        if (Test.isRunningTest()) {
            this.jobName = 'RecordDeletionScheduler - ' + objectApiName + ' - Test';
        } else {
            this.jobName = 'RecordDeletionScheduler - ' + objectApiName;
        }
    }

    //Schedules one job for each object
    public static void scheduleAll() {
        RecordDeletionScheduler tasksJob = new RecordDeletionScheduler(
            'Task',
            CRON_EXPR1
        );
        scheduleJob(tasksJob);

        RecordDeletionScheduler emailMessagesjob = new RecordDeletionScheduler(
            'EmailMessage',
            CRON_EXPR2
        );
        scheduleJob(emailMessagesjob);

        RecordDeletionScheduler individualEmailResultsJob = new RecordDeletionScheduler(
            'et4ae5__IndividualEmailResult__c',
            CRON_EXPR3
        );
        scheduleJob(individualEmailResultsJob);

        RecordDeletionScheduler invoicesJob = new RecordDeletionScheduler(
            'Invoice__c',
            CRON_EXPR4
        );

        scheduleJob(invoicesJob);
    }

    private static void scheduleJob(RecordDeletionScheduler job) {
        // Adding try catch to avoid errors when scheduling jobs, if the job already exists
        try {
            System.schedule(job.jobName, job.cronExpression, job);
            System.debug('Job scheduled: ' + job.jobName);
        } catch (Exception e) {
            System.debug('Error scheduling job: ' + e.getMessage());
        }
    }
  
    /**
     * Execute method required by Schedulable interface
     * @param sc The SchedulableContext
     */
    global void execute(SchedulableContext sc) {
        String query;
        
        // Build the appropriate query based on the object
        if (objectApiName == 'Task') {
            query = RecordDeletionUtils.buildTaskQuery();
        } else if (objectApiName == 'EmailMessage') {
            query = RecordDeletionUtils.buildEmailMessageQuery();
        }
        else if (objectApiName == 'et4ae5__IndividualEmailResult__c') {
            query = RecordDeletionUtils.buildIndividualEmailResultQuery();
        }
        else if (objectApiName == 'Invoice__c') {
            query = RecordDeletionUtils.buildInvoiceQuery();
        }
        
        if (String.isNotBlank(query)) {
            TEMP_BatchDelete batch = new TEMP_BatchDelete(query);
            Database.executeBatch(batch);
        }
    }
}