/**
 * GDPR Lead Cleanup
 * Custom Metadata: GDPR_Cleanup_Setting__mdt, DeveloperName = LeadCleanup
 *
 * Rules:
 *  - No membership: delete Lead after RetentionDays__c (default 90).
 *  - Verified new membership: delete Lead after ConvertedRetentionHours__c
 *    (minimum/default 24), provided membership was created on the same
 *    UTC calendar date as Lead, not before Lead.
 *  - Historical, imported or ambiguous membership: preserve Lead.
 *  - Completed application with missing Person__c: preserve Lead.
 *
 * Only Lead records are deleted. Applications, Accounts and Memberships
 * are never explicitly deleted by this class. Check org cascade behavior.
 *
 * Schedule: System.schedule('Lead Cleanup Daily', '0 30 2 * * ?', new LeadCleanupBatch());
 * Dry run: Database.executeBatch(new LeadCleanupBatch(true), 100);
 */
public without sharing class LeadCleanupBatch
    implements Database.Batchable<SObject>, Database.Stateful, Schedulable {

    private static final String SETTINGS_NAME = 'LeadCleanup';
    private static final Integer MAX_LOGGED_LEADS = 100;
    private static final Integer MAX_LOGGED_ERRORS = 100;

    private Boolean enabled = false;
    private Boolean dryRun = true;
    private Datetime cutoffDate;
    private Datetime convertedCutoff;
    private Integer retentionDays = 90;
    private Integer convertedRetentionHours = 24;

    private Integer processed = 0;
    private Integer eligible = 0;
    private Integer deleted = 0;
    private Integer failed = 0;
    private Integer skipped = 0;

    private List<String> errors = new List<String>();
    private List<String> eligibleLeadIds = new List<String>();

    public LeadCleanupBatch() {
        initialize(null);
    }

    public LeadCleanupBatch(Boolean forceDryRun) {
        initialize(forceDryRun);
    }

    @TestVisible
    private LeadCleanupBatch(
        Boolean testEnabled,
        Boolean testDryRun,
        Integer testRetentionDays,
        Integer testConvertedRetentionHours
    ) {
        enabled = testEnabled == true;
        dryRun = testDryRun != false;
        retentionDays = testRetentionDays;
        convertedRetentionHours = testConvertedRetentionHours;
        if (retentionDays == null || retentionDays < 1 ||
            convertedRetentionHours == null || convertedRetentionHours < 24) {
            enabled = false;
            dryRun = true;
            retentionDays = 90;
            convertedRetentionHours = 24;
        }
        Datetime nowUtc = System.now();
        cutoffDate = nowUtc.addDays(-retentionDays);
        convertedCutoff = nowUtc.addHours(-convertedRetentionHours);
    }

    private void initialize(Boolean forceDryRun) {
        GDPR_Cleanup_Setting__mdt settings =
            GDPR_Cleanup_Setting__mdt.getInstance(SETTINGS_NAME);

        if (settings == null) {
            System.debug(LoggingLevel.ERROR,
                'LEAD CLEANUP: Custom Metadata missing. Disabled.');
            return;
        }

        enabled = settings.Enabled__c == true;
        dryRun = settings.DryRun__c != false || forceDryRun == true;

        Decimal configuredDays = settings.RetentionDays__c;
        Decimal configuredHours = settings.ConvertedRetentionHours__c;

        if ((configuredDays != null &&
             (configuredDays < 1 || configuredDays != configuredDays.setScale(0))) ||
            (configuredHours != null &&
             (configuredHours < 24 || configuredHours != configuredHours.setScale(0)))) {
            enabled = false;
            dryRun = true;
            System.debug(LoggingLevel.ERROR,
                'LEAD CLEANUP: Invalid retention configuration. Disabled.');
            return;
        }

        retentionDays = configuredDays == null ? 90 : configuredDays.intValue();
        convertedRetentionHours = configuredHours == null ? 24 : configuredHours.intValue();

        Datetime nowUtc = System.now();
        cutoffDate = nowUtc.addDays(-retentionDays);
        convertedCutoff = nowUtc.addHours(-convertedRetentionHours);

        System.debug(LoggingLevel.INFO,
            'LEAD CLEANUP CONFIG | Enabled=' + enabled +
            ' | DryRun=' + dryRun +
            ' | RetentionDays=' + retentionDays +
            ' | ConvertedRetentionHours=' + convertedRetentionHours);
    }

    public Database.QueryLocator start(Database.BatchableContext bc) {
        if (!enabled) {
            System.debug(LoggingLevel.INFO, 'LEAD CLEANUP DISABLED');
            return Database.getQueryLocator([
                SELECT Id FROM Lead WHERE Id = null
            ]);
        }

        // Status-independent: covers New and Completed leads alike.
        // A lead younger than convertedCutoff cannot yet be deleted by
        // either rule (90-day standard retention or converted retention).
        Datetime oldestEligibleCutoff = convertedCutoff > cutoffDate
            ? convertedCutoff : cutoffDate;

        return Database.getQueryLocator([
            SELECT Id, CreatedDate, Status
            FROM Lead
            WHERE CreatedDate <= :oldestEligibleCutoff
        ]);
    }

    public void execute(Database.BatchableContext bc, List<SObject> scope) {
        if (!enabled || scope == null || scope.isEmpty()) return;

        processed += scope.size();
        Map<Id, Lead> leads = new Map<Id, Lead>();
        for (SObject item : scope) {
            Lead leadRecord = (Lead)item;
            leads.put(leadRecord.Id, leadRecord);
        }

        Map<Id, Set<Id>> leadPersons = new Map<Id, Set<Id>>();
        Set<Id> personIds = new Set<Id>();
        Set<Id> incompleteLinks = new Set<Id>();

        for (Application__c app : [
            SELECT Id, Lead__c, Person__c, Webstatus__c
            FROM Application__c
            WHERE Lead__c IN :leads.keySet()
        ]) {
            if (!leadPersons.containsKey(app.Lead__c)) {
                leadPersons.put(app.Lead__c, new Set<Id>());
            }
            if (app.Person__c != null) {
                leadPersons.get(app.Lead__c).add(app.Person__c);
                personIds.add(app.Person__c);
            } else if (app.Webstatus__c == 'Komplett ansökan') {
                incompleteLinks.add(app.Lead__c);
            }
        }

        Map<Id, List<Membership__c>> membershipsByPerson =
            new Map<Id, List<Membership__c>>();

        if (!personIds.isEmpty()) {
            for (Membership__c membership : [
                SELECT Id, Person__c, CreatedDate, StartDate__c
                FROM Membership__c
                WHERE Person__c IN :personIds
            ]) {
                if (!membershipsByPerson.containsKey(membership.Person__c)) {
                    membershipsByPerson.put(
                        membership.Person__c, new List<Membership__c>());
                }
                membershipsByPerson.get(membership.Person__c).add(membership);
            }
        }

        List<Lead> toDelete = new List<Lead>();

        for (Lead leadRecord : leads.values()) {
            if (incompleteLinks.contains(leadRecord.Id)) {
                skipped++;
                continue;
            }

            Boolean hasMembership = false;
            Boolean allMembershipsVerified = true;
            Boolean allMembershipsOldEnough = true;

            Set<Id> persons = leadPersons.get(leadRecord.Id);
            if (persons != null) {
                for (Id personId : persons) {
                    List<Membership__c> memberships =
                        membershipsByPerson.get(personId);
                    if (memberships == null) continue;

                    for (Membership__c membership : memberships) {
                        hasMembership = true;

                        // Historical imports, pre-existing memberships and
                        // records from another day are NOT conversion proof.
                        if (membership.CreatedDate < leadRecord.CreatedDate ||
                            membership.CreatedDate.dateGmt() !=
                                leadRecord.CreatedDate.dateGmt()) {
                            allMembershipsVerified = false;
                        }
                        if (membership.CreatedDate > convertedCutoff) {
                            allMembershipsOldEnough = false;
                        }
                    }
                }
            }

            Boolean shouldDelete;
            if (hasMembership) {
                shouldDelete = allMembershipsVerified &&
                    allMembershipsOldEnough &&
                    leadRecord.CreatedDate <= convertedCutoff;
            } else {
                shouldDelete = leadRecord.CreatedDate <= cutoffDate;
            }

            if (shouldDelete) {
                eligible++;
                toDelete.add(leadRecord);
                if (eligibleLeadIds.size() < MAX_LOGGED_LEADS) {
                    eligibleLeadIds.add(String.valueOf(leadRecord.Id));
                }
            } else {
                skipped++;
            }
        }

        if (toDelete.isEmpty()) return;

        if (dryRun) {
            System.debug(LoggingLevel.INFO,
                'LEAD CLEANUP DRY-RUN | EligibleInBatch=' + toDelete.size());
            return;
        }

        Database.DeleteResult[] results = Database.delete(toDelete, false);
        for (Integer i = 0; i < results.size(); i++) {
            if (results[i].isSuccess()) {
                deleted++;
            } else {
                failed++;
                for (Database.Error err : results[i].getErrors()) {
                    String message = 'Lead Id=' + toDelete[i].Id +
                        ' Error=' + err.getMessage();
                    if (errors.size() < MAX_LOGGED_ERRORS) errors.add(message);
                    System.debug(LoggingLevel.ERROR, message);
                }
            }
        }
    }

    public void finish(Database.BatchableContext bc) {
        System.debug(LoggingLevel.INFO,
            'LEAD CLEANUP FINISHED' +
            ' | Enabled=' + enabled +
            ' | DryRun=' + dryRun +
            ' | RetentionDays=' + retentionDays +
            ' | ConvertedRetentionHours=' + convertedRetentionHours +
            ' | Cutoff=' + cutoffDate +
            ' | ConvertedCutoff=' + convertedCutoff +
            ' | Processed=' + processed +
            ' | Eligible=' + eligible +
            ' | Deleted=' + deleted +
            ' | Failed=' + failed +
            ' | Skipped=' + skipped);

        if (!eligibleLeadIds.isEmpty()) {
            System.debug(LoggingLevel.INFO,
                'LEAD CLEANUP ELIGIBLE IDS | CountLogged=' +
                eligibleLeadIds.size() + ' | IDs=' +
                String.join(eligibleLeadIds, ','));
        }
        for (String message : errors) {
            System.debug(LoggingLevel.ERROR, message);
        }
    }

    public void execute(SchedulableContext sc) {
        Database.executeBatch(new LeadCleanupBatch(), 100);
    }
}
