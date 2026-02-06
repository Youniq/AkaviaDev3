/**
 * Handler class to link email attachment files to Case records.
 * When Files are linked to EmailMessage, this also links those Files to the related Case
 * so they show in Case Files / File Explorer.
 */
public with sharing class EmailAttachmentLinkHandler {

    // Recursion guard (avoids repeated work/log noise)
    private static Boolean isProcessing = false;

    /**
     * Inner class without sharing to ensure DML succeeds regardless of sharing rules.
     */
    private without sharing class LinkCreator {
        public Database.SaveResult[] createLinks(List<ContentDocumentLink> linksToCreate) {
            return Database.insert(linksToCreate, false);
        }

        /**
         * Converts Attachment records to Files (ContentVersion/ContentDocument).
         * Returns map AttachmentId -> ContentDocumentId for successful conversions.
         */
        public Map<Id, Id> convertAttachmentsToFiles(List<Attachment> attachments) {
            Map<Id, Id> attachmentToContentDocumentMap = new Map<Id, Id>();
            if (attachments == null || attachments.isEmpty()) return attachmentToContentDocumentMap;

            List<ContentVersion> cvs = new List<ContentVersion>();
            List<Attachment> validAtts = new List<Attachment>();

            for (Attachment att : attachments) {
                if (att == null) continue;

                if (att.Body == null) {
                    System.debug(LoggingLevel.WARN,
                        'EmailAttachmentLinkHandler: [SKIP] Attachment Body is null. AttachmentId=' + att.Id + ', Name=' + att.Name
                    );
                    continue;
                }

                ContentVersion cv = new ContentVersion();
                cv.Title = (att.Name != null) ? att.Name : 'Untitled';
                cv.PathOnClient = (att.Name != null) ? att.Name : 'Untitled';
                cv.VersionData = att.Body;
                cv.IsMajorVersion = true;
                cvs.add(cv);
                validAtts.add(att);
            }

            if (cvs.isEmpty()) return attachmentToContentDocumentMap;

            Database.SaveResult[] results = Database.insert(cvs, false);

            // keep index alignment even if some inserts fail
            List<Id> versionIdByIndex = new List<Id>();
            versionIdByIndex.addAll(new List<Id>(new Id[results.size()])); // pre-sized list of nulls

            for (Integer i = 0; i < results.size(); i++) {
                if (results[i].isSuccess()) {
                    versionIdByIndex[i] = results[i].getId();
                } else {
                    String msg = 'EmailAttachmentLinkHandler: Failed converting AttachmentId=' + validAtts[i].Id + ', Name=' + validAtts[i].Name;
                    for (Database.Error err : results[i].getErrors()) {
                        msg += ' | ' + err.getStatusCode() + ': ' + err.getMessage();
                    }
                    System.debug(LoggingLevel.ERROR, msg);
                }
            }

            Set<Id> versionIds = new Set<Id>();
            for (Id vid : versionIdByIndex) if (vid != null) versionIds.add(vid);

            if (versionIds.isEmpty()) return attachmentToContentDocumentMap;

            Map<Id, ContentVersion> cvMap = new Map<Id, ContentVersion>([
                SELECT Id, ContentDocumentId
                FROM ContentVersion
                WHERE Id IN :versionIds
            ]);

            for (Integer i = 0; i < validAtts.size(); i++) {
                Id vid = versionIdByIndex[i];
                if (vid == null) continue;

                ContentVersion insertedCv = cvMap.get(vid);
                if (insertedCv != null && insertedCv.ContentDocumentId != null) {
                    attachmentToContentDocumentMap.put(validAtts[i].Id, insertedCv.ContentDocumentId);
                }
            }

            return attachmentToContentDocumentMap;
        }
    }

    // Defaults
    private static final String DEFAULT_SHARE_TYPE = 'V';
    private static final String DEFAULT_VISIBILITY = 'AllUsers';

    private static Boolean isCaseId(Id idVal) {
        return idVal != null && idVal.getSObjectType() == Case.SObjectType;
    }

    private static ContentDocumentLink buildContentDocumentLink(Id contentDocumentId, Id linkedEntityId) {
        ContentDocumentLink link = new ContentDocumentLink();
        link.ContentDocumentId = contentDocumentId;
        link.LinkedEntityId = linkedEntityId;
        link.ShareType = DEFAULT_SHARE_TYPE;
        link.Visibility = DEFAULT_VISIBILITY;
        return link;
    }

    private static Set<String> getExistingLinkKeys(Set<Id> contentDocumentIds, Set<Id> linkedEntityIds) {
        Set<String> existingLinks = new Set<String>();
        if (contentDocumentIds == null || contentDocumentIds.isEmpty()) return existingLinks;
        if (linkedEntityIds == null || linkedEntityIds.isEmpty()) return existingLinks;

        for (ContentDocumentLink existing : [
            SELECT ContentDocumentId, LinkedEntityId
            FROM ContentDocumentLink
            WHERE ContentDocumentId IN :contentDocumentIds
            AND LinkedEntityId IN :linkedEntityIds
        ]) {
            existingLinks.add(existing.ContentDocumentId + '_' + existing.LinkedEntityId);
        }
        return existingLinks;
    }

    private static Map<Id, Id> queryEmailMessageToCaseMap(Set<Id> emailMessageIds) {
        Map<Id, Id> emailMessageToCaseMap = new Map<Id, Id>();
        if (emailMessageIds == null || emailMessageIds.isEmpty()) return emailMessageToCaseMap;

        for (EmailMessage em : [
            SELECT Id, ParentId, RelatedToId
            FROM EmailMessage
            WHERE Id IN :emailMessageIds
        ]) {
            // Prefer ParentId, else RelatedToId
            Id candidate = (em.ParentId != null) ? em.ParentId : em.RelatedToId;
            if (isCaseId(candidate)) {
                emailMessageToCaseMap.put(em.Id, candidate);
            }
        }
        return emailMessageToCaseMap;
    }

    private static void logInsertResults(List<ContentDocumentLink> links, Database.SaveResult[] results, String summaryPrefix) {
        Integer ok = 0, fail = 0;

        for (Integer i = 0; i < results.size(); i++) {
            if (results[i].isSuccess()) {
                ok++;
            } else {
                fail++;
                String msg = 'EmailAttachmentLinkHandler: Failed to create CDL: ContentDocumentId='
                    + links[i].ContentDocumentId + ' LinkedEntityId=' + links[i].LinkedEntityId;
                for (Database.Error err : results[i].getErrors()) {
                    msg += ' | ' + err.getStatusCode() + ': ' + err.getMessage();
                }
                System.debug(LoggingLevel.ERROR, msg);
            }
        }

        System.debug(LoggingLevel.INFO, summaryPrefix + ' Success=' + ok + ', Fail=' + fail);
    }

    /**
     * When a File is linked to EmailMessage, also link same File to related Case.
     */
    public static void linkEmailFilesToCases(List<ContentDocumentLink> contentDocumentLinks) {
        if (contentDocumentLinks == null || contentDocumentLinks.isEmpty()) return;

        if (isProcessing) return;
        isProcessing = true;
        try {
            // Collect EmailMessage IDs + ContentDocument IDs
            Set<Id> emailMessageIds = new Set<Id>();
            Set<Id> contentDocumentIds = new Set<Id>();

            for (ContentDocumentLink cdl : contentDocumentLinks) {
                if (cdl == null || cdl.LinkedEntityId == null || cdl.ContentDocumentId == null) continue;

                if (cdl.LinkedEntityId.getSObjectType() == EmailMessage.SObjectType) {
                    emailMessageIds.add(cdl.LinkedEntityId);
                    contentDocumentIds.add(cdl.ContentDocumentId);
                }
            }

            if (emailMessageIds.isEmpty() || contentDocumentIds.isEmpty()) return;

            // EmailMessage -> Case
            Map<Id, Id> emailMessageToCase = queryEmailMessageToCaseMap(emailMessageIds);
            if (emailMessageToCase.isEmpty()) return;

            Set<Id> caseIds = new Set<Id>(emailMessageToCase.values());

            // Avoid duplicates: check existing links for (doc -> case)
            Set<String> existingKeys = getExistingLinkKeys(contentDocumentIds, caseIds);

            // Create missing (doc -> case) links
            List<ContentDocumentLink> toInsert = new List<ContentDocumentLink>();
            Set<String> processedInThisTxn = new Set<String>();

            for (ContentDocumentLink cdl : contentDocumentLinks) {
                if (cdl == null || cdl.LinkedEntityId == null || cdl.ContentDocumentId == null) continue;
                if (cdl.LinkedEntityId.getSObjectType() != EmailMessage.SObjectType) continue;

                Id emId = cdl.LinkedEntityId;
                Id caseId = emailMessageToCase.get(emId);
                if (caseId == null) continue;

                String key = cdl.ContentDocumentId + '_' + caseId;
                if (existingKeys.contains(key) || processedInThisTxn.contains(key)) continue;

                toInsert.add(buildContentDocumentLink(cdl.ContentDocumentId, caseId));
                processedInThisTxn.add(key);
            }

            if (toInsert.isEmpty()) return;

            LinkCreator lc = new LinkCreator();
            Database.SaveResult[] res = lc.createLinks(toInsert);
            logInsertResults(toInsert, res, 'EmailAttachmentLinkHandler: Link Files->Case completed.');
        } finally {
            isProcessing = false;
        }
    }

    /**
     * if legacy Attachment records on EmailMessage is found, convert to File and link to Case as well.
     */
    public static void linkEmailAttachmentsToCases(List<Attachment> attachments) {
        if (attachments == null || attachments.isEmpty()) return;

        // Group attachments per EmailMessage (support multiple attachments per email)
        Map<Id, List<Attachment>> emailToAtts = new Map<Id, List<Attachment>>();
        Set<Id> emailMessageIds = new Set<Id>();

        for (Attachment att : attachments) {
            if (att == null || att.ParentId == null) continue;
            if (att.ParentId.getSObjectType() != EmailMessage.SObjectType) continue;

            emailMessageIds.add(att.ParentId);
            if (!emailToAtts.containsKey(att.ParentId)) emailToAtts.put(att.ParentId, new List<Attachment>());
            emailToAtts.get(att.ParentId).add(att);
        }

        if (emailMessageIds.isEmpty()) return;

        Map<Id, Id> emailToCase = queryEmailMessageToCaseMap(emailMessageIds);
        if (emailToCase.isEmpty()) return;

        // Convert attachments to files
        List<Attachment> allAtts = new List<Attachment>();
        for (Id emId : emailToAtts.keySet()) allAtts.addAll(emailToAtts.get(emId));

        LinkCreator lc = new LinkCreator();
        Map<Id, Id> attToDoc = lc.convertAttachmentsToFiles(allAtts);
        if (attToDoc.isEmpty()) return;

        // Create links to EmailMessage + Case (if missing)
        Set<Id> docIds = new Set<Id>(attToDoc.values());
        Set<Id> caseIds = new Set<Id>(emailToCase.values());

        Set<Id> linkedEntities = new Set<Id>();
        linkedEntities.addAll(emailMessageIds);
        linkedEntities.addAll(caseIds);

        Set<String> existingKeys = getExistingLinkKeys(docIds, linkedEntities);

        List<ContentDocumentLink> toInsert = new List<ContentDocumentLink>();
        Set<String> processed = new Set<String>();

        for (Id emId : emailToAtts.keySet()) {
            Id caseId = emailToCase.get(emId);
            if (caseId == null) continue;

            for (Attachment att : emailToAtts.get(emId)) {
                Id docId = attToDoc.get(att.Id);
                if (docId == null) continue;

                // link doc -> EmailMessage
                String k1 = docId + '_' + emId;
                if (!existingKeys.contains(k1) && !processed.contains(k1)) {
                    toInsert.add(buildContentDocumentLink(docId, emId));
                    processed.add(k1);
                }

                // link doc -> Case
                String k2 = docId + '_' + caseId;
                if (!existingKeys.contains(k2) && !processed.contains(k2)) {
                    toInsert.add(buildContentDocumentLink(docId, caseId));
                    processed.add(k2);
                }
            }
        }

        if (toInsert.isEmpty()) return;

        Database.SaveResult[] res = lc.createLinks(toInsert);
        logInsertResults(toInsert, res, 'EmailAttachmentLinkHandler: Attachment->File linking completed.');
    }
}