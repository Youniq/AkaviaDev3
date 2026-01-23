/**
 * Handler class to link email attachment files to Case records
 * When files are attached to EmailMessage records, this ensures they're also linked to the related Case
 */
public with sharing class EmailAttachmentLinkHandler {
    
    // Static flag to prevent recursive trigger calls
   // private static Boolean isProcessing = false;
    
    /**
     * Inner class without sharing to ensure DML operations succeed regardless of sharing rules
     * This is especially important for batch operations
     */
    private without sharing class LinkCreator {
        public Database.SaveResult[] createLinks(List<ContentDocumentLink> linksToCreate) {
            return Database.insert(linksToCreate, false);
        }
        
        /**
         * Converts Attachment records to Files (ContentVersion/ContentDocument) and links them to Cases
         */
        public Map<Id, Id> convertAttachmentsToFiles(List<Attachment> attachments, Map<Id, Id> emailMessageToCaseMap) {
            Map<Id, Id> attachmentToContentDocumentMap = new Map<Id, Id>();
            
            if (attachments == null || attachments.isEmpty()) {
                return attachmentToContentDocumentMap;
            }
            
            List<ContentVersion> contentVersionsToCreate = new List<ContentVersion>();
            List<Attachment> validAttachments = new List<Attachment>(); // Parallel list to track mapping
            
            // Step 1: Create ContentVersion records from Attachments
            for (Attachment att : attachments) {
                // Skip if Body is null (can happen with some attachment types)
                if (att.Body == null) {
                    System.debug(LoggingLevel.WARN, 'EmailAttachmentLinkHandler: [SKIP] Cannot convert Attachment - ' + 
                        'Attachment: ' + att.Id + ' (' + att.Name + ') - Body is null (file content missing)');
                    continue;
                }
                
                ContentVersion cv = new ContentVersion();
                cv.Title = att.Name != null ? att.Name : 'Untitled';
                cv.PathOnClient = att.Name != null ? att.Name : 'Untitled';
                cv.VersionData = att.Body; // The actual file content
                cv.FirstPublishLocationId = null; // We'll link it manually
                cv.IsMajorVersion = true;
                contentVersionsToCreate.add(cv);
                validAttachments.add(att); // Track which attachment this corresponds to
            }
            
            if (contentVersionsToCreate.isEmpty()) {
                System.debug(LoggingLevel.WARN, 'EmailAttachmentLinkHandler: [SKIP] No valid Attachments to convert - all have null Body');
                return attachmentToContentDocumentMap;
            }
            
            // Insert ContentVersions (this automatically creates ContentDocuments)
            Database.SaveResult[] cvResults = Database.insert(contentVersionsToCreate, false);
            
            // Step 2: Query back to get the ContentDocumentIds
            List<Id> contentVersionIds = new List<Id>();
            
            for (Integer i = 0; i < cvResults.size(); i++) {
                if (cvResults[i].isSuccess()) {
                    contentVersionIds.add(cvResults[i].getId());
                } else {
                    // Log error
                    Attachment att = validAttachments[i];
                    String errorMsg = 'EmailAttachmentLinkHandler: Failed to convert Attachment ' + 
                        att.Id + ' (' + att.Name + ')';
                    for (Database.Error err : cvResults[i].getErrors()) {
                        errorMsg += ' - Error: ' + err.getMessage() + ' (' + err.getStatusCode() + ')';
                    }
                    System.debug(LoggingLevel.ERROR, errorMsg);
                }
            }
            
            if (!contentVersionIds.isEmpty()) {
                // Query ContentVersions to get ContentDocumentIds
                Map<Id, ContentVersion> contentVersionMap = new Map<Id, ContentVersion>([
                    SELECT Id, ContentDocumentId, Title
                    FROM ContentVersion
                    WHERE Id IN :contentVersionIds
                ]);
                
                // Map Attachment to ContentDocument (using parallel lists)
                Integer cvIndex = 0;
                for (Integer i = 0; i < validAttachments.size(); i++) {
                    Attachment att = validAttachments[i];
                    if (cvIndex < cvResults.size() && cvResults[cvIndex].isSuccess()) {
                        Id contentVersionId = contentVersionIds[cvIndex];
                        ContentVersion cv = contentVersionMap.get(contentVersionId);
                        if (cv != null && cv.ContentDocumentId != null) {
                            attachmentToContentDocumentMap.put(att.Id, cv.ContentDocumentId);
                            System.debug(LoggingLevel.INFO, 'EmailAttachmentLinkHandler: [CONVERT] Successfully converted Attachment to File - ' +
                                'Attachment: ' + att.Id + ' (' + att.Name + ') -> ContentDocument: ' + cv.ContentDocumentId);
                        }
                        cvIndex++;
                    } else if (cvIndex < cvResults.size()) {
                        // Skip failed conversion
                        cvIndex++;
                    }
                }
            }
            
            return attachmentToContentDocumentMap;
        }
    }

    /**
     * Checks if the provided Id is a Case Id.
     */
    private static Boolean isCaseId(Id caseId) {
        if (caseId == null) {
            return false;
        }
        String caseIdStr = String.valueOf(caseId);
        return caseIdStr.startsWith('500') && String.valueOf(caseId.getSObjectType()) == 'Case';
    }

    /**
     * Queries EmailMessages and returns a map of EmailMessageId -> CaseId.
     * @param emailMessageIds EmailMessage Ids to query
     * @param logDetails If true, logs Parent/RelatedTo information and warnings
     */
    private static Map<Id, Id> queryEmailMessageToCaseMap(Set<Id> emailMessageIds, Boolean logDetails) {
        Map<Id, Id> emailMessageToCaseMap = new Map<Id, Id>();
        if (emailMessageIds == null || emailMessageIds.isEmpty()) {
            return emailMessageToCaseMap;
        }

        for (EmailMessage em : [
            SELECT Id, ParentId, RelatedToId
            FROM EmailMessage
            WHERE Id IN :emailMessageIds
            AND (ParentId != null OR RelatedToId != null)
        ]) {
            Id caseId = em.ParentId != null ? em.ParentId : em.RelatedToId;

            if (logDetails) {
                String parentType = em.ParentId != null ? String.valueOf(em.ParentId.getSObjectType()) : 'null';
                String relatedToType = em.RelatedToId != null ? String.valueOf(em.RelatedToId.getSObjectType()) : 'null';

                System.debug(LoggingLevel.INFO, 'EmailAttachmentLinkHandler: EmailMessage ' + em.Id +
                    ' - ParentId: ' + em.ParentId + ' (Type: ' + parentType + ')' +
                    ', RelatedToId: ' + em.RelatedToId + ' (Type: ' + relatedToType + ')');
            }

            if (isCaseId(caseId)) {
                emailMessageToCaseMap.put(em.Id, caseId);
                if (logDetails) {
                    System.debug(LoggingLevel.INFO, 'EmailAttachmentLinkHandler: EmailMessage ' + em.Id +
                        ' belongs to Case: ' + caseId + ' - Will link files from this email to this Case');
                }
            } else if (logDetails) {
                System.debug(LoggingLevel.WARN, 'EmailAttachmentLinkHandler: EmailMessage ' + em.Id +
                    ' does not have a Case parent. CaseId: ' + caseId +
                    ' (Type: ' + (caseId != null ? String.valueOf(caseId.getSObjectType()) : 'null') +
                    ', Prefix: ' + (caseId != null ? String.valueOf(caseId).substring(0, 3) : 'null') + ') - Cannot link files');
            }
        }
        return emailMessageToCaseMap;
    }

    /**
     * Filters a provided EmailMessage->Case map to only include valid Case Ids.
     * @param emailMessageIds EmailMessage Ids to include
     * @param emailMessageToCaseMap Map to filter
     */
    private static Map<Id, Id> filterEmailMessageToCaseMap(Set<Id> emailMessageIds, Map<Id, Id> emailMessageToCaseMap) {
        Map<Id, Id> filteredMap = new Map<Id, Id>();
        if (emailMessageIds == null || emailMessageIds.isEmpty() || emailMessageToCaseMap == null) {
            return filteredMap;
        }
        for (Id emailMessageId : emailMessageIds) {
            if (emailMessageToCaseMap.containsKey(emailMessageId)) {
                Id caseId = emailMessageToCaseMap.get(emailMessageId);
                if (isCaseId(caseId)) {
                    filteredMap.put(emailMessageId, caseId);
                } else {
                    System.debug(LoggingLevel.WARN, 'EmailAttachmentLinkHandler: Invalid Case ID in provided map - ' +
                        'EmailMessage: ' + emailMessageId + ', CaseId: ' + caseId +
                        ' (does not start with 500, skipping)');
                }
            }
        }
        return filteredMap;
    }

    /**
     * Creates a ContentDocumentLink with default ShareType and Visibility.
     * @param contentDocumentId ContentDocument Id
     * @param linkedEntityId Id to link the document to
     */
    private static ContentDocumentLink buildContentDocumentLink(Id contentDocumentId, Id linkedEntityId) {
        ContentDocumentLink link = new ContentDocumentLink();
        link.ContentDocumentId = contentDocumentId;
        link.LinkedEntityId = linkedEntityId;
        link.ShareType = 'V';
        link.Visibility = 'AllUsers';
        return link;
    }

    /**
     * Loads existing ContentDocumentLink keys for the provided content documents and linked entities.
     */
    private static Set<String> getExistingLinkKeys(Set<Id> contentDocumentIds, Set<Id> linkedEntityIds) {
        Set<String> existingLinks = new Set<String>();
        if (contentDocumentIds == null || contentDocumentIds.isEmpty() ||
            linkedEntityIds == null || linkedEntityIds.isEmpty()) {
            return existingLinks;
        }
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

    /**
     * Logs results from ContentDocumentLink insert operations.
     */
    private static void logInsertResults(
        List<ContentDocumentLink> links,
        Database.SaveResult[] results,
        String successPrefix,
        String failurePrefix,
        String summaryPrefix
    ) {
        Integer successCount = 0;
        Integer failureCount = 0;
        for (Integer i = 0; i < results.size(); i++) {
            Database.SaveResult result = results[i];
            if (result.isSuccess()) {
                successCount++;
                System.debug(LoggingLevel.INFO, successPrefix +
                    links[i].ContentDocumentId + ' -> ' + links[i].LinkedEntityId);
            } else {
                failureCount++;
                String errorMsg = failurePrefix +
                    links[i].ContentDocumentId + ' -> ' + links[i].LinkedEntityId;
                for (Database.Error err : result.getErrors()) {
                    errorMsg += ' - Error: ' + err.getMessage() + ' (' + err.getStatusCode() + ')';
                }
                System.debug(LoggingLevel.ERROR, errorMsg);
            }
        }
        System.debug(LoggingLevel.INFO, summaryPrefix + successCount + ', Failures: ' + failureCount);
    }
    
    /**
     * Links FILES (ContentDocuments) attached to EmailMessage records to their related Case records
     * This method finds files that are attached to EmailMessages and creates ContentDocumentLinks
     * to link those same files to the related Case records.
     * 
     * @param contentDocumentLinks List of ContentDocumentLink records to process
     */
    public static void linkEmailFilesToCases(List<ContentDocumentLink> contentDocumentLinks) {
        // Prevent recursive calls being processed for 
        // if (isProcessing) {
        //     System.debug(LoggingLevel.DEBUG, 'EmailAttachmentLinkHandler: Skipping recursive call');
        //     return;
        // }
        
        // isProcessing = true;

        // Step 1: Find files (ContentDocuments) that are attached to EmailMessages
        // We're looking for ContentDocumentLinks where LinkedEntityId = EmailMessage
        // This means: File (ContentDocument) is linked to EmailMessage
        Set<Id> emailMessageIds = new Set<Id>();
        Map<Id, Id> fileToEmailMessageMap = new Map<Id, Id>(); // Maps: ContentDocumentId -> EmailMessageId
        
        System.debug(LoggingLevel.INFO, 'EmailAttachmentLinkHandler: [FILES] Processing ' + contentDocumentLinks.size() + 
            ' ContentDocumentLink record(s) - looking for Files (ContentDocuments) attached to EmailMessages');
        
        for (ContentDocumentLink cdl : contentDocumentLinks) {
            if (cdl.LinkedEntityId != null) {
                String objectType = String.valueOf(cdl.LinkedEntityId.getSObjectType());
                if (objectType == 'EmailMessage') {

                    // This ContentDocumentLink represents a FILE attached to an EmailMessage
                    emailMessageIds.add(cdl.LinkedEntityId);
                    fileToEmailMessageMap.put(cdl.ContentDocumentId, cdl.LinkedEntityId);
                    
                    System.debug(LoggingLevel.INFO, 'EmailAttachmentLinkHandler: [FOUND] Found existing File (ContentDocument: ' + 
                        cdl.ContentDocumentId + ') attached to EmailMessage: ' + cdl.LinkedEntityId);
                }
            }
        }
        
        if (emailMessageIds.isEmpty()) {
           //isProcessing = false;
            return;
        }
        
        // Step 2: Find which Case each EmailMessage belongs to
        // We need to know the Case so we can link the FILES to it
        Map<Id, Id> emailMessageToCaseMap = queryEmailMessageToCaseMap(emailMessageIds, true); // Maps: EmailMessageId -> CaseId
        
        if (emailMessageToCaseMap.isEmpty()) {
            //isProcessing = false;
            return;
        }
        
        // Find existing ContentDocumentLinks to Cases to avoid duplicates
        Set<Id> contentDocumentIds = fileToEmailMessageMap.keySet();
        Set<Id> caseIds = new Set<Id>(emailMessageToCaseMap.values());
        
        Set<String> existingLinks = getExistingLinkKeys(contentDocumentIds, caseIds);
        
        // Step 3: Create ContentDocumentLinks to link the FILES to Cases
        // We're linking the same files (ContentDocuments) that are attached to EmailMessages
        // to also be linked to the related Case records
        // Process each ContentDocumentLink individually to handle cases where same file is linked to multiple EmailMessages
        List<ContentDocumentLink> linksToCreate = new List<ContentDocumentLink>();
        Set<String> processedLinks = new Set<String>(); // Track links we've already processed to avoid duplicates
        
        for (ContentDocumentLink cdl : contentDocumentLinks) {
            if (cdl.LinkedEntityId != null) {
                String objectType = String.valueOf(cdl.LinkedEntityId.getSObjectType());
                if (objectType == 'EmailMessage') {
                    Id emailMessageId = cdl.LinkedEntityId;
                    Id contentDocId = cdl.ContentDocumentId;
                    Id caseId = emailMessageToCaseMap.get(emailMessageId);
                    
                    if (caseId != null) {
                        String linkKey = contentDocId + '_' + caseId;
                        // Check if we've already processed this file-to-case combination in this batch
                        if (!processedLinks.contains(linkKey) && !existingLinks.contains(linkKey)) {
                            // Create a new link: File (ContentDocument) -> Case
                            linksToCreate.add(buildContentDocumentLink(contentDocId, caseId));
                            processedLinks.add(linkKey); // Mark as processed
                            
                            System.debug(LoggingLevel.INFO, 'EmailAttachmentLinkHandler: [NEW LINK] Creating ContentDocumentLink to link existing File to Case - ' +
                                'File (ContentDocumentId): ' + contentDocId + 
                                ' -> CaseId: ' + caseId + 
                                ' (File was originally attached to EmailMessage: ' + emailMessageId + ')');
                        } else {
                            System.debug(LoggingLevel.INFO, 'EmailAttachmentLinkHandler: [SKIP] File already linked to Case - ' +
                                'File (ContentDocumentId): ' + contentDocId + ', CaseId: ' + caseId + ' (No new link needed)');
                        }
                    } else {
                        System.debug(LoggingLevel.WARN, 'EmailAttachmentLinkHandler: Cannot link file - No Case found for EmailMessage ' + 
                            emailMessageId + ', File (ContentDocumentId): ' + contentDocId);
                    }
                }
            }
        }
        
        if (!linksToCreate.isEmpty()) {
            try {
                // Note: Inserting these ContentDocumentLinks will trigger ContentDocumentLinkTrigger again
                // However, our handler will skip them because they're linked to Cases, not EmailMessages
                // (see line 27 check: objectType == 'EmailMessage')
                System.debug(LoggingLevel.INFO, 'EmailAttachmentLinkHandler: [INSERT] Inserting ' + linksToCreate.size() + 
                    ' ContentDocumentLink record(s) to link existing Files to Cases');
                
                // Use helper class without sharing to ensure DML operations succeed
                // This is important for batch operations and when called from system context
                LinkCreator linkCreator = new LinkCreator();
                Database.SaveResult[] results = linkCreator.createLinks(linksToCreate);
                
                logInsertResults(
                    linksToCreate,
                    results,
                    'EmailAttachmentLinkHandler: [SUCCESS] Created ContentDocumentLink - File: ',
                    'EmailAttachmentLinkHandler: Failed to create ContentDocumentLink - File: ',
                    'EmailAttachmentLinkHandler: Insert complete - Success: '
                );
            } catch (Exception e) {
                // Log error but don't fail the transaction
                System.debug(LoggingLevel.ERROR, 'EmailAttachmentLinkHandler: Unexpected error linking files to Cases: ' + 
                    e.getMessage() + ' - Stack trace: ' + e.getStackTraceString());
            } finally {
                //isProcessing = false;
            }
        } else {
            System.debug(LoggingLevel.INFO, 'EmailAttachmentLinkHandler: [SUMMARY] No new ContentDocumentLinks to create - all Files already linked to their Cases or no Case found');
            //isProcessing = false;
        }
    }
    
    /**
     * Handles Attachment records attached to EmailMessages
     * Converts them to Files (ContentDocument) and links them to the related Case
     * 
     * @param attachments List of Attachment records to process
     */
    public static void linkEmailAttachmentsToCases(List<Attachment> attachments) {
        linkEmailAttachmentsToCases(attachments, null);
    }
    
    /**
     * Handles Attachment records attached to EmailMessages
     * Converts them to Files (ContentDocument) and links them to the related Case
     * Optimized version that accepts pre-queried emailMessageToCaseMap to avoid SOQL queries
     * 
     * @param attachments List of Attachment records to process
     * @param emailMessageToCaseMap Pre-queried map of EmailMessageId -> CaseId (optional, will query if null)
     */
    public static void linkEmailAttachmentsToCases(List<Attachment> attachments, Map<Id, Id> emailMessageToCaseMap) {
        if (attachments == null || attachments.isEmpty()) {
            return;
        }
        
        System.debug(LoggingLevel.INFO, 'EmailAttachmentLinkHandler: [ATTACHMENTS] Processing ' + attachments.size() + 
            ' Attachment record(s) from EmailMessages - will convert to Files (ContentDocuments) if needed');
        
        // Step 1: Find EmailMessage IDs from Attachments
        Set<Id> emailMessageIds = new Set<Id>();
        Map<Id, Attachment> emailMessageToAttachmentMap = new Map<Id, Attachment>();
        
        for (Attachment att : attachments) {
            if (att.ParentId != null) {
                String parentType = String.valueOf(att.ParentId.getSObjectType());
                if (parentType == 'EmailMessage') {
                    emailMessageIds.add(att.ParentId);
                    emailMessageToAttachmentMap.put(att.ParentId, att);
                }
            }
        }
        
        if (emailMessageIds.isEmpty()) {
            System.debug(LoggingLevel.DEBUG, 'EmailAttachmentLinkHandler: No Attachments linked to EmailMessages found');
            return;
        }
        
        // Step 2: Find which Case each EmailMessage belongs to
        // Use provided map if available, otherwise query
        if (emailMessageToCaseMap == null) {
            emailMessageToCaseMap = queryEmailMessageToCaseMap(emailMessageIds, false);
        } else {
            // Filter the provided map to only include EmailMessages we're processing
            emailMessageToCaseMap = filterEmailMessageToCaseMap(emailMessageIds, emailMessageToCaseMap);
        }
        
        if (emailMessageToCaseMap.isEmpty()) {
            System.debug(LoggingLevel.WARN, 'EmailAttachmentLinkHandler: No Cases found for EmailMessages with Attachments');
            return;
        }
        
        // Step 3: Check if Files already exist for these EmailMessages (to avoid duplicate conversions)
        // Step 4: Convert only Attachments that don't already have Files linked to their EmailMessages
        // This prevents duplicate conversions while preserving existing relationships
        List<Attachment> attachmentsToConvert = new List<Attachment>();
        Map<Id, Id> existingFileToEmailMessageMap = new Map<Id, Id>(); // Track existing Files for EmailMessages
        
        // First, check for existing Files linked to EmailMessages
        for (ContentDocumentLink existing : [
            SELECT ContentDocumentId, LinkedEntityId
            FROM ContentDocumentLink
            WHERE LinkedEntityId IN :emailMessageIds
        ]) {
            existingFileToEmailMessageMap.put(existing.LinkedEntityId, existing.ContentDocumentId);
        }
        
        for (Id emailMessageId : emailMessageToCaseMap.keySet()) {
            Attachment att = emailMessageToAttachmentMap.get(emailMessageId);
            if (att != null) {
                // Only convert if there's no existing File linked to this EmailMessage
                // This preserves existing Files and avoids duplicates
                if (!existingFileToEmailMessageMap.containsKey(emailMessageId)) {
                    attachmentsToConvert.add(att);
                    System.debug(LoggingLevel.INFO, 'EmailAttachmentLinkHandler: [CONVERT] Attachment needs conversion - ' +
                        'Attachment: ' + att.Id + ' (' + att.Name + ') -> EmailMessage: ' + emailMessageId + 
                        ' (no existing File found)');
                } else {
                    System.debug(LoggingLevel.INFO, 'EmailAttachmentLinkHandler: [SKIP] Attachment already has File - ' +
                        'Attachment: ' + att.Id + ' (' + att.Name + ') -> EmailMessage: ' + emailMessageId + 
                        ' -> Existing File (ContentDocument): ' + existingFileToEmailMessageMap.get(emailMessageId) + 
                        ' (preserving existing File, will only create missing links)');
                }
            }
        }
        
        // Convert Attachments to Files (only those that need conversion)
        LinkCreator converter = new LinkCreator();
        Map<Id, Id> attachmentToContentDocumentMap = converter.convertAttachmentsToFiles(
            attachmentsToConvert, 
            emailMessageToCaseMap
        );
        
        // Add existing Files to the map so we can create links for them too
        for (Id emailMessageId : existingFileToEmailMessageMap.keySet()) {
            Attachment att = emailMessageToAttachmentMap.get(emailMessageId);
            if (att != null && emailMessageToCaseMap.containsKey(emailMessageId)) {
                Id existingFileId = existingFileToEmailMessageMap.get(emailMessageId);
                // Use Attachment ID as key, but we'll track that this is an existing File
                attachmentToContentDocumentMap.put(att.Id, existingFileId);
                System.debug(LoggingLevel.INFO, 'EmailAttachmentLinkHandler: [PRESERVE] Using existing File for Attachment - ' +
                    'Attachment: ' + att.Id + ' (' + att.Name + ') -> Existing File (ContentDocument): ' + existingFileId);
            }
        }
        
        if (attachmentToContentDocumentMap.isEmpty()) {
            System.debug(LoggingLevel.WARN, 'EmailAttachmentLinkHandler: [SKIP] Failed to convert any Attachments to Files - ' +
                'no valid Attachments found or conversion failed');
            return;
        }
        
        System.debug(LoggingLevel.INFO, 'EmailAttachmentLinkHandler: [CONVERT] Successfully converted ' + 
            attachmentToContentDocumentMap.size() + ' Attachment(s) to File(s) (ContentDocuments)');
        
        // Step 5: Create ContentDocumentLinks to link Files back to EmailMessages (preserve original relationship)
        Set<Id> contentDocumentIds = new Set<Id>(attachmentToContentDocumentMap.values());
        // Reuse emailMessageIds - it already contains the EmailMessage IDs we need
        // emailMessageIds is already populated from Step 1, and emailMessageToCaseMap.keySet() contains the same IDs
        Set<Id> caseIds = new Set<Id>(emailMessageToCaseMap.values());
        
        // Check for existing links to both EmailMessages and Cases
        Set<Id> linkedEntityIds = new Set<Id>();
        linkedEntityIds.addAll(emailMessageIds);
        linkedEntityIds.addAll(caseIds);
        Set<String> existingLinks = getExistingLinkKeys(contentDocumentIds, linkedEntityIds);
        
        // Create new links - first link Files back to EmailMessages, then to Cases
        // Process both newly converted Files and existing Files
        List<ContentDocumentLink> linksToCreate = new List<ContentDocumentLink>();
        
        // Process all Attachments (both converted and those with existing Files)
        for (Id emailMessageId : emailMessageToCaseMap.keySet()) {
            Attachment att = emailMessageToAttachmentMap.get(emailMessageId);
            if (att != null && att.ParentId != null && emailMessageToCaseMap.containsKey(att.ParentId)) {
                Id contentDocId = attachmentToContentDocumentMap.get(att.Id);
                Id caseId = emailMessageToCaseMap.get(emailMessageId);
                
                if (contentDocId != null) {
                    // First, ensure File is linked back to the original EmailMessage (preserve original relationship)
                    String emailLinkKey = contentDocId + '_' + emailMessageId;
                    if (!existingLinks.contains(emailLinkKey)) {
                        linksToCreate.add(buildContentDocumentLink(contentDocId, emailMessageId));
                        
                        System.debug(LoggingLevel.INFO, 'EmailAttachmentLinkHandler: [NEW LINK] Linking File back to original EmailMessage - ' +
                            'File (ContentDocument): ' + contentDocId + ' -> EmailMessage: ' + emailMessageId + 
                            ' (preserving original Attachment relationship)');
                    } else {
                        System.debug(LoggingLevel.INFO, 'EmailAttachmentLinkHandler: [PRESERVE] File already linked to EmailMessage - ' +
                            'File (ContentDocument): ' + contentDocId + ', EmailMessage: ' + emailMessageId + 
                            ' (existing link preserved)');
                    }
                    
                    // Then, link File to Case (for File Explorer visibility)
                    if (caseId != null) {
                        String caseLinkKey = contentDocId + '_' + caseId;
                        if (!existingLinks.contains(caseLinkKey)) {
                            linksToCreate.add(buildContentDocumentLink(contentDocId, caseId));
                            
                            System.debug(LoggingLevel.INFO, 'EmailAttachmentLinkHandler: [NEW LINK] Creating ContentDocumentLink to link File to Case - ' +
                                'Attachment: ' + att.Id + ' (' + att.Name + ') -> File (ContentDocument): ' + contentDocId + 
                                ' -> Case: ' + caseId);
                        } else {
                            System.debug(LoggingLevel.INFO, 'EmailAttachmentLinkHandler: [PRESERVE] File already linked to Case - ' +
                                'File (ContentDocument): ' + contentDocId + ', Case: ' + caseId + ' (existing link preserved)');
                        }
                    }
                } else {
                    System.debug(LoggingLevel.WARN, 'EmailAttachmentLinkHandler: [SKIP] Cannot link Attachment - ' +
                        'Attachment: ' + att.Id + ' (' + att.Name + ') - Missing ContentDocumentId');
                }
            }
        }
        
        if (!linksToCreate.isEmpty()) {
            System.debug(LoggingLevel.INFO, 'EmailAttachmentLinkHandler: [INSERT] Inserting ' + linksToCreate.size() + 
                ' ContentDocumentLink records for converted Attachments');
            Database.SaveResult[] results = converter.createLinks(linksToCreate);
            logInsertResults(
                linksToCreate,
                results,
                'EmailAttachmentLinkHandler: [SUCCESS] Created ContentDocumentLink for converted Attachment - File: ',
                'EmailAttachmentLinkHandler: [ERROR] Failed to create ContentDocumentLink - File: ',
                'EmailAttachmentLinkHandler: [SUMMARY] Linked converted Attachments to Cases - Success: '
            );
        } else {
            System.debug(LoggingLevel.INFO, 'EmailAttachmentLinkHandler: [SUMMARY] No new ContentDocumentLinks to create - ' +
                'all converted Attachments already linked to their Cases');
        }
    }
    
    /**
     * Invocable method to trigger the batch job for backfilling email attachments
     * Can be called from Flow, Process Builder, or other automation
     */
    @InvocableMethod(label='Run Email Attachment Backfill Batch' 
                     description='Runs a batch job to link existing email attachment files to their related Cases')
    public static void triggerBackfillBatch() {
        System.debug(LoggingLevel.INFO, 'EmailAttachmentLinkHandler: Invocable method called - Starting batch job');
        EmailAttachmentBackfillBatch batch = new EmailAttachmentBackfillBatch();
        Database.executeBatch(batch, 200);
        System.debug(LoggingLevel.INFO, 'EmailAttachmentLinkHandler: Batch job submitted successfully');
    }
    
    /**
     * Batch method to backfill existing email attachment files to Cases
     * Optimized to only process EmailMessages that actually have files attached
     * This can be called from a batch class or anonymous Apex
     */
    public static void backfillEmailFilesToCases() {
        // First, get EmailMessage IDs that are related to Cases
        Set<Id> emailMessageIdsWithCases = new Set<Id>();
        for (EmailMessage em : [
            SELECT Id
            FROM EmailMessage
            WHERE (ParentId != null OR RelatedToId != null)
        ]) {
            emailMessageIdsWithCases.add(em.Id);
        }
        
        if (emailMessageIdsWithCases.isEmpty()) {
            return;
        }
        
        // Then query ContentDocumentLinks only for those EmailMessages
        // This ensures we only process EmailMessages with attachments AND related to Cases
        List<ContentDocumentLink> emailFileLinks = [
            SELECT Id, ContentDocumentId, LinkedEntityId
            FROM ContentDocumentLink
            WHERE LinkedEntityId IN :emailMessageIdsWithCases
        ];
        
        if (!emailFileLinks.isEmpty()) {
            linkEmailFilesToCases(emailFileLinks);
        }
    }
}