
/**
 * @description       : Triggers Marketing Cloud contact deletion.
 *                      Supports existing Person Account deletion
 *                      and GDPR Lead deletion.
 * @author            : Malin Nilsson (Stretch Customer AB)
 * @last modified on  : 2026-11-20
 */

 /**
 * Start GDPR Lead deletion manually via Execute Anonymous:
 *
 * Id jobId = ScheduleDeleteMcContacts.initDeleteGdprContacts();
 * System.debug('GDPR deletion JobId: ' + jobId);
 *
 * WARNING: This triggers a real Contact Delete request against
 * Marketing Cloud PROD for eligible Pending records.
 * Do not execute in Sandbox without verifying the records first.
 */

public with sharing class ScheduleDeleteMcContacts
    implements Schedulable {

    private static final String CRON_EXPR =
        '0 15 00 ? * *'; // Every day at 00:15

    // ============================================================
    // EXISTING SCHEDULED PERSON ACCOUNT DELETION
    // ============================================================

    public static String scheduleIt() {

        ScheduleDeleteMcContacts job =
            new ScheduleDeleteMcContacts();

        String jobName;

        if (Test.isRunningTest()) {
            jobName = 'MC Contacts - Test Schedule Delete';
        } else {
            jobName = 'MC Contacts - Schedule Delete';
        }

        return System.schedule(
            jobName,
            CRON_EXPR,
            job
        );
    }

    public void execute(SchedulableContext ctx) {
        initDeleteMcContacts();
    }

    // Existing Person Account deletion
    public static void initDeleteMcContacts() {

        McDeleteContactsAsync queueable =
            new McDeleteContactsAsync();

        enqueueWithCallout(
            queueable,
            'Marketing Cloud - Delete contacts'
        );
    }

    // ============================================================
    // NEW GDPR LEAD DELETION
    // ============================================================

    public static Id initDeleteGdprContacts() {

        McDeleteContactsAsync queueable =
            new McDeleteContactsAsync(true);

        return enqueueWithCallout(
            queueable,
            'Marketing Cloud - Delete contacts'
        );
    }

    // ============================================================
    // SHARED QUEUEABLE AND CALLOUT LOGGING
    // ============================================================

    private static Id enqueueWithCallout(
        McDeleteContactsAsync queueable,
        String calloutType
    ) {

        Id jobId = System.enqueueJob(queueable);

        Callout__c callout = new Callout__c();

        callout.JobId__c = jobId;
        callout.Type__c = calloutType;
        callout.Status__c = 'Queued';

        insert callout;

        System.debug(
            LoggingLevel.INFO,
            'Marketing Cloud deletion job queued. ' +
            'JobId: ' + jobId +
            ', Type: ' + calloutType
        );

        return jobId;
    }
}
