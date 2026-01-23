@isTest
private class BrilliantSurveyQueueableTest {
    
    @isTest
    static void testQueueable_AlreadyQueued() {
        Contact con = new Contact(FirstName = 'Test', LastName = 'Contact', Email = 'test@example.com');
        insert con;
        
        Case testCase = new Case(Subject = 'Test Case', ContactId = con.Id, Status = 'Closed');
        insert testCase;
        
        BrilliantSurveyClient.RequestDTO dto = new BrilliantSurveyClient.RequestDTO();
        dto.caseId = testCase.Id;
        dto.phoneOrEmail = 'test@example.com';
        dto.isEmail = true;
        dto.companyRefCode = 'COMPANY123';
        dto.agentRefCode = 'AGENT456';
        dto.surveyRefCode = 'SURVEY789';
        dto.languageCode = 'en';
        dto.username = 'testuser';
        dto.password = 'testpass';
        dto.metaKey = testCase.Id;
        dto.attributesJson = '{}';
        
        Callout__c calloutRecord = new Callout__c(
            Case__c = testCase.Id,
            Status__c = 'Queued',
            Type__c = 'Brilliant'
        );
        insert calloutRecord;
        
        Test.setMock(HttpCalloutMock.class, new BrilliantSurveyAlreadyQueuedMock());
        
        Test.startTest();
        BrilliantSurveyQueueable job = new BrilliantSurveyQueueable(dto, 0, 3);
        Id jobId = System.enqueueJob(job);
        
        calloutRecord.jobId__c = jobId;
        update calloutRecord;
        Test.stopTest();
        
        Callout__c updatedCallout = [SELECT Id, Status__c, ExtraMessage__c FROM Callout__c WHERE Id = :calloutRecord.Id];
        System.assertEquals('OK', updatedCallout.Status__c);
        System.assertEquals('AlreadyQueued', updatedCallout.ExtraMessage__c);
    }
    
    @isTest
    static void testQueueable_NullDTO() {
        BrilliantSurveyQueueable job = new BrilliantSurveyQueueable(null);
        System.enqueueJob(job);
        
        System.assertEquals(0, [SELECT COUNT() FROM Callout__c]);
    }
    
    // HTTP Mock classes
    private class BrilliantSurveySuccessMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('<?xml version="1.0" encoding="utf-8"?>' +
                '<soap12:Envelope xmlns:soap12="http://www.w3.org/2003/05/soap-envelope">' +
                '<soap12:Body>' +
                '<EnqueueEmailWithMetaKeyAndAttributesResponse xmlns="http://www.brightnavigator.se">' +
                '<EnqueueEmailWithMetaKeyAndAttributesResult>Success</EnqueueEmailWithMetaKeyAndAttributesResult>' +
                '</EnqueueEmailWithMetaKeyAndAttributesResponse>' +
                '</soap12:Body>' +
                '</soap12:Envelope>');
            return res;
        }
    }
    
    private class BrilliantSurveySMSSuccessMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('<?xml version="1.0" encoding="utf-8"?>' +
                '<soap12:Envelope xmlns:soap12="http://www.w3.org/2003/05/soap-envelope">' +
                '<soap12:Body>' +
                '<EnqueueSMSWithMetaKeyAndAttributesResponse xmlns="http://www.brightnavigator.se">' +
                '<EnqueueSMSWithMetaKeyAndAttributesResult>Success</EnqueueSMSWithMetaKeyAndAttributesResult>' +
                '</EnqueueSMSWithMetaKeyAndAttributesResponse>' +
                '</soap12:Body>' +
                '</soap12:Envelope>');
            return res;
        }
    }
    
    private class BrilliantSurveyAlreadyQueuedMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('<?xml version="1.0" encoding="utf-8"?>' +
                '<soap12:Envelope xmlns:soap12="http://www.w3.org/2003/05/soap-envelope">' +
                '<soap12:Body>' +
                '<EnqueueEmailWithMetaKeyAndAttributesResponse xmlns="http://www.brightnavigator.se">' +
                '<EnqueueEmailWithMetaKeyAndAttributesResult>AlreadyQueued</EnqueueEmailWithMetaKeyAndAttributesResult>' +
                '</EnqueueEmailWithMetaKeyAndAttributesResponse>' +
                '</soap12:Body>' +
                '</soap12:Envelope>');
            return res;
        }
    }
    
    private class BrilliantSurveyInvalidInputMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('<?xml version="1.0" encoding="utf-8"?>' +
                '<soap12:Envelope xmlns:soap12="http://www.w3.org/2003/05/soap-envelope">' +
                '<soap12:Body>' +
                '<EnqueueEmailWithMetaKeyAndAttributesResponse xmlns="http://www.brightnavigator.se">' +
                '<EnqueueEmailWithMetaKeyAndAttributesResult>InvalidInput</EnqueueEmailWithMetaKeyAndAttributesResult>' +
                '</EnqueueEmailWithMetaKeyAndAttributesResponse>' +
                '</soap12:Body>' +
                '</soap12:Envelope>');
            return res;
        }
    }
    
    private class BrilliantSurveyExceptionMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            throw new CalloutException('Connection timeout');
        }
    }
}