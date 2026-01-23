/**
 * @description Controller for bulk email functionality to send emails to multiple employees
 * @author AI Assistant
 * @group Bulk Email
 * @last modified on 2024-01-15
 * @last modified by AI Assistant
**/
public without sharing class BulkEmailController {
    
    /**
     * @description Get active employees for a given employer account with pagination support
     * @param accountId The ID of the employer account
     * @param pageSize Number of records per page (default: 25)
     * @param pageNumber Page number to retrieve (1-based)
     * @param searchTerm Optional search term to filter by name or email
     * @return PaginatedResult containing employees and pagination metadata
     */
    @AuraEnabled(cacheable=true)
    public static PaginatedResult getActiveEmployeesPaginated(String accountId, Integer pageSize, Integer pageNumber, 
                                                             String searchTerm) {
        try {
            // Set defaults
            if (pageSize == null || pageSize <= 0) {
                pageSize = 25;
            }
            if (pageNumber == null || pageNumber <= 0) {
                pageNumber = 1;
            }
            
            // Validate pageSize limit for client-side pagination
            if (pageSize > 3500) {
                pageSize = 3500; // Allow up to 3500 records for client-side pagination
            }
            
            // Check if Employment__c object is accessible
            if (!Schema.sObjectType.Employment__c.isAccessible()) {
                throw new customException('Insufficient permissions to access employment records');
            }
            
            // Build query with proper variable binding
            String query = 'SELECT Id, Person__c, Person__r.Name, Person__r.PersonEmail, ' +
                          'Person__r.FirstName, Person__r.LastName, WorkplaceName__c, StartDate__c, EndDate__c ' +
                          'FROM Employment__c ' +
                          'WHERE Workplace__r.ParentId = :accountId ' +
                          'AND Status__c = \'Aktiv\' ' +
                          'AND Person__r.PersonEmail != null ' +
                          'AND Person__r.isPersonAccount = true';
            
            // Add search filter if provided
            if (String.isNotBlank(searchTerm)) {
                String searchPattern = '%' + searchTerm + '%';
                query += ' AND (Person__r.Name LIKE :searchPattern OR Person__r.PersonEmail LIKE :searchPattern OR WorkplaceName__c LIKE :searchPattern)';
            }
            
            query += ' ORDER BY WorkplaceName__c asc' +
                    ' LIMIT ' + pageSize + ' OFFSET ' + ((pageNumber - 1) * pageSize);
            
            // Execute query
            List<Employment__c> employments = Database.query(query);
            
            // Convert to RecipientWrapper objects
            List<RecipientWrapper> recipients = new List<RecipientWrapper>();
            Integer index = 0;
            for (Employment__c emp : employments) {
                String emailAddress = emp.Person__r.PersonEmail;
               // if (index < 50) { // Add @akavia.se to top 50 recipients for testing failing emails
                //    emailAddress += '@akavia.se';
                //}
                
                recipients.add(new RecipientWrapper(
                    emp.Person__c,
                    emp.Person__r.Name,
                    emailAddress,
                    emp.Person__r.FirstName,
                    emp.Person__r.LastName,
                    emp.WorkplaceName__c
                ));
                index++;
            }
            
            // Get total count for pagination using same filters
            String countQuery = 'SELECT COUNT() FROM Employment__c ' +
                               'WHERE Workplace__r.ParentId = :accountId ' +
                               'AND Status__c = \'Aktiv\' ' +
                               'AND Person__r.PersonEmail != null ' +
                               'AND Person__r.isPersonAccount = true';
            
            if (String.isNotBlank(searchTerm)) {
                String searchPattern = '%' + searchTerm + '%';
                countQuery += ' AND (Person__r.Name LIKE :searchPattern OR Person__r.PersonEmail LIKE :searchPattern OR WorkplaceName__c LIKE :searchPattern)';
            }
            
            Integer totalRecords = Database.countQuery(countQuery);
            Integer totalPages = (Integer) Math.ceil((Double) totalRecords / pageSize);
            
            return new PaginatedResult(recipients, totalRecords, totalPages, pageNumber, pageSize);
            
        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving employees: ' + e.getMessage());
        }
    }
    
    /**
     * @description Legacy method for backward compatibility - gets first page only
     * @param accountId The ID of the employer account
     * @return List of active employees as RecipientWrapper objects (first 25)
     */
    // @AuraEnabled(cacheable=true)
    // public static List<RecipientWrapper> getActiveEmployees(String accountId) {
    //     PaginatedResult result = getActiveEmployeesPaginated(accountId, 25, 1, null);
    //     return result.records;
    // }
    
    
    /**
     * @description Validate email inputs (subject and body)
     * @param subject Email subject
     * @param body Email body
     * @throws customException if validation fails
     */
    private static void validateEmailInputs(String subject, String body) {
        if (String.isBlank(subject)) {
            throw new customException('Email subject is required');
        }
        
        if (String.isBlank(body)) {
            throw new customException('Email body is required');
        }
        
        // Validate subject length (100 characters)
        if (subject.length() > 100) {
            throw new customException('Email subject cannot exceed 100 characters');
        }
        
        // Validate body length (25,000 characters)
        if (body.length() > 25000) {
            throw new customException('Email body cannot exceed 25,000 characters');
        }
    }
    
    /**
     * @description Create all BulkEmailSend__c records upfront - one per Platform Event
     * @param bulkEmailSendGroupId The BulkEmailSendGroupId__c for linking related records
     * @param accountId The Account ID
     * @param subject Email subject
     * @param body Email body
     * @param totalRecipients Total number of recipients (only set on first record)
     * @param parentBulkEmailSendId Parent BulkEmailSend__c ID (null for initial send, set for resend)
     * @param numberOfEvents Number of Platform Events that will be published
     * @return List of created BulkEmailSend__c records
     * @throws customException if record creation fails
     */
    private static List<BulkEmailSend__c> createBulkEmailSendRecords(
        String bulkEmailSendGroupId,
        String accountId,
        String subject,
        String body,
        Integer totalRecipients,
        Id parentBulkEmailSendId,
        Integer numberOfEvents) {
        

        System.debug('BulkEmail: Creating ' + numberOfEvents + ' BulkEmailSend__c records');
        // Create all BulkEmailSend__c records upfront - one per Platform Event
        List<BulkEmailSend__c> bulkEmailSendRecords = new List<BulkEmailSend__c>();
        for (Integer i = 1; i <= numberOfEvents; i++) {
            BulkEmailSend__c record = new BulkEmailSend__c(
                BulkEmailSendGroupId__c = bulkEmailSendGroupId,
                BatchSequence__c = i,
                Status__c = 'Queued',
                AccountId__c = accountId,
                Subject__c = subject,
                Body__c = body,
                TotalRecipients__c = (i == 1 ? totalRecipients : null), // Only first record gets total
                SuccessfulSends__c = 0,
                FailedSends__c = 0,
                CanResend__c = false
            );
            // Set parent on first record if provided (for resend operations)
            if (i == 1 && parentBulkEmailSendId != null) {
                record.ParentBulkEmailSendId__c = parentBulkEmailSendId;
            }
            bulkEmailSendRecords.add(record);
        }
        
        try {
            insert bulkEmailSendRecords;
            System.debug('BulkEmail: Created ' + bulkEmailSendRecords.size() + ' BulkEmailSend__c records');
            
            For (BulkEmailSend__c record : bulkEmailSendRecords) {
                System.debug('Created BulkEmail: Sequence ' + record.BatchSequence__c);
                System.debug('Created BulkEmail: Group ID ' + record.BulkEmailSendGroupId__c);
            }
            // Set ParentBulkEmailSendId__c for records with batchSequence > 1
            // For initial send: use first record as parent
            // For resend: also use first record as parent (first record already has mainRecord.Id as parent)
            if (bulkEmailSendRecords.size() > 1) {
                Id parentRecordId = bulkEmailSendRecords[0].Id;
                List<BulkEmailSend__c> recordsToUpdate = new List<BulkEmailSend__c>();
                for (Integer i = 1; i < bulkEmailSendRecords.size(); i++) {
                    bulkEmailSendRecords[i].ParentBulkEmailSendId__c = parentRecordId;
                    recordsToUpdate.add(bulkEmailSendRecords[i]);
                }
                update recordsToUpdate;
            }
        } catch (Exception e) {
            System.debug('BulkEmail: Error creating BulkEmailSend__c records - ' + e.getMessage());
            throw new customException('Error creating bulk email send records: ' + e.getMessage());
        }
        
        return bulkEmailSendRecords;
    }
    
    /**
     * @description Send bulk email to selected recipients using wrapper approach
     * @param accountId The ID of the employer account (for EmailMessage logging)
     * @param recipients List of RecipientWrapper objects to send email to
     * @param subject Email subject
     * @param body Email body (HTML)
     * @param attachmentIds List of attachment IDs
     * @return Result of the email sending operation
     */
    @AuraEnabled
    public static EmailResult sendBulkEmail(String accountId, List<Map<String, Object>> recipients, 
                                          String subject, String body, 
                                          List<String> attachmentIds) {
        try {
            // Validate inputs
            if (recipients == null || recipients.isEmpty()) {
                throw new customException('No recipients selected');
            }
            
            validateEmailInputs(subject, body);
            
            // Validate total attachment size (8MB)
            // COMMENTED OUT: Attachment logic temporarily disabled due to duplicate errors in Salesforce
            // when sending attachments on the same second. Will be re-enabled in future release.
            /*
            if (attachmentIds != null && !attachmentIds.isEmpty()) {
                Integer totalAttachmentSize = getTotalAttachmentSize(attachmentIds);
                System.debug('BulkEmail: Total attachment size: ' + totalAttachmentSize);
                Integer maxAttachmentSizeBytes = 8 * 1024 * 1024; // 8MB
                System.debug('BulkEmail: Max attachment size: ' + maxAttachmentSizeBytes);
                if (totalAttachmentSize > maxAttachmentSizeBytes) {
                    Decimal totalSizeMB = totalAttachmentSize / (1024.0 * 1024.0);
                    throw new customException('Total attachment size (' + totalSizeMB.setScale(2) + 'MB) cannot exceed 8MB');
                }
            }
            */
            
            // Filter recipients with valid email addresses
            // Only extract id, email, and workplace - name fields are only used in LWC component
            List<RecipientWrapper> validRecipients = new List<RecipientWrapper>();
            for (Map<String, Object> recipientMap : recipients) {
                if (recipientMap != null && recipientMap.containsKey('id') && recipientMap.containsKey('email')) {
                    String id = (String) recipientMap.get('id');
                    String email = (String) recipientMap.get('email');
                    if (String.isNotBlank(email) && String.isNotBlank(id)) {
                        String workplace = (String) recipientMap.get('WorkplaceName__c');
                        // Create RecipientWrapper with only essential fields (name fields will be queried later if needed)
                        validRecipients.add(new RecipientWrapper(id, null, email, null, null, workplace));
                    }
                }
            }
            
            if (validRecipients.isEmpty()) {
                throw new customException('No valid recipients found');
            }
            
            // Trigger batched email send using helper method
            return triggerBatchedEmailSend(
                validRecipients,
                accountId,
                subject,
                body,
                null, // originalGroupId - null for initial send
                null // parentBulkEmailSendId - null for initial send
            );
            
        } catch (Exception e) {
            System.debug('BulkEmail: Error sending email: ' + e.getMessage());
            throw new customException('Error sending email: ' + e.getMessage());
        }
    }
    
    /**
     * @description Split recipients into chunks considering both recipient count (150) and BCC character limit (4000)
     * @param recipients List of recipient accounts
     * @return List of recipient chunks that respect both limits
     */
    private static List<List<RecipientWrapper>> splitRecipientsIntoChunks(List<RecipientWrapper> recipients) {
        List<List<RecipientWrapper>> chunks = new List<List<RecipientWrapper>>();
        
        Integer maxRecipientsPerChunk = 25; // Salesforce limits each singleEmailMessage BCC for 25 recipients
        Integer maxBccCharacterLength = 2000; // Salesforce limit for BCC field character length (4000 bytes, adding limit on 2 byter per chars to not exceed the limit)
        
        List<RecipientWrapper> currentChunk = new List<RecipientWrapper>();
        Integer currentBccLength = 0;
        
        for (RecipientWrapper recipient : recipients) {
            // Calculate the length this recipient would add to BCC field
            // Each email address is separated by a semicolon and space (2 characters)
            Integer recipientEmailLength = recipient.email.length();
            Integer separatorLength = currentChunk.size() > 0 ? 2 : 0; // "; " for all but first email
            Integer totalLengthForThisRecipient = recipientEmailLength + separatorLength;
            
            // Check if adding this recipient would exceed either limit
            Boolean wouldExceedRecipientLimit = currentChunk.size() >= maxRecipientsPerChunk;
            Boolean wouldExceedCharacterLimit = (currentBccLength + totalLengthForThisRecipient) > maxBccCharacterLength;
            
            // If adding this recipient would exceed limits, start a new chunk
            if ((wouldExceedRecipientLimit || wouldExceedCharacterLimit) && currentChunk.size() > 0) {
                chunks.add(currentChunk);
                currentChunk = new List<RecipientWrapper>();
                currentBccLength = 0;
            }
            
            // Add recipient to current chunk
            currentChunk.add(recipient);
            currentBccLength += totalLengthForThisRecipient;
        }
        
        // Add the last chunk if it has any recipients
        if (currentChunk.size() > 0) {
            chunks.add(currentChunk);
        }
        
        return chunks;
    }
    
    /**
     * @description Convert RecipientWrapper batches to simplified format (id, email, workplace) for Platform Events
     * @param recipientChunks List of RecipientWrapper batches
     * @return List of simplified batches in format List<List<Map<String, String>>>
     */
    private static List<List<Map<String, String>>> convertRecipientsToSerializableFormat(
        List<List<RecipientWrapper>> recipientChunks) {
        List<List<Map<String, String>>> simplifiedBatches = new List<List<Map<String, String>>>();
        
        for (List<RecipientWrapper> chunk : recipientChunks) {
            List<Map<String, String>> simplifiedBatch = new List<Map<String, String>>();
            for (RecipientWrapper recipient : chunk) {
                Map<String, String> simplified = new Map<String, String>();
                simplified.put('id', recipient.id);
                simplified.put('email', recipient.email);
                simplified.put('workplace', recipient.workplace != null ? recipient.workplace : '');
                simplifiedBatch.add(simplified);
            }
            simplifiedBatches.add(simplifiedBatch);
        }
        
        return simplifiedBatches;
    }
    
    /**
     * @description Wrapper class for recipient data (scalable approach)
     */
    public class RecipientWrapper {
        @AuraEnabled public String id;
        @AuraEnabled public String name;
        @AuraEnabled public String email;
        @AuraEnabled public String firstName;
        @AuraEnabled public String lastName;
        @AuraEnabled public String workplace; // For any extra context
        
        // No-argument constructor required for JSON deserialization
        public RecipientWrapper() {
        }
        
        public RecipientWrapper(String id, String name, String email, String firstName, 
                               String lastName, String workplace) {
            this.id = id;
            this.name = name;
            this.email = email;
            this.firstName = firstName;
            this.lastName = lastName;
            this.workplace = workplace;
        }
    }
    
    /**
     * @description Create individual Task records for each recipient to track email activity
     * @param recipients List of recipients who received the email
     * @param subject Email subject
     * @param body Email body
     * @param attachmentIds List of attachment IDs
     * @param accountId Employer account ID
     * @return List of Task records
     */
    public static List<Task> createRecipientTasks(List<RecipientWrapper> recipients, String subject, String body, 
                                                   List<String> attachmentIds, String accountId, String employerName) {
        List<Task> tasks = new List<Task>();
        
        for (RecipientWrapper recipient : recipients) {
            try {
                Task task = new Task();
                task.WhatId = recipient.id; // Link to the recipient (Person Account)
                task.Subject = 'Email skickat: ' + subject;
                task.Description = 'Meddelande:\n' + body.stripHtmlTags();
                task.Status = 'Completed';
                task.Priority = 'Normal';
                task.ActivityDate = System.today();
                task.Type = 'Email';
                task.IsReminderSet = false;
                
                // Add attachment information if any
                if (attachmentIds != null && !attachmentIds.isEmpty()) {
                    task.Description += '\n\nBifogade filer: ' + attachmentIds.size() + ' fil(er).';
                }
                
                // Add additional context
                task.Description += '\n\nSkickat från medlemmens arbetsgivare: ' + employerName;
                if (String.isNotBlank(recipient.workplace)) {
                    task.Description += '\n(Arbetsställe: ' + recipient.workplace + ')';
                }
                
                tasks.add(task);
            } catch (Exception e) {
                System.debug('BulkEmail: Failed to create task for recipient ' + recipient.id + ': ' + e.getMessage());
                // Continue with other recipients even if one fails
            }
        }
        
        return tasks;
    }
    
    /**
     * @description Generate unique BulkEmailSendGroupId__c
     * @param originalGroupId Optional original BulkEmailSendGroupId__c for resend operations. If null/blank, generates a new unique ID.
     * @return Unique group ID string, or resend version with -RESEND-{sequence} suffix if originalGroupId is provided
     */
    private static String generateBulkEmailSendGroupId(String originalGroupId) {
        // If no original group ID provided, generate a new unique ID
        if (String.isBlank(originalGroupId)) {
            // Generate UUID-like identifier using timestamp and random number
            String timestamp = String.valueOf(DateTime.now().getTime());
            String randomNum = String.valueOf(Integer.valueOf(Math.random() * 1000000));
            return 'BESG-' + timestamp + '-' + randomNum;
        }
        
        // Generate resend version based on original group ID
        // Check if this is already a resend (contains -RESEND-)
        if (originalGroupId.contains('-RESEND-')) {
            // Extract the sequence number and increment it
            Integer lastIndex = originalGroupId.lastIndexOf('-RESEND-');
            String base = originalGroupId.substring(0, lastIndex);
            String suffix = originalGroupId.substring(lastIndex + 7); // Skip '-RESEND-'
            
            // Try to parse the sequence number
            try {
                Integer sequence = Integer.valueOf(suffix);
                return base + '-RESEND-' + (sequence + 1);
            } catch (Exception e) {
                // If parsing fails, start with RESEND-1
                return base + '-RESEND-1';
            }
        } else {
            // First resend, append -RESEND-1
            return originalGroupId + '-RESEND-1';
        }
    }
    
    /**
     * @description Collect all failed Account IDs from related BulkEmailSend__c records. Used for resending process 
     * @param relatedSendOuts List of related BulkEmailSend__c records to collect failures from
     * @return Set of failed Account IDs
     */
    private static Set<String> collectFailedAccountIdsFromRelatedRecords(List<BulkEmailSend__c> relatedSendOuts) {
        Set<String> failedAccountIds = new Set<String>();
        
            // Collect failed Account IDs from related records
            for (BulkEmailSend__c record : relatedSendOuts) {
            // Only process records that have failed batches stored
            if (String.isNotBlank(record.RemainingBatches__c)) {
                try {
                    List<String> accountIds = (List<String>) JSON.deserialize(record.RemainingBatches__c, List<String>.class);
                    for (String accountId : accountIds) {
                        if (String.isNotBlank(accountId)) {
                            failedAccountIds.add(accountId);
                        }
                    }
                } catch (Exception e) {
                    System.debug('BulkEmail: Error deserializing RemainingBatches__c from record ' + record.Id + ' - ' + e.getMessage());
                }
            }
        }
        System.debug('BulkEmail:Number of recipients to reattempt sendout: ' + failedAccountIds.size());
        
        return failedAccountIds;
    }
    
    
    
    /**
     * @description Publish Platform Events in batches of 10, handling errors and updating BulkEmailSend__c status
     * @param recipientChunks List of recipient chunks (List<List<RecipientWrapper>>). Outer list has no limit yet, but inner list has MAX 25 recipients.
     * @param bulkEmailSendRecords List of pre-created BulkEmailSend__c records (one per event)
     * @param bulkEmailSendGroupId The BulkEmailSendGroupId__c for linking related records
     * @param subject Email subject
     * @param body Email body
     */
    private static void publishPlatformEventsInBatches(
        List<List<RecipientWrapper>> recipientChunks,
        List<BulkEmailSend__c> bulkEmailSendRecords,
        String bulkEmailSendGroupId,
        String subject,
        String body) {
        
        Integer batchSequence = 1;
        Integer eventIndex = 0; // Index into bulkEmailSendRecords array
        Integer totalBatches = recipientChunks.size();
        
        
        // Split the totalBatches into lists of 10 batches, each containing up 25 recipients
        for (Integer i = 0; i < totalBatches; i += 10) {// Jump up 10 indexes to get the next 10 batches
            
            // Math.min() is used to handle scenarios where the last batch is less than 10
            List<List<RecipientWrapper>> eventChunks = new List<List<RecipientWrapper>>();
            for (Integer j = i; j < Math.min(i + 10, totalBatches); j++) {
                eventChunks.add(recipientChunks[j]);
            }
            
            // Convert RecipientWrapper batches to simplified format for Platform Events (only needed here for JSON serialization)
            List<List<Map<String, String>>> simplifiedBatches = convertRecipientsToSerializableFormat(eventChunks);
            
            // Serialize simplified batches to JSON (only id, email, workplace)
            String jsonBatches = JSON.serialize(simplifiedBatches);
            
            // Get the corresponding BulkEmailSend__c record for this batchSequence
            BulkEmailSend__c bulkEmailSendRecord = bulkEmailSendRecords[eventIndex];
            
            // Create Platform Event
            BulkEmailSendEvent__e platformEvent = new BulkEmailSendEvent__e(
                BulkEmailSendId__c = bulkEmailSendRecord.Id,
                BulkEmailSendGroupId__c = bulkEmailSendGroupId,
                BatchSequence__c = batchSequence,
                EmailBatches__c = jsonBatches,
                Subject__c = subject,
                Body__c = body
            );
            
            try {
                EventBus.publish(platformEvent);
                System.debug('BulkEmail: Published Platform Event with BatchSequence__c = ' + batchSequence + ', batches: ' + eventChunks.size());
            } catch (Exception e) {
                System.debug('BulkEmail: Error publishing Platform Event - ' + e.getMessage());
                // Update BulkEmailSend__c with error
                bulkEmailSendRecord.Status__c = 'Failed';
                bulkEmailSendRecord.CanResend__c = true;
                bulkEmailSendRecord.ErrorLog__c = 'Error publishing Platform Event: ' + e.getMessage();
                update bulkEmailSendRecord;
                throw new customException('Error publishing Platform Event: ' + e.getMessage());
            }
            
            batchSequence++;
            eventIndex++;
        }
    }
    
    /**
     * @description Trigger batched email send by processing recipients, creating BulkEmailSend__c records, and publishing Platform Events
     * @param validRecipients List of recipients to send to
     * @param accountId Account ID - Employer account ID, from where the email is sent
     * @param subject Email subject
     * @param body Email body
     * @param originalGroupId Original BulkEmailSendGroupId__c (null for new sends, existing ID for resends)
     * @param parentBulkEmailSendId Parent BulkEmailSend__c ID (null for new sends, existing ID for resends)
     * @param successMessagePrefix Prefix for success message
     * @param recipientLabel Label for recipients in success message (default: 'mottagare')
     * @return EmailResult with success status and BulkEmailSend__c ID
     */
    private static EmailResult triggerBatchedEmailSend(
        List<RecipientWrapper> validRecipients,
        String accountId,
        String subject,
        String body, 
        String originalGroupId,
        Id parentBulkEmailSendId) {
        
        // Generate unique BulkEmailSendGroupId__c for linking all related records
        String bulkEmailSendGroupId = generateBulkEmailSendGroupId(originalGroupId);
        
        // Log email sending activity
        System.debug('BulkEmail: Starting email send to ' + validRecipients.size() + ' recipients for account: ' + accountId);
        System.debug('BulkEmail: Generated BulkEmailSendGroupId__c: ' + bulkEmailSendGroupId);
        
        // Process recipients into batches
        List<List<RecipientWrapper>> recipientChunks = splitRecipientsIntoChunks(validRecipients);
        
        // Calculate how many Platform Events will be published (each event handles up to 10 batches, with 25 BCC recipients per batch)
        Integer totalBatches = recipientChunks.size();
        Integer numberOfEvents = (totalBatches + 9) / 10; // Round up division: (totalBatches + 9) / 10
        
        // Create all BulkEmailSend__c records upfront - one per Platform Event
        List<BulkEmailSend__c> bulkEmailSendRecords = createBulkEmailSendRecords(
            bulkEmailSendGroupId,
            accountId,
            subject,
            body,
            validRecipients.size(),
            parentBulkEmailSendId,
            numberOfEvents
        );
        
        // Publish Platform Events in batches of 10
        publishPlatformEventsInBatches(
            recipientChunks,
            bulkEmailSendRecords,
            bulkEmailSendGroupId,
            subject,
            body
        );
        
        // Return result with first BulkEmailSend__c ID and group ID for tracking, message in swedish as it is displayed to end user.
        String message = 'Mailet har placerats i kö för att skickas till ' + validRecipients.size() + ' mottagare';
        return new EmailResult(true, message, bulkEmailSendRecords[0].Id, true);
    }

    /**
     * @description Resend bulk email for failed or partial sends
     * @param bulkEmailSendId The ID of the BulkEmailSend__c record to resend
     * @return Result of the resend operation
     */
    public static EmailResult resendBulkEmail(String bulkEmailSendId) {
        try {
            if (String.isBlank(bulkEmailSendId)) {
                throw new customException('Bulk email send ID is required');
            }
            
            // Retrieve BulkEmailSend__c record
            List<BulkEmailSend__c> bulkEmailSends = [
                SELECT Id, BulkEmailSendGroupId__c, Status__c, CanResend__c,
                       Subject__c, Body__c, AccountId__c, RemainingBatches__c,
                       TotalRecipients__c, SuccessfulSends__c, FailedSends__c
                FROM BulkEmailSend__c
                WHERE Id = :bulkEmailSendId
                AND CanResend__c = true
                LIMIT 1
            ];
            
            if (bulkEmailSends.isEmpty()) {
                throw new customException('Bulk email send record not found');
            }
            
            BulkEmailSend__c mainRecord = bulkEmailSends[0];
            
            // Check CanResend__c flag
            if (!mainRecord.CanResend__c) {
                throw new customException('This bulk email send cannot be resent');
            }

            // Query all related BulkEmailSend__c records which is ready for resendwith same BulkEmailSendGroupId__c 
            List<BulkEmailSend__c> relatedSendOuts = [
                SELECT Id, Status__c, RemainingBatches__c, BatchSequence__c, CanResend__c
                FROM BulkEmailSend__c
                WHERE BulkEmailSendGroupId__c = :mainRecord.BulkEmailSendGroupId__c
                AND CanResend__c = true
                ORDER BY BatchSequence__c ASC
            ];

            System.debug('BulkEmail:Number of related SendOuts: ' + relatedSendOuts.size());
            
            // Collect all failed Account IDs from all related records using helper method
            Set<String> failedAccountIds = collectFailedAccountIdsFromRelatedRecords(relatedSendOuts);            
            // Check if we have any failed Account IDs to resend
            if (failedAccountIds.isEmpty()) {
                // No specific failed batches tracked, cannot resend
                throw new customException('No failed recipient batches to resend. All recipient batches were successfully processed or no failed recipient batches are tracked in RemainingBatches__c.');
            }
           
            List<RecipientWrapper> failedRecipients = new List<RecipientWrapper>();
             
            // Query Account records to get PersonEmail for failed Account IDs
            for(Account acc : [SELECT Id, PersonEmail FROM Account WHERE Id IN :failedAccountIds and IsPersonAccount = true and PersonEmail != null]) {
                failedRecipients.add(new RecipientWrapper(acc.Id, null, acc.PersonEmail, null, null, null));
            }
            
            // Check if we have any valid recipients after querying
            if (failedRecipients.isEmpty()) {
                throw new customException('No valid recipients found for failed Account IDs. Email addresses may be missing.');
            }
            
            // Update all related BulkEmailSend__c records to mark them as 'Resent'
            // Clear RemainingBatches__c, set CanResend__c = false, and Status__c = 'Resent'
            for (BulkEmailSend__c record : relatedSendOuts) {
                record.RemainingBatches__c = null; // Clear since failures are now processed in new record
                record.CanResend__c = false; // Cannot be resent again from these records
                record.Status__c = 'Resent'; // Indicates they've been resent
            }
            
            try {
                update relatedSendOuts;
                System.debug('BulkEmail: Updated ' + relatedSendOuts.size() + ' related records to Resent status');
            } catch (Exception e) {
                System.debug('BulkEmail: Error updating related records to Resent status - ' + e.getMessage());
                // Continue with resend even if update fails - don't fail the resend operation
            }
            
            // Trigger batched email send using helper method
            return triggerBatchedEmailSend(
                failedRecipients,
                mainRecord.AccountId__c,
                mainRecord.Subject__c,
                mainRecord.Body__c,
                mainRecord.BulkEmailSendGroupId__c, // originalGroupId - for resend
                mainRecord.Id // parentBulkEmailSendId - link to original record
            );
            
        } catch (Exception e) {
            System.debug('BulkEmail: Error resending email: ' + e.getMessage());
            throw new customException('Error resending email: ' + e.getMessage());
        }
    }
    
    /**
     * @description Invocable method wrapper for resending bulk emails from Flow
     * @param bulkEmailSendIds List of BulkEmailSend__c record IDs to resend
     * @return List of EmailResult
     */
    @InvocableMethod(label='Resend Bulk Email' description='Resends failed bulk email batches')
    public static List<EmailResult> resendBulkEmailInvocable(List<String> bulkEmailSendIds) {
        List<EmailResult> results = new List<EmailResult>();
        
        for (String bulkEmailSendId : bulkEmailSendIds) {
            try {
                EmailResult result = resendBulkEmail(bulkEmailSendId);
                results.add(result);
            } catch (Exception e) {
                results.add(new EmailResult(false, 'Error: ' + e.getMessage(), e.getMessage()));
            }
        }
        
        return results;
    }
    
    /**
     * @description Result class for email sending operations
     */
    public class EmailResult {
        @AuraEnabled @InvocableVariable public Boolean success;
        @AuraEnabled @InvocableVariable public String message;
        @AuraEnabled @InvocableVariable public String error;
        @AuraEnabled @InvocableVariable public String bulkEmailSendId; // ID of BulkEmailSend__c record for tracking
        
        // No-argument constructor required for JSON deserialization
        public EmailResult() {
        }
        
        public EmailResult(Boolean success, String message, String error) {
            this.success = success;
            this.message = message;
            this.error = error;
            this.bulkEmailSendId = null;
        }
        
        public EmailResult(Boolean success, String message) {
            this.success = success;
            this.message = message;
            this.error = null;
            this.bulkEmailSendId = null;
        }
        
        public EmailResult(Boolean success, String message, String bulkEmailSendId, Boolean isBulkId) {
            this.success = success;
            this.message = message;
            this.error = null;
            this.bulkEmailSendId = bulkEmailSendId;
        }
    }
    
    /**
     * @description Wrapper class for paginated results
     */
    public class PaginatedResult {
        @AuraEnabled public List<RecipientWrapper> records;
        @AuraEnabled public Integer totalRecords;
        @AuraEnabled public Integer totalPages;
        @AuraEnabled public Integer currentPage;
        @AuraEnabled public Integer pageSize;
        @AuraEnabled public Boolean hasNextPage;
        @AuraEnabled public Boolean hasPreviousPage;
        
        // No-argument constructor required for JSON deserialization
        public PaginatedResult() {
        }
        
        public PaginatedResult(List<RecipientWrapper> records, Integer totalRecords, Integer totalPages, 
                              Integer currentPage, Integer pageSize) {
            this.records = records;
            this.totalRecords = totalRecords;
            this.totalPages = totalPages;
            this.currentPage = currentPage;
            this.pageSize = pageSize;
            this.hasNextPage = currentPage < totalPages;
            this.hasPreviousPage = currentPage > 1;
        }
    }
     /**
     * @description Get email addresses from a chunk of recipients
     * @param chunk List of recipient wrappers
     * @return List of email addresses
     */
    // private static List<String> getEmailAddressesFromRecipients(List<RecipientWrapper> chunk) {
    //     List<String> emailAddresses = new List<String>();
    //     for (RecipientWrapper recipient : chunk) {
    //         emailAddresses.add(recipient.email);
    //     }
    //     return emailAddresses;
    // }
    
    
    // /**
    //  * @description Get email attachments from ContentDocument IDs
    //  * @param attachmentIds List of ContentDocument IDs
    //  * @return List of email file attachments
    //  */
    // private static List<Messaging.EmailFileAttachment> getEmailAttachments(List<String> attachmentIds) {
    //     List<Messaging.EmailFileAttachment> attachments = new List<Messaging.EmailFileAttachment>();
        
    //     try {
    //         List<ContentVersion> contentVersions = [
    //             SELECT Id, Title, FileExtension, VersionData, ContentDocumentId
    //             FROM ContentVersion 
    //             WHERE ContentDocumentId IN :attachmentIds 
    //             AND IsLatest = true
    //         ];
            
    //         for (ContentVersion cv : contentVersions) {
    //             Messaging.EmailFileAttachment attachment = new Messaging.EmailFileAttachment();
    //             attachment.setFileName(cv.Title + '.' + cv.FileExtension);
    //             attachment.setBody(cv.VersionData);
    //             attachments.add(attachment);
    //         }
    //     } catch (Exception e) {
    //         // Error retrieving attachments, return empty list
    //     }
        
    //     return attachments;
    // }

     /**
     * @description Get file size for a single ContentDocument
     * @param documentId ContentDocument ID
     * @return File size in bytes
     */
    // @AuraEnabled
    // public static Integer getFileSize(String documentId) {
    //     try {
    //         List<ContentVersion> contentVersions = [
    //             SELECT ContentSize
    //             FROM ContentVersion 
    //             WHERE ContentDocumentId = :documentId 
    //             AND IsLatest = true
    //             LIMIT 1
    //         ];
            
    //         if (!contentVersions.isEmpty() && contentVersions[0].ContentSize != null) {
    //             return contentVersions[0].ContentSize;
    //         }
            
    //         return 0;
    //     } catch (Exception e) {
    //         System.debug('BulkEmail: Error getting file size for document ' + documentId + ': ' + e.getMessage());
    //         return 0;
    //     }
    // }

    // /**
    //  * @description Get total size of all attachments
    //  * @param attachmentIds List of ContentDocument IDs
    //  * @return Total size in bytes
    //  */
    // private static Integer getTotalAttachmentSize(List<String> attachmentIds) {
    //     Integer totalSize = 0;
        
    //     try {
    //         List<ContentVersion> contentVersions = [
    //             SELECT ContentSize
    //             FROM ContentVersion 
    //             WHERE ContentDocumentId IN :attachmentIds 
    //             AND IsLatest = true
    //         ];
            
    //         for (ContentVersion cv : contentVersions) {
    //             if (cv.ContentSize != null) {
    //                 totalSize += cv.ContentSize;
    //             }
    //         }
    //     } catch (Exception e) {
    //         System.debug('BulkEmail: Error calculating attachment size - ' + e.getMessage());
    //     }
        
    //     return totalSize;
    // }

    //  /**
    //  * @description Get ContentVersion IDs from ContentDocument IDs
    //  * @param attachmentIds List of ContentDocument IDs
    //  * @return List of ContentVersion IDs
    //  */
    // private static List<Id> getContentVersionIds(List<String> attachmentIds) {
    //     List<Id> contentVersionIds = new List<Id>();
        
    //     try {
    //         List<ContentVersion> contentVersions = [
    //             SELECT Id
    //             FROM ContentVersion 
    //             WHERE ContentDocumentId IN :attachmentIds 
    //             AND IsLatest = true
    //         ];
            
    //         for (ContentVersion cv : contentVersions) {
    //             contentVersionIds.add(cv.Id);
    //         }
    //     } catch (Exception e) {
    //         System.debug('BulkEmail: Error retrieving ContentVersion IDs - ' + e.getMessage());
    //     }
        
    //     return contentVersionIds;
    // }
}