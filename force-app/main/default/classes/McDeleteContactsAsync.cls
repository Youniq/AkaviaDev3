
/**
 * @description       : Deletes contacts from Marketing Cloud.
 *                      Supports existing Person Account deletion
 *                      and GDPR Lead deletion through GDPR_Deletion_Queue__c.
 * @author            : Malin Nilsson (Stretch Customer AB)
 * @last modified on  : 2026-11-20
 */
public with sharing class McDeleteContactsAsync
    implements Queueable, Database.AllowsCallouts {

    private static final String ENDPOINT =
        '/contacts/v1/contacts/actions/delete?type=keys';

    private static final String BASE_URL =
        'callout:MarketingCloudInteg';

    private Id singleAccToDelete;
    private Boolean processGdprQueue = false;

    // Existing scheduled Person Account deletion
    public McDeleteContactsAsync() {
    }

    // Existing single Person Account deletion
    public McDeleteContactsAsync(Id accId) {
        this.singleAccToDelete = accId;
    }

    // New GDPR Lead deletion
    public McDeleteContactsAsync(Boolean processGdprQueue) {
        this.processGdprQueue = processGdprQueue == true;
    }

    public void execute(QueueableContext context) {

        // Callout__c is created by the caller using the Queueable JobId.
        Callout__c currCallout = [
            SELECT Id,
                   Status__c,
                   Request__c,
                   Response__c,
                   Path__c,
                   Code__c,
                   ErrorLog__c
            FROM Callout__c
            WHERE JobId__c = :context.getJobId()
            LIMIT 1
        ];

        try {

            if (processGdprQueue) {

                deleteGdprContacts(currCallout);

            } else {

                deleteAccountContacts(currCallout);
            }

        } catch (Exception e) {

            currCallout.Status__c = 'Failed';
            currCallout.ErrorLog__c =
                e.getMessage() + '\n\n' +
                e.getStackTraceString();

            System.debug(
                LoggingLevel.ERROR,
                'Marketing Cloud delete error: ' +
                e.getMessage()
            );

        } finally {

            update currCallout;
        }
    }

    // ============================================================
    // EXISTING PERSON ACCOUNT DELETION
    // ============================================================

    private void deleteAccountContacts(
        Callout__c currCallout
    ) {

        List<Account> toMcDelete;

        if (singleAccToDelete != null) {

            // Delete a single Person Account
            toMcDelete = [
                SELECT Id,
                       ContactCaseSafeID__c,
                       DeletedFromMc__c,
                       SyncWithMc__c
                FROM Account
                WHERE IsPersonAccount = true
                AND Id = :singleAccToDelete
            ];

        } else {

            // Existing scheduled deletion
            Integer deleteLimit = getContactDeleteLimit();

            Date sixMonthsAgo =
                Date.today().addMonths(-6);

            if (Test.isRunningTest()) {

                toMcDelete = [
                    SELECT Id,
                           ContactCaseSafeID__c,
                           DeletedFromMc__c,
                           SyncWithMc__c
                    FROM Account
                    WHERE IsPersonAccount = true
                    AND SyncWithMc__c = false
                    AND DeletedFromMc__c = false
                    LIMIT :deleteLimit
                ];

            } else {

                toMcDelete = [
                    SELECT Id,
                           ContactCaseSafeID__c,
                           DeletedFromMc__c,
                           SyncWithMc__c
                    FROM Account
                    WHERE IsPersonAccount = true
                    AND SyncWithMc__c = false
                    AND MemberPhase__c = 'Avslutad'
                    AND (
                        MembershipStatus__c = 'Avliden'
                        OR CancellationDate__c < :sixMonthsAgo
                    )
                    AND DeletedFromMc__c = false
                    LIMIT :deleteLimit
                ];
            }
        }

        List<String> mcKeysToDelete =
            new List<String>();

        for (Account a : toMcDelete) {

            // Existing Contact Key for Person Accounts
            mcKeysToDelete.add(
                a.ContactCaseSafeID__c
            );
        }

        // Preserve existing Account deletion behavior
        DeleteByKeyRequest reqData =
            new DeleteByKeyRequest();

        reqData.values = mcKeysToDelete;
        reqData.DeleteOperationType =
            'ContactAndAttributes';

        Boolean success = sendDeleteRequest(
            reqData,
            currCallout
        );

        if (success) {
            setSfAccountMcDeleted(toMcDelete);
        }
    }

    // ============================================================
    // NEW GDPR LEAD DELETION
    // ============================================================

    private void deleteGdprContacts(
        Callout__c currCallout
    ) {

        Integer deleteLimit =
            getContactDeleteLimit();

        // Only process records explicitly approved for MC deletion.
        // DryRun records are excluded.
        List<GDPR_Deletion_Queue__c> queueRecords = [
            SELECT Id,
                   LeadId__c,
                   Email__c,
                   MarketingCloudStatus__c,
                   DeleteFromMarketingCloud__c,
                   ErrorMessage__c
            FROM GDPR_Deletion_Queue__c
            WHERE DeleteFromMarketingCloud__c = true
            AND MarketingCloudStatus__c = 'Pending'
            AND LeadId__c != null
            ORDER BY CreatedDate ASC
            LIMIT :deleteLimit
        ];

        if (queueRecords.isEmpty()) {

            currCallout.Status__c = 'OK';

            System.debug(
                LoggingLevel.INFO,
                'No pending GDPR contacts to delete.'
            );

            return;
        }

        List<String> mcKeysToDelete =
            new List<String>();

        Set<String> uniqueKeys =
            new Set<String>();

        for (GDPR_Deletion_Queue__c record : queueRecords) {

            String leadId = record.LeadId__c;

            if (
                String.isNotBlank(leadId) &&
                !uniqueKeys.contains(leadId)
            ) {

                // First version:
                // Salesforce Lead.Id = Marketing Cloud Contact Key
                mcKeysToDelete.add(leadId);

                uniqueKeys.add(leadId);
            }
        }

        if (mcKeysToDelete.isEmpty()) {

            currCallout.Status__c = 'OK';
            return;
        }

        DeleteByKeyRequest reqData =
            new DeleteByKeyRequest();

        reqData.values = mcKeysToDelete;
        reqData.DeleteOperationType =
            'ContactAndAttributes';

        Boolean success = sendDeleteRequest(
            reqData,
            currCallout
        );

        List<GDPR_Deletion_Queue__c> updates =
            new List<GDPR_Deletion_Queue__c>();

        for (GDPR_Deletion_Queue__c record : queueRecords) {

            GDPR_Deletion_Queue__c updateRecord =
                new GDPR_Deletion_Queue__c(
                    Id = record.Id
                );

            if (success) {

                // MC Contact Delete is asynchronous.
                // Submitted does not mean deletion is completed.
                updateRecord.MarketingCloudStatus__c =
                    'Submitted';

            } else {

                updateRecord.MarketingCloudStatus__c =
                    'Failed';

                updateRecord.ErrorMessage__c =
                    'Marketing Cloud delete request failed. ' +
                    'See Callout__c: ' +
                    currCallout.Id;
            }

            updates.add(updateRecord);
        }

        if (!updates.isEmpty()) {
            update updates;
        }

        System.debug(
            LoggingLevel.INFO,
            'GDPR Marketing Cloud deletion submitted. ' +
            'Contacts: ' + mcKeysToDelete.size() +
            ', Success: ' + success
        );
    }

    // ============================================================
    // SHARED MARKETING CLOUD API
    // ============================================================

    private Boolean sendDeleteRequest(
        DeleteByKeyRequest reqData,
        Callout__c currCallout
    ) {

        Http http = new Http();
        HttpRequest req = new HttpRequest();

        req.setMethod('POST');

        req.setEndpoint(
            BASE_URL + ENDPOINT
        );

        req.setHeader(
            GlobalConstants.HTTP_HEADER_FIELD_NAME_CONTENT_TYPE,
            GlobalConstants.HTTP_HEADER_FIELD_CONTENT_TYPE_VALUE_APPLICATION_JSON
        );

        String bodyAsString =
            reqData.toJson();

        req.setBodyAsBlob(
            Blob.valueOf(bodyAsString)
        );

        req.setTimeout(120000);

        currCallout.Request__c =
            bodyAsString;

        currCallout.Path__c =
            req.getEndpoint();

        HttpResponse res =
            http.send(req);

        currCallout.Response__c =
            res.getBody();

        currCallout.Code__c =
            String.valueOf(res.getStatusCode());

        Integer statusCode =
            res.getStatusCode();

        if (
            statusCode == 200 ||
            statusCode == 201 ||
            statusCode == 202
        ) {

            currCallout.Status__c = 'OK';

            System.debug(
                LoggingLevel.INFO,
                'Marketing Cloud delete request accepted: ' +
                res.getBody()
            );

        } else {

            currCallout.Status__c = 'Failed';

            System.debug(
                LoggingLevel.ERROR,
                'Marketing Cloud delete request failed: ' +
                res.getBody()
            );
        }

        return currCallout.Status__c == 'OK';
    }

    // ============================================================
    // EXISTING ACCOUNT STATUS UPDATE
    // ============================================================

    private void setSfAccountMcDeleted(
        List<Account> accounts
    ) {

        for (Account a : accounts) {
            a.DeletedFromMc__c = true;
        }

        update accounts;
    }

    // ============================================================
    // EXISTING CONTACT DELETE LIMIT
    // ============================================================

    private Integer getContactDeleteLimit() {

        McSetting__c setting =
            McSetting__c.getOrgDefaults();

        if (setting == null) {

            throw new IllegalArgumentException(
                'Custom Settings McSetting__c not set. ' +
                'Aborting job.'
            );

        } else if (
            setting.ContactDeleteLimit__c == null ||
            setting.ContactDeleteLimit__c <= 0
        ) {

            throw new IllegalArgumentException(
                'McSetting__c.ContactDeleteLimit__c ' +
                'must have a positive value. Aborting job.'
            );

        } else {

            System.debug(
                LoggingLevel.DEBUG,
                'contactDeleteLimit: ' +
                (Integer)setting.ContactDeleteLimit__c
            );

            return (Integer)setting.ContactDeleteLimit__c;
        }
    }

    // ============================================================
    // REQUEST MODEL
    // ============================================================

    private class DeleteByKeyRequest {

        public List<String> values;
        public String DeleteOperationType;

        public String toJson() {
            return JSON.serialize(this);
        }
    }
}
