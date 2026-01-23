public with sharing class EmailAttachmentBackfillBatch
    implements Database.Batchable<SObject>, Database.Stateful {

    private Integer totalEmailsProcessed = 0;
    private Integer totalEmailCdlsProcessed = 0;
    private Integer totalCaseLinksCreated = 0;
    private Integer totalSkippedNoCase = 0;
    private Integer totalSkippedAlreadyLinked = 0;
    private Integer totalErrors = 0;

    public Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator([
            SELECT Id, ParentId, RelatedToId
            FROM EmailMessage
            WHERE (ParentId != null OR RelatedToId != null)
        ]);
    }

    public void execute(Database.BatchableContext bc, List<EmailMessage> scope) {
        if (scope == null || scope.isEmpty()) return;

        totalEmailsProcessed += scope.size();

        Map<Id, Id> emailToCase = new Map<Id, Id>();
        Set<Id> emailIds = new Set<Id>();

        for (EmailMessage em : scope) {
            emailIds.add(em.Id);

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
            totalSkippedNoCase += scope.size();
            return;
        }

        List<ContentDocumentLink> emailCdls = [
            SELECT Id, ContentDocumentId, LinkedEntityId
            FROM ContentDocumentLink
            WHERE LinkedEntityId IN :emailToCase.keySet()
        ];

        if (emailCdls.isEmpty()) return;

        totalEmailCdlsProcessed += emailCdls.size();

        Set<Id> contentDocIds = new Set<Id>();
        Set<Id> caseIds = new Set<Id>(emailToCase.values());

        for (ContentDocumentLink cdl : emailCdls) {
            if (cdl.ContentDocumentId != null) contentDocIds.add(cdl.ContentDocumentId);
        }

        if (contentDocIds.isEmpty() || caseIds.isEmpty()) return;

        Set<String> existingKeys = new Set<String>();
        for (ContentDocumentLink existing : [
            SELECT ContentDocumentId, LinkedEntityId
            FROM ContentDocumentLink
            WHERE ContentDocumentId IN :contentDocIds
            AND LinkedEntityId IN :caseIds
        ]) {
            existingKeys.add(existing.ContentDocumentId + '_' + existing.LinkedEntityId);
        }

        List<ContentDocumentLink> toInsert = new List<ContentDocumentLink>();
        Set<String> processedKeys = new Set<String>();

        for (ContentDocumentLink cdl : emailCdls) {
            Id caseId = emailToCase.get(cdl.LinkedEntityId);
            if (caseId == null || cdl.ContentDocumentId == null) continue;

            String key = cdl.ContentDocumentId + '_' + caseId;
            if (existingKeys.contains(key) || processedKeys.contains(key)) {
                totalSkippedAlreadyLinked++;
                continue;
            }

            toInsert.add(new ContentDocumentLink(
                ContentDocumentId = cdl.ContentDocumentId,
                LinkedEntityId = caseId,
                ShareType = 'V',
                Visibility = 'AllUsers'
            ));
            processedKeys.add(key);
        }

        if (toInsert.isEmpty()) return;

        Database.SaveResult[] results = Database.insert(toInsert, false);

        Integer ok = 0, fail = 0;
        for (Database.SaveResult r : results) {
            if (r.isSuccess()) ok++;
            else fail++;
        }

        totalCaseLinksCreated += ok;
        totalErrors += fail;
    }

    public void finish(Database.BatchableContext bc) {
        System.debug(LoggingLevel.INFO,
            'EmailAttachmentBackfillBatch finished. ' +
            'Emails processed=' + totalEmailsProcessed +
            ', Email CDLs processed=' + totalEmailCdlsProcessed +
            ', Case links created=' + totalCaseLinksCreated +
            ', Skipped(already linked)=' + totalSkippedAlreadyLinked +
            ', Errors=' + totalErrors
        );
    }
}