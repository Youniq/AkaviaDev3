/**
 * @description Handler for BulkEmailSendEvent__e platform events to send emails asynchronously
 * @author AI Assistant
 * @group Bulk Email
**/
public without sharing class BulkEmailSendEventTriggerHandler {
    
    /**
     * @description Process platform events and send emails
     * @param events List of BulkEmailSendEvent__e platform events
     */
    public void processEvents(List<BulkEmailSendEvent__e> events) {
        System.debug('BulkEmailSend TriggerHandler: Processing ' + events.size() + ' events');
        for (BulkEmailSendEvent__e event : events) {
            try {
                processSingleEvent(event);
            } catch (Exception e) {
                System.debug('BulkEmailSendEvent: Error processing event - ' + e.getMessage());
                handleAllBatchesFailed(event, e);
            }
        }
    }
    
    /**
     * @description Process a single platform event
     * @param event BulkEmailSendEvent__e platform event
     */
    private void processSingleEvent(BulkEmailSendEvent__e event) {
        // Deserialize email batches from JSON
        // event.EmailBatches__c = 1 list, containing MAX 10 lists, each containing MAX 25 recipients
        List<List<RecipientWrapper>> emailBatches = deserializeEmailBatches(event.EmailBatches__c);
        
        // Get BulkEmailSend__c record (should always exist as records are created in the BulkEmailController)
        // Returns null if record not found and retry has been queued
        BulkEmailSend__c bulkEmailSend = getBulkEmailSend(event);
        
        // If null, retry has been queued - skip processing in this transaction
        if (bulkEmailSend == null) {
            System.debug('BulkEmailSendEvent: Record not found, retry queued. Skipping processing for this event.');
            return;
        }
        
        // Continue processing with the record
        processEventWithRecord(event, bulkEmailSend);
    }
    
    /**
     * @description Process a platform event with a pre-fetched BulkEmailSend__c record
     * This method is called directly or via retry Queueable
     * @param event BulkEmailSendEvent__e platform event
     * @param bulkEmailSend BulkEmailSend__c record
     */
    public void processEventWithRecord(BulkEmailSendEvent__e event, BulkEmailSend__c bulkEmailSend) {
        // Deserialize email batches from JSON
        List<List<RecipientWrapper>> emailBatches = deserializeEmailBatches(event.EmailBatches__c);
        
        // Validate event constraints: MAX 10 batches, MAX 25 recipients per batch
        // If validation fails, an exception is thrown 
        validateEventBatches(emailBatches, bulkEmailSend);
        
        // Update status to 'In Progress' when processing begins
        if (bulkEmailSend.Status__c == 'Queued') {
            bulkEmailSend.Status__c = 'In Progress';
            try {
                update bulkEmailSend;
            } catch (Exception e) {
                System.debug('BulkEmailSendEvent: Error updating status to In Progress - ' + e.getMessage());
                // Continue processing even if status update fails
            }
        }
        
        // Send emails (MAX 10 per transaction)
        // Validation ensures we always receive MAX 10 batches, so we process all of them
        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();
        List<List<RecipientWrapper>> batchRecipientsList = new List<List<RecipientWrapper>>();
        
        // Process all batches (validation ensures MAX 10 batches)
        for (Integer i = 0; i < emailBatches.size(); i++) {
            List<RecipientWrapper> recipients = emailBatches[i];
            System.debug('TriggerHandler: Batch: ' + recipients);
            Messaging.SingleEmailMessage email = createEmailMessage(recipients, event.Subject__c, event.Body__c);
            emails.add(email);
            batchRecipientsList.add(recipients);
        }
        
        // Send emails
        Messaging.SendEmailResult[] results;
        try {
            // false = do not fail all emails if one fails
            results = Messaging.sendEmail(emails, false);
            System.debug('BulkEmailSendEvent: Sent ' + emails.size() + ' email messages');
        } catch (Exception emailException) {
            System.debug('BulkEmailSendEvent: Failed to send emails - ' + emailException.getMessage());
            // Mark all event batches as failed (error occurred during email sendout)
            handleAllBatchesFailed(event, emailException);
            return;
        }
        
        // Process results and create tasks
        // IMPORTANT: SendEmailResult.isSuccess() is all-or-nothing per email message:
        // - isSuccess() = true: Email was submitted for delivery, ALL recipients succeeded, errors list is empty
        // - isSuccess() = false: Email failed to send, ALL recipients failed, no partial success
        // There is no partial success for individual recipients within a single email message
        Integer successCount = 0;
        Integer failureCount = 0;
        List<RecipientWrapper> successfulRecipients = new List<RecipientWrapper>();
        List<List<RecipientWrapper>> failedBatches = new List<List<RecipientWrapper>>(); // Track failed batches for resend
        String errorMessages = '';
        
        // Process each email send result
        for (Integer i = 0; i < results.size(); i++) {
            Messaging.SendEmailResult result = results[i];
            List<RecipientWrapper> batch = batchRecipientsList[i];
            
            System.debug('BulkEmailSendEvent: IsSuccess?: ' + result.isSuccess());
            
            if (!result.isSuccess()) {
                // isSuccess() = false: Entire email message failed, all recipients failed
                failureCount += batch.size();
                failedBatches.add(batch); // Store entire batch for resend
                
                // Collect error messages for logging
                List<Messaging.SendEmailError> errors = result.getErrors();
                errorMessages += collectErrorMessages(errors);
            } else {
                // isSuccess() = true: Email was submitted for delivery, all recipients succeeded
                // Errors list will be empty when isSuccess() is true
                successCount += batch.size();
                successfulRecipients.addAll(batch);
            }
        }
        
        // Create Task records for successful sends
        if (!successfulRecipients.isEmpty() && bulkEmailSend.AccountId__c != null) {
            String employerName = getEmployerName(String.valueOf(bulkEmailSend.AccountId__c));
            
            // Convert RecipientWrapper to BulkEmailController.RecipientWrapper
            // Note: Only id and workplace are needed for Task creation, name fields not required
            List<BulkEmailController.RecipientWrapper> controllerRecipients = new List<BulkEmailController.RecipientWrapper>();
            for (RecipientWrapper rw : successfulRecipients) {
                controllerRecipients.add(new BulkEmailController.RecipientWrapper(
                    rw.id, 
                    null, // name not needed for Task
                    rw.email, 
                    null, // firstName not needed for Task
                    null, // lastName not needed for Task
                    rw.workplace
                ));
            }
            
            if (!controllerRecipients.isEmpty()) {
                List<Task> recipientTasks = BulkEmailController.createRecipientTasks(
                    controllerRecipients, 
                    event.Subject__c, 
                    event.Body__c, 
                    null, // No attachments, not added for version 1
                    String.valueOf(bulkEmailSend.AccountId__c), 
                    employerName
                );
                try {
                    insert recipientTasks;
                    System.debug('BulkEmailSendEvent: Created ' + recipientTasks.size() + ' Task records');
                } catch (Exception taskException) {
                    System.debug('BulkEmailSendEvent: Failed to insert Task records - ' + taskException.getMessage());
                }
            }
        }
        
        // Update BulkEmailSend__c record
        updateBulkEmailSendWithResults(bulkEmailSend, successCount, failureCount, errorMessages, failedBatches);
    }
    
    /**
     * @description Deserialize email batches from JSON. The format is: List<List<Map<String, String>>>,
     *  where the outer list contains MAX 10 lists, each containing MAX 25 recipients.
     * Must perform a manual deserialization to handle the nested structure.
     * @param jsonBatches JSON string containing email batches
     * @return List of RecipientWrapper batches
     */
    private List<List<RecipientWrapper>> deserializeEmailBatches(String jsonBatches) {
        if (String.isBlank(jsonBatches)) {
            return new List<List<RecipientWrapper>>();
        }
        
        try {
            // Parse JSON: List<List<Map<String, Object>>>
            // Outer list contains MAX 10 lists (10 emails), each containing MAX 25 recipients
            List<Object> outerList = (List<Object>) JSON.deserializeUntyped(jsonBatches);
            List<List<RecipientWrapper>> batches = new List<List<RecipientWrapper>>();
            
            for (Object outerObj : outerList) {
                // Inner list contains MAX 25 recipients
                List<Object> innerList = (List<Object>) outerObj;
                // batch represents the finished parsed list of recipients (25 recipients)
                List<RecipientWrapper> batch = new List<RecipientWrapper>();
                
                for (Object obj : innerList) {
                    Map<String, Object> recipientMap = (Map<String, Object>) obj;
                    String id = (String) recipientMap.get('id');
                    String email = (String) recipientMap.get('email');
                    String workplace = (String) recipientMap.get('workplace');
                    
                    // Only add recipient if id and email are not null/blank
                    if (String.isNotBlank(id) && String.isNotBlank(email)) {
                        RecipientWrapper recipient = new RecipientWrapper(id, email, workplace);
                        batch.add(recipient);
                    }
                }
                batches.add(batch);
            }
            
            return batches;
        } catch (Exception e) {
            System.debug('BulkEmailSendEvent: Error deserializing batches - ' + e.getMessage());
            return new List<List<RecipientWrapper>>();
        }
    }
    
    /**
     * @description Validate event batches against constraints: MAX 10 batches, MAX 25 recipients per batch
     * If validation fails, updates BulkEmailSend__c record with error status and returns false to end the transaction
     * @param emailBatches List of email batches to validate
     * @param bulkEmailSend BulkEmailSend__c record to update if validation fails
     * @return Boolean - true if validation passes, false if validation fails (transaction should end)
     */
    private Boolean validateEventBatches(List<List<RecipientWrapper>> emailBatches, BulkEmailSend__c bulkEmailSend) {
        Boolean isValid = true;
        String errorMsg = '';

        if (emailBatches == null || emailBatches.isEmpty()) {
            errorMsg = 'Invalid event: No email recipients found in event';
            isValid = false;
        }
        
        // Validate MAX 10 batches constraint
        if (isValid && emailBatches.size() > 10) {
            errorMsg = 'Invalid event: Received ' + emailBatches.size() + ' batches, maximum allowed is 10';
            isValid = false;
        }
        
        // If validation passes, validate each batch has MAX 25 recipients
        if(isValid) {
            // Validate each batch has MAX 25 recipients
            for (Integer i = 0; i < emailBatches.size(); i++) {
                List<RecipientWrapper> batch = emailBatches[i];
                if (batch != null && batch.size() > 25) {
                    errorMsg = 'Invalid event: Batch ' + (i + 1) + ' contains ' + batch.size() + ' recipients, maximum allowed is 25';
                        isValid = false;
                        break;
                    
                }
            }
        }

        if (!isValid) {
            throw new customException(errorMsg);
           // markBulkEmailSendAsFailed(bulkEmailSend, errorMsg, emailBatches);
           // return false;
        }
        
        // All validations passed
        return true;
    }
    
    /**
     * @description Extract Account IDs from RecipientWrapper batches
     * @param batches List of RecipientWrapper batches
     * @return Set of Account IDs extracted from all batches
     */
    private Set<String> extractAccountIdsFromBatches(List<List<RecipientWrapper>> batches) {
        Set<String> accountIds = new Set<String>();
        if (batches != null && !batches.isEmpty()) {
            for (List<RecipientWrapper> batch : batches) {
                if (batch != null && !batch.isEmpty()) {
                    for (RecipientWrapper rw : batch) {
                        if (rw != null && String.isNotBlank(rw.id)) {
                            accountIds.add(rw.id);
                        }
                    }
                }
            }
        }
        return accountIds;
    }
    
    /**
     * @description Mark BulkEmailSend__c record as failed with resend capability
     * @param bulkEmailSend BulkEmailSend__c record to update
     * @param errorMsg Error message to log (replaces existing ErrorLog__c)
     * @param batches Optional list of RecipientWrapper batches to extract Account IDs from for RemainingBatches__c
     */
    private void markBulkEmailSendAsFailed(BulkEmailSend__c bulkEmailSend, String errorMsg, List<List<RecipientWrapper>> batches) {
        System.debug('BulkEmailSendEvent: ' + errorMsg);
        bulkEmailSend.Status__c = 'Failed';
        bulkEmailSend.CanResend__c = batches != null && !batches.isEmpty() ? true : false;

         // Preserve existing error log and combine with new error message
        String existingErrorLog = bulkEmailSend.ErrorLog__c != null ? bulkEmailSend.ErrorLog__c : '';
        bulkEmailSend.ErrorLog__c = existingErrorLog + '\n' + errorMsg;
        
        // Extract Account IDs from batches if provided
        if (batches != null && !batches.isEmpty()) {
            Set<String> failedAccountIds = extractAccountIdsFromBatches(batches);
            bulkEmailSend.RemainingBatches__c = serializeAccountIds(failedAccountIds);
        } else {
            // If no batches provided, clear RemainingBatches__c
            bulkEmailSend.RemainingBatches__c = null;
        }
        
        try {
            update bulkEmailSend;
        } catch (Exception e) {
            ApexLog.createLogDebug(New ApexLog.Error('BulkEmailSendEventTriggerHandler', 'markBulkEmailSendAsFailed', true, e));
        }
    }
    
    /**
     * @description Serialize Account IDs for RemainingBatches__c field
     * @param accountIds Set of Account IDs to serialize
     * @return JSON string of Account IDs, or null if empty
     */
    private String serializeAccountIds(Set<String> accountIds) {
        if (accountIds == null || accountIds.isEmpty()) {
            return null;
        }
        return JSON.serialize(new List<String>(accountIds));
    }
    
    /**
     * @description Collect error messages from SendEmailError list
     * @param errors List of Messaging.SendEmailError
     * @return Concatenated error messages separated by '; '
     */
    private String collectErrorMessages(List<Messaging.SendEmailError> errors) {
        String errorMessages = '';
        if (errors != null && !errors.isEmpty()) {
            for (Messaging.SendEmailError error : errors) {
                String errorMsg = error.getMessage();
                System.debug('BulkEmailSendEvent: Found Error message: ' + errorMsg);
                System.debug('BulkEmailSendEvent: Error code: ' + error.getStatusCode());
                System.debug('BulkEmailSendEvent: Error fields: ' + error.getFields());
                System.debug('BulkEmailSendEvent: TargetObjectId: ' + error.getTargetObjectId());
                errorMessages += errorMsg + '; ';
            }
        }
        return errorMessages;
    }
    
    /**
     * @description Get BulkEmailSend__c record. Record should always exist as it's created upfront in the Controller.
     * @param event Platform event
     * @return BulkEmailSend__c record
     * @throws customException if record is not found (data integrity issue)
     */
    private BulkEmailSend__c getBulkEmailSend(BulkEmailSendEvent__e event) {

        if (event == null || String.isBlank(event.BulkEmailSendId__c)) {
            String errorMsg = 'Invalid event: BulkEmailSendId__c is null or blank. ' +
                             'GroupId: ' + (event != null ? event.BulkEmailSendGroupId__c : 'null') + 
                             ', BatchSequence: ' + (event != null ? String.valueOf(event.BatchSequence__c) : 'null');
            System.debug('BulkEmailSendEvent: ' + errorMsg);
            throw new customException(errorMsg);
        }

        // Validate and cast to Id type for proper SOQL comparison
        Id bulkEmailSendId;
        try {
            bulkEmailSendId = Id.valueOf(event.BulkEmailSendId__c.trim());
        } catch (Exception e) {
            String errorMsg = 'Invalid BulkEmailSendId__c format: "' + event.BulkEmailSendId__c + '". ' +
                             'GroupId: ' + event.BulkEmailSendGroupId__c + 
                             ', BatchSequence: ' + event.BatchSequence__c;
            System.debug('BulkEmailSendEvent: ' + errorMsg);
            throw new customException(errorMsg);
        }

        System.debug('BulkEmailSendEvent: Getting BulkEmailSend__c record for Id: ' + bulkEmailSendId + 
                    ', GroupId: ' + event.BulkEmailSendGroupId__c + ', BatchSequence: ' + event.BatchSequence__c);
        
        // Query for existing record by ID - it should always exist as records are created upfront
        List<BulkEmailSend__c> records = [
            SELECT Id, Status__c, AccountId__c, Subject__c, Body__c,
                   TotalRecipients__c, SuccessfulSends__c, FailedSends__c,
                   ErrorLog__c, BatchSequence__c, BulkEmailSendGroupId__c,
                   ParentBulkEmailSendId__c, RemainingBatches__c, CanResend__c
            FROM BulkEmailSend__c
            WHERE Id = :bulkEmailSendId
            LIMIT 1
        ];
        
        if (records.isEmpty()) {
            // Record not found - likely a transaction timing issue with Platform Events
            // Queue a retry via Queueable which will run after the current transaction commits
            System.debug('BulkEmailSendEvent: Record not found for Id: ' + bulkEmailSendId + 
                        ', queueing retry. GroupId: ' + event.BulkEmailSendGroupId__c + 
                        ', BatchSequence: ' + event.BatchSequence__c);
            
            // Queue retry - this will execute after the publishing transaction commits
            System.enqueueJob(new BulkEmailSendEventRetryQueueable(event, 1));
            
            // Return null to signal that processing should be skipped (will be handled by retry)
            return null;
        }
        
        return records[0];
    }
    
    /**
     * @description Create email message from recipient batch
     * @param batch List of recipients
     * @param subject Email subject
     * @param body Email body
     * @return Messaging.SingleEmailMessage
     */
    private Messaging.SingleEmailMessage createEmailMessage(List<RecipientWrapper> batch, String subject, String body) {
        Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
        
        // Create BCC addresses
        List<String> bccAddresses = new List<String>();
        for (RecipientWrapper recipient : batch) {
            bccAddresses.add(recipient.email);
        }
        email.setBccAddresses(bccAddresses);
        email.setSubject(subject);
        email.setHtmlBody(body);
        
        // Set org-wide email address
        email.setReplyTo(getOrgWideEmailAddress()); // Setting reply to address to the noreply address to avoid responses.
        if (UserInfo.getUserEmail().contains('@akavia.se')) {
            email.setSenderDisplayName(UserInfo.getName()); // Set sender display name for Akavia users
        } else {
            String orgWideEmailId = getOrgWideEmailAddressId(); // Get org-wide email address ID
           if (orgWideEmailId != null) {
            // Cannot use setOrgWideEmailAddressId() in combination with setSenderDisplayName()
                email.setOrgWideEmailAddressId(orgWideEmailId); // Set org-wide email address for sender
            } else {
                throw new customException('No org-wide email address found to use as sender');
            }
        }
        
        return email;
    }
    
 /**
     * @description Get org-wide email address ID
     * @return Org-wide email address ID
     */
    private static String getOrgWideEmailAddressId() {
        try {
            // Try to get configured email address from custom metadata
            String emailAddress = getOrgWideEmailAddress();
           
            // Try to find org-wide email matching configured address
            List<OrgWideEmailAddress> orgWideEmails = [
                SELECT Id 
                FROM OrgWideEmailAddress 
                WHERE Address = :emailAddress
                LIMIT 1
            ];
            
            if (!orgWideEmails.isEmpty()) {
                System.debug('Found org-wide email for configured address: ' + emailAddress);
                return orgWideEmails[0].Id;
            }

            return null;
        } catch (Exception e) {
            System.debug('Error getting org-wide email address: ' + e.getMessage());
            return null;
        }
    }
    
    /**
     * @description Get org-wide email address for noreply address.
     * @return Org-wide email address
     */
    private static String getOrgWideEmailAddress() {
            Flow_Email_Address__mdt emailSettings = Flow_Email_Address__mdt.getInstance('Flow_Email_Addresses');
            if (emailSettings != null && String.isNotBlank(emailSettings.No_Reply_Email_Address__c)) {
                return emailSettings.No_Reply_Email_Address__c;
            } else {
                return 'noreply@akavia.se'; // Fallback to default noreply address if configured one not found
            }
    }
    
    /**
     * @description Update BulkEmailSend__c with results
     * @param bulkEmailSend BulkEmailSend__c record to update
     * @param successCount Number of successful sends
     * @param failureCount Number of failed sends
     * @param errorMessages Error messages
     * @param failedBatches List of failed batches to store for resend
     */
    private void updateBulkEmailSendWithResults(BulkEmailSend__c bulkEmailSend, Integer successCount, 
                                               Integer failureCount, String errorMessages, 
                                               List<List<RecipientWrapper>> failedBatches) {
        bulkEmailSend.SuccessfulSends__c = (bulkEmailSend.SuccessfulSends__c != null ? bulkEmailSend.SuccessfulSends__c : 0) + successCount;
        bulkEmailSend.FailedSends__c = (bulkEmailSend.FailedSends__c != null ? bulkEmailSend.FailedSends__c : 0) + failureCount;
        
        if (failureCount > 0) {
            String existingErrorLog = bulkEmailSend.ErrorLog__c != null ? bulkEmailSend.ErrorLog__c : '';
            bulkEmailSend.ErrorLog__c = existingErrorLog + '\n' + errorMessages;
            bulkEmailSend.Status__c = successCount > 0 ? 'Partial Success' : 'Failed';
            bulkEmailSend.CanResend__c = true;
            
            // Store only Account IDs from failed batches for resend (most recent failures only)
            Set<String> failedAccountIds = extractAccountIdsFromBatches(failedBatches);
            
            // Store only the most recent failures (replace, don't accumulate)
            bulkEmailSend.RemainingBatches__c = serializeAccountIds(failedAccountIds);
        } else if (successCount > 0 && failureCount == 0) {
            bulkEmailSend.Status__c = 'Completed';
            // Clear RemainingBatches__c since all recipients succeeded
            bulkEmailSend.RemainingBatches__c = null;
        }
        
        bulkEmailSend.SentOn__c = System.now();
        
        try {
            update bulkEmailSend;
            System.debug('BulkEmailSendEvent: Updated BulkEmailSend__c record - Status: ' + bulkEmailSend.Status__c + ', Success: ' + successCount + ', Failed: ' + failureCount);
        } catch (Exception e) {
            ApexLog.createLogDebug(New ApexLog.Error('BulkEmailSendEventTriggerHandler', 'updateBulkEmailSendWithResults', true, e));
            // Log error but don't fail - this ensures processing continues
        }
    }
    
    /**
     * @description Handle all batches failed - marks ALL event batches as failed
     * This method handles errors occurring before email sendout is attempted
     * It extracts all Account IDs from all batches in the event and marks them as failed
     * @param event Platform event that failed
     * @param e Exception that occurred
     */
    private void handleAllBatchesFailed(BulkEmailSendEvent__e event, Exception e) {
        try {
            // Query the BulkEmailSend__c record using BulkEmailSendId__c (most reliable)
            List<BulkEmailSend__c> records = [
                SELECT Id, RemainingBatches__c, Status__c, CanResend__c, ErrorLog__c, FailedSends__c, SuccessfulSends__c
                FROM BulkEmailSend__c
                WHERE Id = :event.BulkEmailSendId__c
                LIMIT 1
            ];
            
            if (!records.isEmpty()) {
                BulkEmailSend__c bulkEmailSend = records[0];
                
                String error = 'Error: ' + e.getMessage() + 
                              '\nBulkEmailSendId: ' + event.BulkEmailSendId__c +
                              '\nGroupId: ' + event.BulkEmailSendGroupId__c + 
                              '\nBatchSequence: ' + event.BatchSequence__c +
                              '\nStack: ' + e.getStackTraceString();
                
                // Mark ALL event batches as failed (error occurred before/during email sendout)
                // Extract all Account IDs from all batches in the event
                List<List<RecipientWrapper>> recipientBatches = null;
                if (String.isNotBlank(event.EmailBatches__c)) {
                    try {
                        recipientBatches = deserializeEmailBatches(event.EmailBatches__c);
                    } catch (Exception deserializeException) {
                        System.debug('BulkEmailSendEvent: Error deserializing event batches - ' + deserializeException.getMessage());
                        // If deserialization fails, continue without batches
                    }
                }
                
                // Use unified helper method to mark as failed
                markBulkEmailSendAsFailed(bulkEmailSend, error, recipientBatches);
            } else {
                // Record not found - log detailed error for debugging
                String notFoundError = 'BulkEmailSend__c record not found in handleAllBatchesFailed. ' +
                                      'BulkEmailSendId: ' + event.BulkEmailSendId__c + 
                                      ', GroupId: ' + event.BulkEmailSendGroupId__c + 
                                      ', BatchSequence: ' + event.BatchSequence__c +
                                      '. Original error: ' + e.getMessage();
                System.debug('BulkEmailSendEvent: ' + notFoundError);
                ApexLog.createLogDebug(New ApexLog.Error('BulkEmailSendEventTriggerHandler', 'handleAllBatchesFailed', true, new customException(notFoundError)));
            }
        } catch (Exception ex) {
            ApexLog.createLogDebug(New ApexLog.Error('BulkEmailSendEventTriggerHandler', 'handleAllBatchesFailed', true, ex));
        }
    }  
    
    /**
     * @description Get employer name
     * @param accountId Account ID
     * @return Employer name
     */
    private String getEmployerName(String accountId) {
        if (String.isBlank(accountId)) {
            return '';
        }
        
        try {
            Account employer = [SELECT Name FROM Account WHERE Id = :accountId LIMIT 1];
            return employer.Name;
        } catch (Exception e) {
            System.debug('BulkEmailSendEvent: Error getting employer name - ' + e.getMessage());
            return '';
        }
    }
    
    /**
     * @description Wrapper class for recipient data (simplified - only id, email, workplace for Platform Event)
     */
    public class RecipientWrapper {
        public String id;
        public String email;
        public String workplace;
        
        public RecipientWrapper(String id, String email, String workplace) {
            this.id = id;
            this.email = email;
            this.workplace = workplace != null ? workplace : '';
        }
    }
    
    /**
     * @description Queueable class to retry processing a Platform Event when BulkEmailSend__c record 
     * is not immediately available due to transaction timing issues
     */
    public class BulkEmailSendEventRetryQueueable implements Queueable {
        private String bulkEmailSendId;
        private String bulkEmailSendGroupId;
        private Decimal batchSequence;
        private String emailBatches;
        private String subject;
        private String body;
        private Integer retryCount;
        private final Integer MAX_RETRIES = 3;
        
        public BulkEmailSendEventRetryQueueable(BulkEmailSendEvent__e event, Integer retryCount) {
            this.bulkEmailSendId = event.BulkEmailSendId__c;
            this.bulkEmailSendGroupId = event.BulkEmailSendGroupId__c;
            this.batchSequence = event.BatchSequence__c;
            this.emailBatches = event.EmailBatches__c;
            this.subject = event.Subject__c;
            this.body = event.Body__c;
            this.retryCount = retryCount;
        }
        
        public void execute(QueueableContext context) {
            System.debug('BulkEmailSendEventRetry: Retry attempt ' + retryCount + ' for BulkEmailSendId: ' + bulkEmailSendId);
            
            try {
                // Query for the record
                List<BulkEmailSend__c> records = [
                    SELECT Id, Status__c, AccountId__c, Subject__c, Body__c,
                           TotalRecipients__c, SuccessfulSends__c, FailedSends__c,
                           ErrorLog__c, BatchSequence__c, BulkEmailSendGroupId__c,
                           ParentBulkEmailSendId__c, RemainingBatches__c, CanResend__c
                    FROM BulkEmailSend__c
                    WHERE Id = :bulkEmailSendId
                    LIMIT 1
                ];
                
                if (records.isEmpty()) {
                    // Record still not found
                    if (retryCount < MAX_RETRIES) {
                        // Queue another retry
                        System.debug('BulkEmailSendEventRetry: Record still not found, queueing retry ' + (retryCount + 1));
                        BulkEmailSendEvent__e retryEvent = new BulkEmailSendEvent__e(
                            BulkEmailSendId__c = bulkEmailSendId,
                            BulkEmailSendGroupId__c = bulkEmailSendGroupId,
                            BatchSequence__c = batchSequence,
                            EmailBatches__c = emailBatches,
                            Subject__c = subject,
                            Body__c = body
                        );
                        System.enqueueJob(new BulkEmailSendEventRetryQueueable(retryEvent, retryCount + 1));
                    } else {
                        // Max retries reached, log error
                        String errorMsg = 'BulkEmailSend__c record not found after ' + MAX_RETRIES + ' retries. ' +
                                         'BulkEmailSendId: ' + bulkEmailSendId + 
                                         ', GroupId: ' + bulkEmailSendGroupId + 
                                         ', BatchSequence: ' + batchSequence;
                        System.debug('BulkEmailSendEventRetry: ' + errorMsg);
                        ApexLog.createLogDebug(new ApexLog.Error('BulkEmailSendEventRetryQueueable', 'execute', true, new customException(errorMsg)));
                    }
                    return;
                }
                
                // Record found, process the event
                BulkEmailSend__c bulkEmailSend = records[0];
                System.debug('BulkEmailSendEventRetry: Record found, processing event');
                
                // Create a handler instance and process
                BulkEmailSendEventTriggerHandler handler = new BulkEmailSendEventTriggerHandler();
                BulkEmailSendEvent__e event = new BulkEmailSendEvent__e(
                    BulkEmailSendId__c = bulkEmailSendId,
                    BulkEmailSendGroupId__c = bulkEmailSendGroupId,
                    BatchSequence__c = batchSequence,
                    EmailBatches__c = emailBatches,
                    Subject__c = subject,
                    Body__c = body
                );
                handler.processEventWithRecord(event, bulkEmailSend);
                
            } catch (Exception e) {
                String errorMsg = 'Error in retry processing: ' + e.getMessage() + 
                                 '\nBulkEmailSendId: ' + bulkEmailSendId +
                                 '\nGroupId: ' + bulkEmailSendGroupId + 
                                 '\nBatchSequence: ' + batchSequence;
                System.debug('BulkEmailSendEventRetry: ' + errorMsg);
                ApexLog.createLogDebug(new ApexLog.Error('BulkEmailSendEventRetryQueueable', 'execute', true, e));
            }
        }
    }
}