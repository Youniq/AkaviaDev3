/**
 * Batch class to backfill existing email attachment files to Case records
 * Run this once to link all existing email attachment files to their related Cases
 * 
 * This batch handles both:
 * 1. Files (ContentDocumentLink) - modern Salesforce Files
 * 2. Attachments (Attachment) - legacy attachment system
 * 
 * LIMIT CONSIDERATIONS:
 * - QueryLocator can handle up to 50 million records (not 50,000), so large datasets are fine
 * - Records are processed in chunks (default 200 per execute() call, configurable via Database.executeBatch(batch, batchSize))
 * 
 * GOVERNOR LIMITS PER EXECUTE() CALL:
 * - SOQL Queries: 2 queries (without attachments) or 6 queries (with attachments)
 *   Limit: 200 queries per batch transaction - ✅ Safe (can process ~33 batches with attachments)
 * - DML Statements: 1-2 statements per batch
 *   Limit: 150 statements per batch transaction - ✅ Safe
 * - DML Rows: Variable (depends on number of files per EmailMessage)
 *   Limit: 10,000 rows per batch transaction - ⚠️ Monitor if EmailMessages have many files
 *   Safeguard: Automatically chunks large inserts if approaching limit
 * - Heap Size: Variable (depends on batch size and number of files)
 *   Limit: 12 MB per batch transaction - ⚠️ Monitor for large batches
 *   Safeguard: Attachment processing skipped if heap > 80% of limit
 * - CPU Time: Minimal processing, mostly queries and DML
 *   Limit: 10,000 ms per batch transaction - ✅ Safe
 * 
 * RECOMMENDATIONS:
 * - For large datasets (millions of records), consider smaller batch size (e.g., 100)
 * - Monitor logs for limit warnings
 * - If DML rows limit is hit frequently, reduce batch size further
 */
public class EmailAttachmentBackfillBatch implements Database.Batchable<sObject>, Database.Stateful {
    
    private Integer totalProcessed = 0;
    private Integer totalLinked = 0;
    private Integer totalErrors = 0;
    private Integer totalAttachmentsProcessed = 0;
    private Integer totalAttachmentsConverted = 0;
    
    public Database.QueryLocator start(Database.BatchableContext bc) {
        // Query EmailMessages with parents and attachments
        // Note: Can't use ContentDocumentLink in subquery (semi-join not supported)
        // Note: SOQL cannot filter by ID prefix (e.g., "starts with 500"), so we filter in execute() method
        // We'll filter by Case prefix (500) for both ParentId and RelatedToId in execute method
        // 
        // IMPORTANT: QueryLocator can handle up to 50 million records, so 50,000+ is not a problem.
        // The batch processes records in chunks (default 200 per execute() call).
        // This query may return many records, but Salesforce will process them in manageable batches.
        // 
        // Optimization: Filter by HasAttachment = true to only process EmailMessages with attachments
        // This significantly reduces the number of records processed, improving performance
        // Note: HasAttachment primarily tracks legacy Attachments, but this optimization still helps
        // by filtering out EmailMessages that definitely have no attachments
        // Optimization: Added ORDER BY to ensure consistent processing order
        // Consider adding date filters if processing in waves: WHERE CreatedDate >= :startDate
        return Database.getQueryLocator([
            SELECT Id, ParentId, RelatedToId
            FROM EmailMessage
            WHERE (ParentId != null OR RelatedToId != null)
            AND HasAttachment = true
            ORDER BY CreatedDate ASC
        ]);
    }
    
    public void execute(Database.BatchableContext bc, List<EmailMessage> emailMessages) {
        // Step 1: Filter EmailMessages to only those with Case parents (starting with 500)
        // Optimized: Single pass with early validation
        // IMPORTANT: Only process EmailMessages where ParentId or RelatedToId starts with '500' (Case prefix)
        // This ensures we only modify Cases and not other object types
        Map<Id, Id> emailMessageToCaseMap = new Map<Id, Id>();
        Set<Id> validEmailMessageIds = new Set<Id>();
        
        for (EmailMessage em : emailMessages) {
            Id caseId = null;
            
            // Check ParentId
            if (em.ParentId != null) {
                String parentIdStr = String.valueOf(em.ParentId);
                // Ensure ParentId starts with '500' (Case prefix) before using it
                if (parentIdStr.startsWith('500') && String.valueOf(em.ParentId.getSObjectType()) == 'Case') {
                    caseId = em.ParentId;
                }
            }
            
            // If ParentId is not a Case, check RelatedToId
            if (caseId == null && em.RelatedToId != null) {
                String relatedToIdStr = String.valueOf(em.RelatedToId);
                if (relatedToIdStr.startsWith('500') && String.valueOf(em.RelatedToId.getSObjectType()) == 'Case') {
                    caseId = em.RelatedToId;
                }
            }
            
            // Only process if we found a valid Case ID (starts with 500)
            if (caseId != null) {
                emailMessageToCaseMap.put(em.Id, caseId);
                validEmailMessageIds.add(em.Id);
            }
        }
        
        if (emailMessageToCaseMap.isEmpty()) {
            return;
        }
        
        // Step 2: Get ContentDocumentLinks for these EmailMessages
        List<ContentDocumentLink> emailFileLinks = [
            SELECT Id, ContentDocumentId, LinkedEntityId
            FROM ContentDocumentLink
            WHERE LinkedEntityId IN :validEmailMessageIds
        ];
        
        if (emailFileLinks.isEmpty()) {
            return;
        }
        
        totalProcessed += emailFileLinks.size();
        
        // Step 3: Get all existing ContentDocumentLinks for these Files and Cases
        Set<Id> contentDocumentIds = new Set<Id>();
        Set<Id> caseIds = new Set<Id>(emailMessageToCaseMap.values());
        
        // Build contentDocumentIds set efficiently
        for (ContentDocumentLink cdl : emailFileLinks) {
            contentDocumentIds.add(cdl.ContentDocumentId);
        }
        
        // Early exit if no content documents to process
        if (contentDocumentIds.isEmpty() || caseIds.isEmpty()) {
            return;
        }
        
        // Query for existing links - this is preventing duplicates
        Set<String> existingLinks = new Set<String>();
        for (ContentDocumentLink existing : [
            SELECT ContentDocumentId, LinkedEntityId
            FROM ContentDocumentLink
            WHERE ContentDocumentId IN :contentDocumentIds
            AND LinkedEntityId IN :caseIds
        ]) {
            // Optimized: Use string concatenation that's cached
            existingLinks.add(existing.ContentDocumentId + '_' + existing.LinkedEntityId);
        }
        
        // Step 4: Create new ContentDocumentLinks only for Files not already linked to Cases
        List<ContentDocumentLink> linksToCreate = new List<ContentDocumentLink>();
        Integer skippedCount = 0;
        
        for (ContentDocumentLink cdl : emailFileLinks) {
            Id caseId = emailMessageToCaseMap.get(cdl.LinkedEntityId);
            
            // Skip if no Case found for this EmailMessage
            if (caseId == null) {
                continue;
            }
            
            // Check if link already exists (optimized string key)
            String linkKey = cdl.ContentDocumentId + '_' + caseId;
            if (!existingLinks.contains(linkKey)) {
                // Create a new link: File (ContentDocument) -> Case
                ContentDocumentLink newLink = new ContentDocumentLink();
                newLink.ContentDocumentId = cdl.ContentDocumentId;
                newLink.LinkedEntityId = caseId;
                newLink.ShareType = 'V';
                newLink.Visibility = 'AllUsers';
                linksToCreate.add(newLink);
            } else {
                skippedCount++;
            }
        }
        
        // Log summary instead of individual records
        if (linksToCreate.size() > 0 || skippedCount > 0) {
            System.debug(LoggingLevel.INFO, 'EmailAttachmentBackfillBatch: [BATCH SUMMARY] ' + 
                linksToCreate.size() + ' new links to create, ' + skippedCount + ' already exist');
        }
        
        // Monitor governor limits
        System.debug(LoggingLevel.INFO, 'EmailAttachmentBackfillBatch: [LIMITS] Queries: ' + Limits.getQueries() + '/200, ' +
            'DML Rows: ' + Limits.getDMLRows() + '/10000, Heap: ' + Limits.getHeapSize() + '/' + Limits.getLimitHeapSize());
        
        if (!linksToCreate.isEmpty()) {
            try {
                // Check DML rows limit before inserting
                Integer availableDMLRows = Limits.getLimitDMLRows() - Limits.getDMLRows();
                if (linksToCreate.size() > availableDMLRows) {
                    System.debug(LoggingLevel.WARN, 'EmailAttachmentBackfillBatch: [LIMIT WARNING] Attempting to insert ' + 
                        linksToCreate.size() + ' rows, but only ' + availableDMLRows + ' DML rows available. ' +
                        'Splitting into chunks.');
                    
                    // Split into chunks to avoid hitting DML rows limit
                    Integer chunkSize = Math.min(availableDMLRows, 1000); // Process in chunks of 1000 or available limit
                    Integer totalInserted = 0;
                    
                    for (Integer i = 0; i < linksToCreate.size(); i += chunkSize) {
                        Integer endIndex = Math.min(i + chunkSize, linksToCreate.size());
                        List<ContentDocumentLink> chunk = new List<ContentDocumentLink>();
                        for (Integer j = i; j < endIndex; j++) {
                            chunk.add(linksToCreate[j]);
                        }
                        
                        if (!chunk.isEmpty()) {
                            Database.SaveResult[] chunkResults = Database.insert(chunk, false);
                            Integer chunkSuccess = 0;
                            Integer chunkFailures = 0;
                            
                            for (Database.SaveResult result : chunkResults) {
                                if (result.isSuccess()) {
                                    chunkSuccess++;
                                } else {
                                    chunkFailures++;
                                }
                            }
                            
                            totalInserted += chunkSuccess;
                            totalErrors += chunkFailures;
                            
                            System.debug(LoggingLevel.INFO, 'EmailAttachmentBackfillBatch: Chunk ' + (i/chunkSize + 1) + 
                                ' complete - Success: ' + chunkSuccess + ', Failures: ' + chunkFailures);
                        }
                    }
                    
                    totalLinked += totalInserted;
                    System.debug(LoggingLevel.INFO, 'EmailAttachmentBackfillBatch: All chunks complete - Total inserted: ' + totalInserted);
                    return; // Exit early since we've processed in chunks
                }
                
                System.debug(LoggingLevel.INFO, 'EmailAttachmentBackfillBatch: Inserting ' + linksToCreate.size() + 
                    ' ContentDocumentLink records to Cases');
                
                // Use Database.insert with allOrNone=false to handle partial failures gracefully
                Database.SaveResult[] results = Database.insert(linksToCreate, false);
                
                Integer successCount = 0;
                Integer failureCount = 0;
                List<String> errorDetails = new List<String>();
                
                for (Integer i = 0; i < results.size(); i++) {
                    Database.SaveResult result = results[i];
                    if (result.isSuccess()) {
                        successCount++;
                    } else {
                        failureCount++;
                        // Collect error details but only log first few to avoid log bloat
                        if (errorDetails.size() < 5) {
                            String errorMsg = 'File: ' + linksToCreate[i].ContentDocumentId + 
                                ' -> Case: ' + linksToCreate[i].LinkedEntityId;
                            for (Database.Error err : result.getErrors()) {
                                errorMsg += ' - ' + err.getMessage() + ' (' + err.getStatusCode() + ')';
                            }
                            errorDetails.add(errorMsg);
                        }
                    }
                }
                
                // Log errors if any (limit to first 5 to avoid log bloat)
                if (failureCount > 0) {
                    System.debug(LoggingLevel.ERROR, 'EmailAttachmentBackfillBatch: [ERRORS] ' + 
                        failureCount + ' failed. First errors: ' + String.join(errorDetails, '; '));
                }
                
                totalLinked += successCount;
                totalErrors += failureCount;
                System.debug(LoggingLevel.INFO, 'EmailAttachmentBackfillBatch: Insert complete - Success: ' + 
                    successCount + ', Failures: ' + failureCount);
            } catch (Exception e) {
                totalErrors += linksToCreate.size();
                System.debug(LoggingLevel.ERROR, 'EmailAttachmentBackfillBatch: Unexpected error in batch: ' + 
                    e.getMessage() + ' - Stack trace: ' + e.getStackTraceString());
            }
        } else {
            System.debug(LoggingLevel.INFO, 'EmailAttachmentBackfillBatch: [SUMMARY] No new ContentDocumentLinks to create in this batch - all Files already linked to their Cases');
        }
        
        // Process Attachments separately to avoid SOQL query limit issues
        // Pass the already-queried emailMessageToCaseMap to avoid re-querying
        // Check multiple limits before processing attachments
        Integer currentQueries = Limits.getQueries();
        Integer currentDMLRows = Limits.getDMLRows();
        Long currentHeap = Limits.getHeapSize();
        Long heapLimit = Limits.getLimitHeapSize();
        
        // Only process attachments if we have sufficient limits remaining
        // Attachment processing uses ~4 additional queries and may create DML rows
        if (currentQueries < 150 && currentDMLRows < 8000 && currentHeap < (heapLimit * 0.8)) {
            processAttachmentsForEmailMessages(emailMessageToCaseMap);
        } else {
            String limitWarnings = '';
            if (currentQueries >= 150) {
                limitWarnings += 'Queries: ' + currentQueries + '/200; ';
            }
            if (currentDMLRows >= 8000) {
                limitWarnings += 'DML Rows: ' + currentDMLRows + '/10000; ';
            }
            if (currentHeap >= (heapLimit * 0.8)) {
                limitWarnings += 'Heap: ' + currentHeap + '/' + heapLimit + '; ';
            }
            
            System.debug(LoggingLevel.WARN, 'EmailAttachmentBackfillBatch: Skipping Attachment processing to avoid limits - ' +
                limitWarnings + 'Process Attachments in a separate batch if needed.');
        }
    }
    
    /**
     * Processes Attachment records for EmailMessages and converts them to Files
     * NOTE: This method is currently disabled in execute() to avoid SOQL query limit issues.
     * If you need to process Attachments, consider running a separate batch job or
     * processing them in a different context.
     */
    private void processAttachmentsForEmailMessages(Map<Id, Id> emailMessageToCaseMap) {
        if (emailMessageToCaseMap == null || emailMessageToCaseMap.isEmpty()) {
            return;
        }
        
        // Query Attachments linked to these EmailMessages
        List<Attachment> attachments = [
            SELECT Id, Name, Body, ParentId, ContentType, BodyLength
            FROM Attachment
            WHERE ParentId IN :emailMessageToCaseMap.keySet()
        ];
        
        if (attachments.isEmpty()) {
            return;
        }
        
        totalAttachmentsProcessed += attachments.size();
        System.debug(LoggingLevel.INFO, 'EmailAttachmentBackfillBatch: [ATTACHMENTS] Found ' + attachments.size() + 
            ' Attachment record(s) that need to be converted to Files (ContentDocuments)');
        
        // Use the handler method to convert and link
        // Pass the already-queried emailMessageToCaseMap to avoid re-querying (saves SOQL queries)
        try {
            EmailAttachmentLinkHandler.linkEmailAttachmentsToCases(attachments, emailMessageToCaseMap);
            totalAttachmentsConverted += attachments.size();
        } catch (Exception e) {
            totalErrors += attachments.size();
            System.debug(LoggingLevel.ERROR, 'EmailAttachmentBackfillBatch: Error processing Attachments: ' + 
                e.getMessage() + ' - Stack trace: ' + e.getStackTraceString());
        }
    }
    
    public void finish(Database.BatchableContext bc) {
        // Send summary email or log results
        System.debug(LoggingLevel.INFO, 'Email Attachment Backfill Complete:');
        System.debug(LoggingLevel.INFO, 'Total files (ContentDocumentLink) processed: ' + totalProcessed);
        System.debug(LoggingLevel.INFO, 'Total links created: ' + totalLinked);
        System.debug(LoggingLevel.INFO, 'Total Attachments processed: ' + totalAttachmentsProcessed);
        System.debug(LoggingLevel.INFO, 'Total Attachments converted: ' + totalAttachmentsConverted);
        System.debug(LoggingLevel.INFO, 'Total errors: ' + totalErrors);
    }
}