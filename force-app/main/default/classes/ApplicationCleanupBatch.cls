
public without sharing class LeadCleanupBatch
    implements Database.Batchable<SObject>,
               Database.Stateful,
               Schedulable {

    private Boolean dryRun;
    private Datetime cutoffDate;
    private Datetime convertedCutoff;

    private Integer processed = 0;
    private Integer eligible = 0;
    private Integer deleted = 0;
    private Integer failed = 0;
    private Integer skipped = 0;

    private List<String> errors = new List<String>();

    public LeadCleanupBatch(Boolean dryRun) {
        this.dryRun = dryRun;
        this.cutoffDate = System.now().addDays(-90);
        this.convertedCutoff = System.now().addHours(-24);
    }

    public Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator([
            SELECT Id, CreatedDate, Status
            FROM Lead
            WHERE CreatedDate <= :cutoffDate
               OR Status = 'Completed'
        ]);
    }

    public void execute(Database.BatchableContext bc, List<SObject> scope) {

        if (scope.isEmpty()) return;

        processed += scope.size();

        Map<Id, Lead> leads = new Map<Id, Lead>();

        for (SObject record : scope) {
            Lead leadRecord = (Lead)record;
            leads.put(leadRecord.Id, leadRecord);
        }

        // Alla ansökningar kopplade till dessa Leads.
        Map<Id, Set<Id>> leadPersons = new Map<Id, Set<Id>>();
        Set<Id> personIds = new Set<Id>();
        Set<Id> leadsWithIncompleteLinks = new Set<Id>();

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
                leadsWithIncompleteLinks.add(app.Lead__c);
            }
        }

        // Medlemskap per person.
        Map<Id, List<Membership__c>> membershipsByPerson =
            new Map<Id, List<Membership__c>>();

        if (!personIds.isEmpty()) {
            for (Membership__c membership : [
                SELECT Id, Person__c, CreatedDate
                FROM Membership__c
                WHERE Person__c IN :personIds
            ]) {
                if (!membershipsByPerson.containsKey(
                    membership.Person__c
                )) {
                    membershipsByPerson.put(
                        membership.Person__c,
                        new List<Membership__c>()
                    );
                }

                membershipsByPerson.get(
                    membership.Person__c
                ).add(membership);
            }
        }

        List<Lead> toDelete = new List<Lead>();

        for (Lead leadRecord : leads.values()) {

            // Oklar koppling: behåll.
            if (leadsWithIncompleteLinks.contains(leadRecord.Id)) {
                skipped++;
                continue;
            }

            Set<Id> persons = leadPersons.get(leadRecord.Id);

            Boolean hasMembership = false;
            Boolean hasDifferentDayMembership = false;
            Boolean allMembershipsOldEnough = true;

            if (persons != null) {
                for (Id personId : persons) {

                    List<Membership__c> memberships =
                        membershipsByPerson.get(personId);

                    if (memberships == null) continue;

                    for (Membership__c membership : memberships) {

                        hasMembership = true;

                        // Samma kalenderdag i UTC.
                        if (
                            membership.CreatedDate.dateGmt() !=
                            leadRecord.CreatedDate.dateGmt()
                        ) {
                            hasDifferentDayMembership = true;
                        }

                        if (
                            membership.CreatedDate >
                            convertedCutoff
                        ) {
                            allMembershipsOldEnough = false;
                        }
                    }
                }
            }

            Boolean shouldDelete = false;

            if (hasMembership) {

                // Endast medlemskap skapade samma dag.
                // Minst 24 timmar måste ha passerat.
                shouldDelete =
                    !hasDifferentDayMembership &&
                    allMembershipsOldEnough;

            } else {

                // Saknar medlemskap: 90 dagar.
                shouldDelete =
                    leadRecord.CreatedDate <= cutoffDate;
            }

            if (shouldDelete) {
                eligible++;
                toDelete.add(leadRecord);
            } else {
                skipped++;
            }
        }

        if (toDelete.isEmpty()) return;

        if (dryRun) {
            System.debug(
                LoggingLevel.INFO,
                'LEAD CLEANUP DRY-RUN: ' +
                toDelete.size() + ' Leads eligible.'
            );
            return;
        }

        Database.DeleteResult[] results =
            Database.delete(toDelete, false);

        for (Integer i = 0; i < results.size(); i++) {

            if (results[i].isSuccess()) {
                deleted++;
            } else {
                failed++;

                for (Database.Error err : results[i].getErrors()) {

                    String message =
                        'Lead Id=' + toDelete[i].Id +
                        ' Error=' + err.getMessage();

                    if (errors.size() < 100) {
                        errors.add(message);
                    }

                    System.debug(LoggingLevel.ERROR, message);
                }
            }
        }
    }

    public void finish(Database.BatchableContext bc) {

        System.debug(
            LoggingLevel.INFO,
            'LEAD CLEANUP FINISHED' +
            ' | DryRun=' + dryRun +
            ' | Cutoff=' + cutoffDate +
            ' | ConvertedCutoff=' + convertedCutoff +
            ' | Processed=' + processed +
            ' | Eligible=' + eligible +
            ' | Deleted=' + deleted +
            ' | Failed=' + failed +
            ' | Skipped=' + skipped
        );

        for (String message : errors) {
            System.debug(LoggingLevel.ERROR, message);
        }
    }

    public void execute(SchedulableContext sc) {
        Database.executeBatch(
            new LeadCleanupBatch(false),
            100
        );
    }
}
