
/**
 * GDPR Lead Cleanup
 *
 * Custom Metadata:
 * GDPR_Cleanup_Setting__mdt
 * DeveloperName = LeadCleanup
 *
 * Rules:
 * 1. Approved on creation date or following calendar date:
 *    Delete from Salesforce and Marketing Cloud.
 *
 * 2. Approved two or more calendar days later:
 *    Preserve in Salesforce, delete from Marketing Cloud.
 *
 * 3. Not approved and older than retention period:
 *    Delete from Salesforce and Marketing Cloud.
 *
 * 4. Missing or invalid approval date:
 *    Preserve for manual review.
 *
 * All deletion decisions are written to
 * GDPR_Deletion_Queue__c before Salesforce deletion.
 *
 * DryRun:
 * - Writes review records.
 * - Does not delete Salesforce Leads.
 * - Does not authorize Marketing Cloud deletion.
 *
 * Marketing Cloud Contact Delete is handled separately.
 */
public without sharing class LeadCleanupBatch
    implements Database.Batchable<SObject>,
               Database.Stateful,
               Schedulable {

    private static final String SETTINGS_NAME = 'LeadCleanup';
    private static final String TEST_PREFIX = 'GDPR-TEST-';
    private String testPattern;
    public class CleanupException extends Exception {}

    private Boolean enabled = false;
    private Boolean dryRun = true;

    private Integer retentionDays = 90;
    private Datetime cutoffDate;

    private Integer processed = 0;
    private Integer eligibleSalesforce = 0;
    private Integer eligibleMarketingCloud = 0;
    private Integer deletedSalesforce = 0;
    private Integer failed = 0;
    private Integer skipped = 0;

    private List<String> errors = new List<String>();

    public LeadCleanupBatch() {
        initialize(null);
    }

    public LeadCleanupBatch(Boolean forceDryRun) {
        initialize(forceDryRun);
    }

    // Restrict an operational test to records explicitly marked GDPR-TEST-.
    // The metadata DryRun flag remains the authority: false does not override true.
    public LeadCleanupBatch(Boolean forceDryRun, String testPrefix) {
        initialize(forceDryRun);
        if (testPrefix != TEST_PREFIX) {
            throw new CleanupException('Only GDPR-TEST- is permitted as test filter.');
        }
        testPattern = TEST_PREFIX + '%';
    }

    @TestVisible
    private LeadCleanupBatch(
        Boolean testEnabled,
        Boolean testDryRun,
        Integer testRetentionDays
    ) {
        enabled = testEnabled == true;
        dryRun = testDryRun != false;
        retentionDays = testRetentionDays;

        if (retentionDays == null || retentionDays < 1) {
            enabled = false;
            dryRun = true;
            retentionDays = 90;
        }

        cutoffDate = System.now().addDays(-retentionDays);
    }

    private void initialize(Boolean forceDryRun) {

        GDPR_Cleanup_Setting__mdt settings =
            GDPR_Cleanup_Setting__mdt.getInstance(SETTINGS_NAME);

        if (settings == null) {
            System.debug(
                LoggingLevel.ERROR,
                'LEAD CLEANUP: Settings missing.'
            );
            return;
        }

        enabled = settings.Enabled__c == true;

        dryRun =
            settings.DryRun__c != false ||
            forceDryRun == true;

        Decimal configuredDays = settings.RetentionDays__c;

        if (configuredDays != null &&
            (configuredDays < 1 ||
             configuredDays != configuredDays.setScale(0))) {

            enabled = false;
            dryRun = true;
            return;
        }

        retentionDays = configuredDays == null
            ? 90
            : configuredDays.intValue();

        cutoffDate = System.now().addDays(-retentionDays);
    }

    public Database.QueryLocator start(
        Database.BatchableContext bc
    ) {
        if (!enabled) {
            return Database.getQueryLocator([
                SELECT Id
                FROM Lead
                WHERE Id = null
            ]);
        }

        // All Leads are evaluated because approved Leads
        // may qualify before the 90-day retention cutoff.
        if (testPattern != null) {
            String pattern = testPattern;
            return Database.getQueryLocator([
                SELECT Id, Email, CreatedDate
                FROM Lead
                WHERE LastName LIKE :pattern
            ]);
        }
        return Database.getQueryLocator([
            SELECT Id, Email, CreatedDate
            FROM Lead
        ]);
    }

    public void execute(
        Database.BatchableContext bc,
        List<SObject> scope
    ) {
        if (!enabled || scope == null || scope.isEmpty()) {
            return;
        }

        processed += scope.size();

        Map<Id, Lead> leads = new Map<Id, Lead>();

        for (SObject item : scope) {
            Lead leadRecord = (Lead)item;
            leads.put(leadRecord.Id, leadRecord);
        }

        Map<Id, List<Application__c>> applicationsByLead =
            new Map<Id, List<Application__c>>();

        for (Application__c app : [
            SELECT Id, Lead__c, Decision__c, DecisionDate__c
            FROM Application__c
            WHERE Lead__c IN :leads.keySet()
        ]) {
            if (!applicationsByLead.containsKey(app.Lead__c)) {
                applicationsByLead.put(
                    app.Lead__c,
                    new List<Application__c>()
                );
            }

            applicationsByLead.get(app.Lead__c).add(app);
        }

        Map<String, GDPR_Deletion_Queue__c> existingQueue =
            new Map<String, GDPR_Deletion_Queue__c>();

        Set<String> externalKeys = new Set<String>();

        for (Id leadId : leads.keySet()) {
            externalKeys.add(String.valueOf(leadId));
        }

        for (GDPR_Deletion_Queue__c queueRecord : [
            SELECT Id, ExternalKey__c,
                   SalesforceStatus__c,
                   MarketingCloudStatus__c
            FROM GDPR_Deletion_Queue__c
            WHERE ExternalKey__c IN :externalKeys
        ]) {
            existingQueue.put(
                queueRecord.ExternalKey__c,
                queueRecord
            );
        }

        List<GDPR_Deletion_Queue__c> queueToSave =
            new List<GDPR_Deletion_Queue__c>();

        // Keyed by ExternalKey__c.
        Map<String, Lead> leadsToDelete =
            new Map<String, Lead>();

        for (Lead leadRecord : leads.values()) {

            String externalKey = String.valueOf(leadRecord.Id);

            List<Application__c> applications =
                applicationsByLead.get(leadRecord.Id);

            Boolean hasApproved = false;
            Boolean hasEarlyApproval = false;
            Boolean hasLateApproval = false;
            Boolean hasInvalidApproval = false;

            Date decisionDate;

            if (applications != null) {

                for (Application__c app : applications) {

                    if (app.Decision__c != 'Godkänd') {
                        continue;
                    }

                    hasApproved = true;

                    Date leadCreationDate = leadRecord.CreatedDate.date();
                    if (app.DecisionDate__c == null ||
                        app.DecisionDate__c > Date.today() ||
                        app.DecisionDate__c < leadCreationDate) {
                        hasInvalidApproval = true;
                        continue;
                    }

                    Integer daysBetween =
                        leadCreationDate.daysBetween(app.DecisionDate__c);

                    if (daysBetween >= 0 && daysBetween <= 1) {
                        hasEarlyApproval = true;
                    } else {
                        hasLateApproval = true;
                    }

                    if (decisionDate == null ||
                        app.DecisionDate__c < decisionDate) {

                        decisionDate = app.DecisionDate__c;
                    }
                }
            }

            Boolean deleteSF = false;
            Boolean deleteMC = false;
            String reason;

            if (hasApproved) {

                if (hasInvalidApproval) {
                    skipped++;
                    continue;
                }

                if (hasLateApproval) {
                    deleteSF = false;
                    deleteMC = true;
                    reason = 'ApprovedAfter1Day';

                } else if (hasEarlyApproval) {
                    deleteSF = true;
                    deleteMC = true;
                    reason = 'ApprovedWithin1Day';
                }

            } else if (leadRecord.CreatedDate <= cutoffDate) {

                deleteSF = true;
                deleteMC = true;
                reason = 'Retention90Days';
            }

            if (!deleteSF && !deleteMC) {
                skipped++;
                continue;
            }

            GDPR_Deletion_Queue__c existing =
                existingQueue.get(externalKey);

            // Salesforce deletion must not be blocked by MC completion.
            // An already completed Salesforce status with an existing Lead
            // is an inconsistency requiring manual review.
            if (existing != null &&
                existing.SalesforceStatus__c == 'Deleted') {
                skipped++;
                addError('Existing Salesforce Deleted status for live Lead=' + externalKey);
                continue;
            }

            GDPR_Deletion_Queue__c queueRecord =
                new GDPR_Deletion_Queue__c();

            queueRecord.ExternalKey__c = externalKey;
            queueRecord.LeadId__c = externalKey;
            queueRecord.Email__c = leadRecord.Email;
            queueRecord.LeadCreatedDate__c =
                leadRecord.CreatedDate;

            queueRecord.DecisionDate__c = decisionDate;
            queueRecord.DeletionReason__c = reason;

            queueRecord.DeleteFromSalesforce__c = deleteSF;
            queueRecord.DeleteFromMarketingCloud__c = deleteMC;

            if (dryRun) {

                queueRecord.SalesforceStatus__c =
                    'DryRun';

                queueRecord.MarketingCloudStatus__c =
                    'DryRun';

            } else {

                queueRecord.SalesforceStatus__c =
                    deleteSF ? 'Pending' : 'Retained';

                queueRecord.MarketingCloudStatus__c =
                    'Pending';
            }

            if (existing != null) {
                queueRecord.Id = existing.Id;

                // Never requeue a previously submitted or completed MC deletion.
                // Failed requests require an explicit retry decision.
                if (existing.MarketingCloudStatus__c == 'Submitted' ||
                    existing.MarketingCloudStatus__c == 'Deleted' ||
                    existing.MarketingCloudStatus__c == 'Failed') {
                    queueRecord.MarketingCloudStatus__c =
                        existing.MarketingCloudStatus__c;
                }

                if (dryRun &&
                    existing.SalesforceStatus__c == 'Retained') {
                    queueRecord.SalesforceStatus__c = 'Retained';
                }
            }

            queueToSave.add(queueRecord);

            if (deleteSF) {
                eligibleSalesforce++;

                if (!dryRun) {
                    leadsToDelete.put(externalKey, leadRecord);
                }
            }

            if (deleteMC) {
                eligibleMarketingCloud++;
            }
        }

        if (queueToSave.isEmpty()) {
            return;
        }

        // One transaction per execute scope. Any failure rolls back queue
        // changes AND Lead deletions; never leave a Pending queue by accident.
        Savepoint checkpoint = Database.setSavepoint();
        try {
        Database.UpsertResult[] queueResults =
            Database.upsert(
                queueToSave,
                GDPR_Deletion_Queue__c.Fields.ExternalKey__c,
                false
            );

        List<Lead> confirmedForDeletion =
            new List<Lead>();

        Map<String, Id> queueIdsByLead =
            new Map<String, Id>();

        for (Integer i = 0; i < queueResults.size(); i++) {

            String key = queueToSave[i].ExternalKey__c;

            if (!queueResults[i].isSuccess()) {

                failed++;

                for (Database.Error err :
                    queueResults[i].getErrors()) {

                    addError(
                        'Queue failed. Lead=' + key +
                        ' Error=' + err.getMessage()
                    );
                }

                throw new CleanupException('Queue upsert failed for Lead=' + key);
            }

            queueIdsByLead.put(
                key,
                queueResults[i].getId()
            );

            if (!dryRun && leadsToDelete.containsKey(key)) {
                confirmedForDeletion.add(
                    leadsToDelete.get(key)
                );
            }
        }

        if (dryRun || confirmedForDeletion.isEmpty()) {
            return;
        }

        Database.DeleteResult[] deleteResults =
            Database.delete(confirmedForDeletion, false);

        List<GDPR_Deletion_Queue__c> statusUpdates =
            new List<GDPR_Deletion_Queue__c>();

        for (Integer i = 0; i < deleteResults.size(); i++) {

            Lead leadRecord = confirmedForDeletion[i];

            String key = String.valueOf(leadRecord.Id);

            GDPR_Deletion_Queue__c statusRecord =
                new GDPR_Deletion_Queue__c(
                    Id = queueIdsByLead.get(key)
                );

            if (deleteResults[i].isSuccess()) {

                deletedSalesforce++;

                statusRecord.SalesforceStatus__c =
                    'Deleted';

                statusRecord.ProcessedDate__c =
                    System.now();

            } else {

                failed++;

                statusRecord.SalesforceStatus__c =
                    'Failed';

                List<String> messages = new List<String>();

                for (Database.Error err :
                    deleteResults[i].getErrors()) {

                    messages.add(err.getMessage());
                }

                statusRecord.ErrorMessage__c =
                    String.join(messages, ' | ');

                addError(
                    'Delete failed. Lead=' + key +
                    ' Error=' + statusRecord.ErrorMessage__c
                );
                throw new CleanupException('Lead deletion failed for Lead=' + key);
            }

            statusUpdates.add(statusRecord);
        }

        if (!statusUpdates.isEmpty()) {

            Database.SaveResult[] updateResults =
                Database.update(statusUpdates, false);

            for (Integer i = 0; i < updateResults.size(); i++) {

                if (!updateResults[i].isSuccess()) {

                    failed++;

                    for (Database.Error err :
                        updateResults[i].getErrors()) {

                        addError(
                            'Status update failed. Queue=' +
                            statusUpdates[i].Id +
                            ' Error=' + err.getMessage()
                        );
                        throw new CleanupException('Queue status update failed');
                    }
                }
            }
        }
        } catch (Exception e) {
            Database.rollback(checkpoint);
            System.debug(LoggingLevel.ERROR,
                'LEAD CLEANUP ROLLED BACK scope: ' + e.getMessage());
            throw e;
        }
    }

    private void addError(String message) {

        System.debug(LoggingLevel.ERROR, message);

        if (errors.size() < 100) {
            errors.add(message);
        }
    }

    public void finish(Database.BatchableContext bc) {

        System.debug(
            LoggingLevel.INFO,
            'LEAD CLEANUP FINISHED' +
            ' | Enabled=' + enabled +
            ' | DryRun=' + dryRun +
            ' | RetentionDays=' + retentionDays +
            ' | Processed=' + processed +
            ' | EligibleSalesforce=' + eligibleSalesforce +
            ' | EligibleMarketingCloud=' + eligibleMarketingCloud +
            ' | DeletedSalesforce=' + deletedSalesforce +
            ' | Failed=' + failed +
            ' | Skipped=' + skipped
        );

        for (String message : errors) {
            System.debug(LoggingLevel.ERROR, message);
        }

        // Never invoke the single production MC environment from a sandbox,
        // an operational GDPR-TEST- run, or a DryRun.
        if (!enabled || dryRun || testPattern != null || failed > 0) {
            return;
        }

        Organization orgInfo = [
            SELECT IsSandbox FROM Organization LIMIT 1
        ];
        if (orgInfo.IsSandbox) {
            System.debug(LoggingLevel.INFO,
                'LEAD CLEANUP: MC submission skipped in Salesforce sandbox.');
            return;
        }

        // Do not launch MC deletion if any batch scope failed.
        AsyncApexJob batchJob = [
            SELECT NumberOfErrors
            FROM AsyncApexJob
            WHERE Id = :bc.getJobId()
            LIMIT 1
        ];
        if (batchJob.NumberOfErrors > 0) {
            System.debug(LoggingLevel.ERROR,
                'LEAD CLEANUP: MC submission skipped due to batch errors.');
            return;
        }

        Integer pendingCount = [
            SELECT COUNT()
            FROM GDPR_Deletion_Queue__c
            WHERE DeleteFromMarketingCloud__c = true
            AND MarketingCloudStatus__c = 'Pending'
            AND LeadId__c != null
        ];

        if (pendingCount == 0) {
            return;
        }

        // Reuse the existing Queueable + Callout__c logging integration.
        // Each invocation processes up to McSetting__c.ContactDeleteLimit__c.
        Id mcJobId = ScheduleDeleteMcContacts.initDeleteGdprContacts();
        System.debug(LoggingLevel.INFO,
            'LEAD CLEANUP: MC GDPR job queued. JobId=' + mcJobId +
            ' | Pending=' + pendingCount);
    }

    public void execute(SchedulableContext sc) {

        Database.executeBatch(
            new LeadCleanupBatch(),
            100
        );
    }
}
