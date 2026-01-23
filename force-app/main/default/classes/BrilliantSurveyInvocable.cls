/**
 * BrilliantSurveyInvocable
 * 
 * Invocable Apex class that enables automated customer satisfaction survey requests
 * to be sent to the Brilliant survey service when Cases are closed.
 * 
 * Business Process:
 * This class supports the customer feedback workflow where satisfaction surveys
 * are automatically triggered after Case resolution. When a Case is closed, this
 * invocable action can be called from a Flow, Process Builder, or Apex to:
 * 
 * 1. Collect Case information including Contact phone details
 * 2. Determine the appropriate survey configuration from Case data and settings
 * 3. Build and validate survey request data
 * 4. Queue asynchronous API callouts to Brilliant's survey service (one job per callout)
 * 
 * The class queries Case-related data (Contact) and selects
 * contact phone information (preferring MobilePhone over Phone). It uses default survey
 * settings from Custom Metadata and always derives values from the Case:
 * - Survey reference code (from settings)
 * - Language code (from settings)
 * - Agent reference code (from settings)
 * - Meta key (from Case ContactId)
 * - Custom attributes JSON (defaults to empty object)
 * 
 * Validation ensures required fields (phoneOrEmail, agentRefCode, surveyRefCode)
 * are present before queuing. Failed validations are logged to Callout__c records
 * for troubleshooting. Successful requests are processed asynchronously via
 * BrilliantSurveyQueueable (one job per callout) to avoid blocking the Case close transaction.
 * 
 * Usage:
 * This class is designed to be invoked from Salesforce Flows (typically triggered
 * when a Case status changes to "Closed" or similar) or Process Builder/Automation.
 * The invocable method accepts a list of Input objects, each containing a CaseId.
 * All other values are derived from the Case and settings.
 */
public with sharing class BrilliantSurveyInvocable {
    public class Input {
        @InvocableVariable(required=true)
        public Id CaseId;
    }

    @InvocableMethod(label='Send Brilliant Survey' description='Queues a callout to Brilliant after Case closed')
    public static void sendToBrilliant(List<Input> inputs) {
        try {
            if (inputs == null || inputs.isEmpty()) {
                return;
            }

            // Collect Case Ids
            Set<Id> caseIds = new Set<Id>();
            for (Input i : inputs) {
                if (i != null && i.CaseId != null) {
                    caseIds.add(i.CaseId);
                }
            }
            if (caseIds.isEmpty()) {
                return;
            }

            // Query needed Case data (Contact, Origin, Email, RecordType for survey selection, Owner for AgentRefCode)
            Map<Id, Case> casesById = new Map<Id, Case>([
                SELECT Id, CaseNumber, ContactId, Contact.Phone, Contact.MobilePhone, Origin, Contact.Email, RecordType.DeveloperName, OwnerId, Owner.Email
                FROM Case
                WHERE Id IN :caseIds
            ]);

            // Build DTOs
            List<BrilliantSurveyClient.RequestDTO> dtos = new List<BrilliantSurveyClient.RequestDTO>();
            List<Integer> maxRetryList = new List<Integer>();
            List<Callout__c> calloutLogs = new List<Callout__c>();
            
            for (Input i : inputs) {
                if (i == null || i.CaseId == null) continue;
                Case c = casesById.get(i.CaseId);
                if (c == null) continue;

                try {
                    // Validate RecordType - only ServiceCase and LegalCase are allowed
                    String recordTypeName = (c.RecordType != null) ? c.RecordType.DeveloperName : null;
                    
                    if (recordTypeName != 'ServiceCase' && recordTypeName != 'LegalCase') {
                        // Log error and skip - do not send Brilliant survey for unsupported Case types
                        ApexLog.Error errorLog = new ApexLog.Error(
                            'BrilliantSurveyInvocable',
                            'sendToBrilliant - Unsupported RecordType',
                            false,
                            new IllegalArgumentException('Case RecordType must be ServiceCase or LegalCase. Current RecordType: ' + recordTypeName)
                        );
                        errorLog.recordId = c.Id;
                        ApexLog.createLogDebug(errorLog);
                        continue;
                    }
                    
                    // Determine survey type based on Case RecordType
                    String surveyType = recordTypeName;
                    BrilliantSurveyClient.Settings settings = BrilliantSurveyClient.getSettingsByType(surveyType);
                    Integer maxRetries = settings.MaxRetries != null ? settings.MaxRetries : 3;

                    BrilliantSurveyClient.RequestDTO requestData = new BrilliantSurveyClient.RequestDTO();
                    requestData.caseId = c.Id;

                    // Always send survey via Email for all Case Origins (Email, Phone, Web, Portal)
                    String email = (c.Contact != null) ? (String)c.Contact.get('Email') : null;
                    requestData.phoneOrEmail = email;
                    requestData.isEmail = true;

                    // AgentRefCode: Determine based on RecordType
                    String agentRefCode;
                    
                    if (recordTypeName == 'ServiceCase') {
                        // For ServiceCase: Map Owner email to agentRefCode
                        String ownerEmail = (c.Owner != null && c.Owner.Email != null) ? c.Owner.Email : null;
                        
                        // List of allowed owner emails for ServiceCase
                        Set<String> allowedServiceEmails = new Set<String>{
                            'mikael.hamann@akavia.se',
                            'dorota@akavia.se',
                            'marcus.nilsson@akavia.se',
                            'suzan.avci@akavia.se',
                            'nazli.younespoor@akavia.se',
                            'therese.drake@akavia.se'
                        };
                        
                        if (ownerEmail != null && allowedServiceEmails.contains(ownerEmail.toLowerCase())) {
                            agentRefCode = ownerEmail;
                        } else {
                            // Fallback to DefaultAgentRefCode from metadata
                            agentRefCode = settings.DefaultAgentRefCode;
                        }
                    } else if (recordTypeName == 'LegalCase') {
                        // For LegalCase: Use DefaultAgentRefCode from metadata
                        agentRefCode = settings.DefaultAgentRefCode;
                    } else {
                        // This should never happen due to validation above, but added for safety
                        ApexLog.Error errorLog = new ApexLog.Error(
                            'BrilliantSurveyInvocable',
                            'sendToBrilliant - Invalid RecordType in agentRefCode logic',
                            true,
                            new IllegalArgumentException('Unexpected RecordType: ' + recordTypeName)
                        );
                        errorLog.recordId = c.Id;
                        ApexLog.createLogDebug(errorLog);
                        continue;
                    }
                    
                    requestData.agentRefCode = agentRefCode;

                    // Survey/Language from settings
                    requestData.surveyRefCode = settings.DefaultSurveyRefCode;
                    requestData.languageCode  = settings.DefaultLanguageCode;

                    // MetaKey from ContactId
                    requestData.metaKey = c.ContactId;

                    // Attributes default to empty object
                    requestData.attributesJson = '{}';

                    // Inject settings
                    requestData.username = settings.Username;
                    requestData.password = settings.Password;
                    requestData.companyRefCode = settings.CompanyRefCode;
                    
                    BrilliantSurveyClient.CalloutLog clog = new BrilliantSurveyClient.CalloutLog();
                    Callout__c calloutLog = new Callout__c();

                    // Guard: must have phoneOrEmail and agentRefCode and surveyRefCode
                    if (String.isBlank(requestData.phoneOrEmail) || String.isBlank(requestData.agentRefCode) || String.isBlank(requestData.surveyRefCode)) {
                        // Log an error entry to Callout__c and skip
                        clog.endpoint = '/brightservice/brightservice.asmx';
                        clog.method = 'POST';
                        clog.requestBodyRedacted = 'MISSING REQUIRED FIELDS: ' +
                            'PhoneOrEmail=' + requestData.phoneOrEmail + ', AgentRefCode=' + requestData.agentRefCode + ', SurveyRefCode=' + requestData.surveyRefCode;
                        clog.success = false;
                        clog.errorMessage = 'Validation failed before callout';
                        clog.caseId = c.Id;
                        calloutLog = BrilliantSurveyClient.logToCallout(clog);
                        calloutLogs.add(calloutLog);
                        dtos.add(null);
                        maxRetryList.add(null);
                        continue;
                    } else {
                        // Create callout log for queued request
                        clog.endpoint = '/brightservice/brightservice.asmx';
                        clog.method = 'POST';
                        clog.success = true;
                        clog.caseId = c.Id;
                        calloutLog = BrilliantSurveyClient.logToCallout(clog);
                        calloutLog.Status__c = 'Queued';
                        calloutLogs.add(calloutLog);
                    }

                    // Persist the DTO + retry policy alongside the queued log so we can re-use it later
                    dtos.add(requestData);
                    maxRetryList.add(maxRetries);
                    
                } catch (Exception ex) {
                    // Log error for this specific case
                    ApexLog.Error errorLog = new ApexLog.Error(
                        'BrilliantSurveyInvocable',
                        'sendToBrilliant - Case processing',
                        false,
                        ex
                    );
                    errorLog.recordId = c.Id;
                    ApexLog.createLogDebug(errorLog);
                    continue;
                }
            }

            // Insert callout logs BEFORE enqueuing jobs so records exist when jobs run
            if (!calloutLogs.isEmpty()) {
                try {
                    insert calloutLogs;
                    
                    // Now enqueue jobs and update with jobIds
                    List<Callout__c> logsToUpdate = new List<Callout__c>();
                    for (Integer idx = 0; idx < calloutLogs.size(); idx++) {
                        Callout__c logRecord = calloutLogs[idx];
                        BrilliantSurveyClient.RequestDTO dto = dtos.size() > idx ? dtos[idx] : null;
                        Integer maxRetries = maxRetryList.size() > idx && maxRetryList[idx] != null ? maxRetryList[idx] : 3;

                        if (logRecord == null || logRecord.Status__c != 'Queued' || dto == null) {
                            continue;
                        }

                        try {
                            // Set calloutId in DTO before enqueuing to avoid race condition
                            dto.calloutId = logRecord.Id;
                            
                            Id jobId = System.enqueueJob(new BrilliantSurveyQueueable(dto, 0, maxRetries));
                            logRecord.jobId__c = jobId;
                            logsToUpdate.add(logRecord);
                        } catch (Exception ex) {
                            // Log error for this specific job enqueue
                            ApexLog.Error errorLog = new ApexLog.Error(
                                'BrilliantSurveyInvocable',
                                'sendToBrilliant - Job enqueue',
                                false,
                                ex
                            );
                            errorLog.recordId = logRecord.Case__c;
                            ApexLog.createLogDebug(errorLog);
                        }
                    }
                    
                    if (!logsToUpdate.isEmpty()) {
                        update logsToUpdate;
                    }
                } catch (Exception ex) {
                    ApexLog.Error errorLog = new ApexLog.Error(
                        'BrilliantSurveyInvocable',
                        'sendToBrilliant - Callout log insert/update',
                        true,
                        ex
                    );
                    ApexLog.createLogDebug(errorLog);
                }
            }
            
        } catch (Exception ex) {
            // Top-level error handler
            ApexLog.Error errorLog = new ApexLog.Error(
                'BrilliantSurveyInvocable',
                'sendToBrilliant',
                true,
                ex
            );
            ApexLog.createLogDebug(errorLog);
        }
    }
}