public with sharing class BrilliantSurveyQueueable implements Queueable, Database.AllowsCallouts {
    private BrilliantSurveyClient.RequestDTO dto;
    private Integer currentRetryCount;
    private Integer maxRetries;

    public BrilliantSurveyQueueable(BrilliantSurveyClient.RequestDTO dto) {
        this.dto = dto;
        this.currentRetryCount = 0;
        this.maxRetries = 3;
    }

    public BrilliantSurveyQueueable(BrilliantSurveyClient.RequestDTO dto, Integer retryCount, Integer maxRetries) {
        this.dto = dto;
        this.currentRetryCount = retryCount;
        this.maxRetries = maxRetries;
    }

    public void execute(QueueableContext qc) {
        if (dto == null) return;

        // Query for existing Callout__c record using calloutId from DTO (avoids race condition with jobId)
        Callout__c currentCallout;
        if (dto.calloutId != null) {
            List<Callout__c> existingCallouts = [
                SELECT Id, Status__c, sentOn__c, Duration__c, Response__c, Account__c,
                       jobId__c, errorLog__c, extraMessage__c, RetryCount__c 
                FROM Callout__c 
                WHERE Id = :dto.calloutId
                LIMIT 1
            ];
            
            if (existingCallouts.isEmpty()) {
                // Record doesn't exist - log error and exit (cannot make callout after DML)
                System.debug('ERROR: Callout__c record not found for calloutId: ' + dto.calloutId);
                return;
            }
            
            currentCallout = existingCallouts[0];
        } else {
            // Fallback: try to find by jobId for backward compatibility
            List<Callout__c> existingCallouts = [
                SELECT Id, Status__c, sentOn__c, Duration__c, Response__c, Account__c,
                       jobId__c, errorLog__c, extraMessage__c, RetryCount__c 
                FROM Callout__c 
                WHERE jobId__c = :qc.getJobId()
                LIMIT 1
            ];
            
            if (existingCallouts.isEmpty()) {
                System.debug('ERROR: Callout__c record not found for jobId: ' + qc.getJobId());
                return;
            }
            
            currentCallout = existingCallouts[0];
        }
        
        // Prepare endpoint - direct URL (credentials are in SOAP body, not headers)
        final String endpoint = 'https://service.brilliantnavigator.com/brightservice/brightservice.asmx';

        // Build SOAP request
        HttpRequest req = new HttpRequest();
        req.setEndpoint(endpoint);
        req.setMethod('POST');
        req.setHeader(GlobalConstants.HTTP_HEADER_FIELD_NAME_CONTENT_TYPE, 'application/soap+xml; charset=utf-8');
        
        // Always use Email SOAPAction
        req.setHeader('SOAPAction', 'http://www.brightnavigator.se/EnqueueEmailWithMetaKeyAndAttributes');
        
        String body = BrilliantSurveyClient.buildSoapEnvelope(dto);
        currentCallout.request__c = body;
        req.setBody(body);

        // Send
        Integer statusCode;
        String responseBody;
        Boolean success = false;
        String resultCode;
        String errorMessage;

        try {
            HttpResponse res = new Http().send(req);
            statusCode = res.getStatusCode();
            responseBody = res.getBody();

            // Consider 200 as success; parse body for ResultCode
            success = (statusCode >= 200 && statusCode < 300);

            // Extract ResultCode from SOAP response
            resultCode = parseResultCode(responseBody);

            // If ResultCode is present, "Success" or "AlreadyQueued" indicates success
            if (String.isNotBlank(resultCode)) {
                success = 'Success'.equalsIgnoreCase(resultCode) || 'AlreadyQueued'.equalsIgnoreCase(resultCode);
            }
        } catch (Exception ex) {
            statusCode = null;
            responseBody = null;
            success = false;
            errorMessage = ex.getMessage();
        }

        // Log to Callout__c with password redacted in request body
        currentCallout.Response__c = responseBody;
        currentCallout.Code__c = String.valueOf(statusCode);
        currentCallout.Status__c = success ? 'OK' : 'Failed';
        currentCallout.errorLog__c = errorMessage;
        currentCallout.ExtraMessage__c = resultCode;
        currentCallout.request__c = BrilliantSurveyClient.redactPasswordInBody(body);
        currentCallout.RetryCount__c = currentRetryCount;
        
        // Retry logic for failed callouts
        if (!success && currentRetryCount < maxRetries) {
            currentCallout.Status__c = 'Queued';
            currentCallout.errorLog__c = (errorMessage != null ? errorMessage : 'Callout failed') + 
                ' - Retry ' + (currentRetryCount + 1) + ' of ' + maxRetries;
            
            // Update jobId for retry job
            Id retryJobId = System.enqueueJob(new BrilliantSurveyQueueable(dto, currentRetryCount + 1, maxRetries));
            currentCallout.jobId__c = retryJobId;
            update currentCallout;
        } else {
            if (!success && currentRetryCount >= maxRetries) {
                currentCallout.errorLog__c = (errorMessage != null ? errorMessage : 'Callout failed') + 
                    ' - Max retries reached';
            }
            update currentCallout;
            
            // Update Case BrilliantSurveySent__c timestamp only after successful callout
            if (success && dto.caseId != null && (resultCode == 'Success' || resultCode == 'AlreadyQueued')) {
                try {
                    Case caseToUpdate = new Case(
                        Id = dto.caseId,
                        BrilliantSurveySent__c = Datetime.now()
                    );
                    update caseToUpdate;
                } catch (Exception ex) {
                    // Log error but don't fail the queueable job
                    ApexLog.Error errorLog = new ApexLog.Error(
                        'BrilliantSurveyQueueable',
                        'execute - Case date update',
                        false,
                        ex
                    );
                    errorLog.recordId = dto.caseId;
                    ApexLog.createLogDebug(errorLog);
                }
            }
        }
    }

    // Parse result from SOAP 1.2 XML response.
    // Expected response structure for Email:
    // <soap12:Envelope><soap12:Body><EnqueueEmailWithMetaKeyAndAttributesResponse xmlns="http://www.brightnavigator.se">
    //   <EnqueueEmailWithMetaKeyAndAttributesResult>Success</EnqueueEmailWithMetaKeyAndAttributesResult>
    // </EnqueueEmailWithMetaKeyAndAttributesResponse></soap12:Body></soap12:Envelope>
    // Expected response structure for SMS:
    // <soap12:Envelope><soap12:Body><EnqueueSMSWithMetaKeyAndAttributesResponse xmlns="http://www.brightnavigator.se">
    //   <EnqueueSMSWithMetaKeyAndAttributesResult>Success</EnqueueSMSWithMetaKeyAndAttributesResult>
    // </EnqueueSMSWithMetaKeyAndAttributesResponse></soap12:Body></soap12:Envelope>
    private static String parseResultCode(String body) {
        if (String.isBlank(body)) return null;

        // Try Email method response first
        Matcher m = Pattern.compile('(?i)<EnqueueEmailWithMetaKeyAndAttributesResult[^>]*>([^<]+)</EnqueueEmailWithMetaKeyAndAttributesResult>').matcher(body);
        if (m.find()) {
            String result = m.group(1).trim();
            // Validate against known ResultCode values from WSDL
            // Success, Failure, InvalidInput, InvalidCode, AlreadyQueued, Disabled, NumberExcluded
            return result;
        }

        // Try SMS method response
        m = Pattern.compile('(?i)<EnqueueSMSWithMetaKeyAndAttributesResult[^>]*>([^<]+)</EnqueueSMSWithMetaKeyAndAttributesResult>').matcher(body);
        if (m.find()) return m.group(1).trim();

        // Fallback: try generic EnqueueSurvey for backward compatibility
        m = Pattern.compile('(?i)<EnqueueSurveyResult[^>]*>([^<]+)</EnqueueSurveyResult>').matcher(body);
        if (m.find()) return m.group(1).trim();

        return null;
    }
}