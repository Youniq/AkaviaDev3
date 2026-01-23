/**
 * Files-only backfill:
 * Links existing Salesforce Files that are currently linked to EmailMessage
 * to the related Case (so they appear in Case Files / File Explorer).
 *
 * Why Files-only?
 * - This solves: "File Explorer visar inte filer för Email Message"
 * - Attachments (legacy) are a separate concern and should be handled separately if needed.
 *
 * Key improvements vs your current batch:
 * - Does NOT rely on EmailMessage.HasAttachment (often misses Files)
 * - Starts from ContentDocumentLink (the truth source for Files)
 * - Idempotent: avoids duplicates both vs database AND within the same execute
 * - Minimal queries per execute
 */
public with sharing class EmailFileToCaseBackfillBatch
    implements Database.Batchable<SObject>, Database.Stateful {

    // Stats (optional)
    private Integer totalCdlsProcessed = 0;
    private Integer totalCaseLinksCreated = 0;
    private Integer totalSkippedNoCase = 0;
    private Integer totalSkippedAlreadyLinked = 0;
    private Integer totalErrors = 0;

    public Database.QueryLocator start(Database.BatchableContext bc) {
        // We query ALL ContentDocumentLinks, and filter to EmailMessage in execute() using getSObjectType().
        // This avoids relying on Id prefixes (02s), and avoids HasAttachment issues.
        //
        // NOTE: If your org is extremely large and you want to reduce scan:
        // - You can add CreatedDate filters here.
        return Database.getQueryLocator([
            SELECT Id, ContentDocumentId, LinkedEntityId
            FROM ContentDocumentLink
            WHERE LinkedEntityId != null
            AND ContentDocumentId != null
        ]);
    }

    public void execute(Database.BatchableContext bc, List<ContentDocumentLink> scope) {
        if (scope == null || scope.isEmpty()) return;

        // 1) Keep only links where LinkedEntityId is EmailMessage
        Set<Id> emailMessageIds = new Set<Id>();
        List<ContentDocumentLink> emailCdls = new List<ContentDocumentLink>();

        for (ContentDocumentLink cdl : scope) {
            if (cdl == null || cdl.LinkedEntityId == null || cdl.ContentDocumentId == null) continue;

            // Safe type check (no prefix assumptions)
            if (cdl.LinkedEntityId.getSObjectType() == EmailMessage.SObjectType) {
                emailMessageIds.add(cdl.LinkedEntityId);
                emailCdls.add(cdl);
            }
        }

        if (emailCdls.isEmpty()) return;

        totalCdlsProcessed += emailCdls.size();

        // 2) Query EmailMessages to find related Case
        Map<Id, Id> emailToCase = new Map<Id, Id>();
        for (EmailMessage em : [
            SELECT Id, ParentId, RelatedToId
            FROM EmailMessage
            WHERE Id IN :emailMessageIds
        ]) {
            Id caseId = null;

            if (em.ParentId != null && em.ParentId.getSObjectType() == Case.SObjectType) {
                caseId = em.ParentId;
            } else if (em.RelatedToId != null && em.RelatedToId.getSObjectType() == Case.SObjectType) {
                caseId = em.RelatedToId;
            }

            if (caseId != null) {
                emailToCase.put(em.Id, caseId);
            }
        }

        if (emailToCase.isEmpty()) {
            totalSkippedNoCase += emailCdls.size();
            return;
        }

        // 3) Build sets for dedupe query
        Set<Id> contentDocIds = new Set<Id>();
        Set<Id> caseIds = new Set<Id>();

        for (ContentDocumentLink cdl : emailCdls) {
            Id caseId = emailToCase.get(cdl.LinkedEntityId);
            if (caseId == null) continue;

            contentDocIds.add(cdl.ContentDocumentId);
            caseIds.add(caseId);
        }

        if (contentDocIds.isEmpty() || caseIds.isEmpty()) return;

        // 4) Query existing doc->case links to avoid duplicates
        Set<String> existingKeys = new Set<String>();
        for (ContentDocumentLink existing : [
            SELECT ContentDocumentId, LinkedEntityId
            FROM ContentDocumentLink
            WHERE ContentDocumentId IN :contentDocIds
            AND LinkedEntityId IN :caseIds
        ]) {
            existingKeys.add(existing.ContentDocumentId + '_' + existing.LinkedEntityId);
        }

        // 5) Create missing links (also dedupe inside this execute)
        List<ContentDocumentLink> toInsert = new List<ContentDocumentLink>();
        Set<String> processedKeys = new Set<String>();

        for (ContentDocumentLink cdl : emailCdls) {
            Id caseId = emailToCase.get(cdl.LinkedEntityId);
            if (caseId == null) {
                totalSkippedNoCase++;
                continue;
            }

            String key = cdl.ContentDocumentId + '_' + caseId;
            if (existingKeys.contains(key) || processedKeys.contains(key)) {
                totalSkippedAlreadyLinked++;
                continue;
            }

            ContentDocumentLink newLink = new ContentDocumentLink();
            newLink.ContentDocumentId = cdl.ContentDocumentId;
            newLink.LinkedEntityId = caseId;
            newLink.ShareType = 'V';
            newLink.Visibility = 'AllUsers';

            toInsert.add(newLink);
            processedKeys.add(key);
        }

        if (toInsert.isEmpty()) return;

        // 6) Insert with partial success
        Database.SaveResult[] results = Database.insert(toInsert, false);

        Integer ok = 0;
        Integer fail = 0;

        for (Database.SaveResult r : results) {
            if (r.isSuccess()) ok++;
            else fail++;
        }

        totalCaseLinksCreated += ok;
        totalErrors += fail;
    }

    public void finish(Database.BatchableContext bc) {
        System.debug(LoggingLevel.INFO,
            'EmailFileToCaseBackfillBatch finished. ' +
            'Processed EmailMessage CDLs=' + totalCdlsProcessed +
            ', Case links created=' + totalCaseLinksCreated +
            ', Skipped(no case)=' + totalSkippedNoCase +
            ', Skipped(already linked)=' + totalSkippedAlreadyLinked +
            ', Errors=' + totalErrors
        );
    }
}
