@isTest
private class BrilliantSurveyClientTest {
    
    @TestSetup
    static void setupTestData() {
        // Test data setup is handled per test method due to Custom Metadata
    }
    
    @isTest
    static void testGetSettings() {
        // This test assumes Brilliant_Settings__mdt 'Default' record exists
        Test.startTest();
        BrilliantSurveyClient.Settings settings = BrilliantSurveyClient.getSettings();
        Test.stopTest();
        
        System.assertNotEquals(null, settings, 'Settings should not be null');
        System.assertEquals('Default', settings.SurveyType, 'Survey type should be Default');
        System.assertEquals(3, settings.MaxRetries, 'Default max retries should be 3');
    }
    
    @isTest
    static void testGetSettingsByType_ServiceCase() {
        Test.startTest();
        BrilliantSurveyClient.Settings settings = BrilliantSurveyClient.getSettingsByType('ServiceCase');
        Test.stopTest();
        
        System.assertNotEquals(null, settings, 'Settings should not be null');
        System.assertEquals('ServiceCase', settings.SurveyType, 'Survey type should match');
    }
    
    @isTest
    static void testGetSettingsByType_LegalCase() {
        Test.startTest();
        BrilliantSurveyClient.Settings settings = BrilliantSurveyClient.getSettingsByType('LegalCase');
        Test.stopTest();
        
        System.assertNotEquals(null, settings, 'Settings should not be null');
        System.assertEquals('LegalCase', settings.SurveyType, 'Survey type should match');
    }
    
    @isTest
    static void testGetSettingsByType_UnsupportedType() {
        Test.startTest();
        try {
            BrilliantSurveyClient.Settings settings = BrilliantSurveyClient.getSettingsByType('NonExistentType');
            System.assert(false, 'Should have thrown IllegalArgumentException');
        } catch (IllegalArgumentException ex) {
            System.assert(ex.getMessage().contains('Unsupported SurveyType'), 'Should throw IllegalArgumentException for unsupported type');
        }
        Test.stopTest();
    }
    
    @isTest
    static void testGetSettingsByType_BlankType() {
        Test.startTest();
        try {
            BrilliantSurveyClient.Settings settings = BrilliantSurveyClient.getSettingsByType('');
            System.assert(false, 'Should have thrown IllegalArgumentException');
        } catch (IllegalArgumentException ex) {
            System.assert(ex.getMessage().contains('cannot be blank'), 'Should throw IllegalArgumentException for blank type');
        }
        Test.stopTest();
    }
    
    @isTest
    static void testGetSettingsByType_DefaultType() {
        Test.startTest();
        try {
            BrilliantSurveyClient.Settings settings = BrilliantSurveyClient.getSettingsByType('Default');
            System.assert(false, 'Should have thrown IllegalArgumentException');
        } catch (IllegalArgumentException ex) {
            System.assert(ex.getMessage().contains('Unsupported SurveyType'), 'Should throw IllegalArgumentException for Default type');
        }
        Test.stopTest();
    }
    
    @isTest
    static void testBuildSoapEnvelope_Email() {
        BrilliantSurveyClient.RequestDTO dto = new BrilliantSurveyClient.RequestDTO();
        dto.phoneOrEmail = 'test@example.com';
        dto.isEmail = true;
        dto.companyRefCode = 'COMPANY123';
        dto.agentRefCode = 'AGENT456';
        dto.surveyRefCode = 'SURVEY789';
        dto.languageCode = 'en';
        dto.username = 'testuser';
        dto.password = 'testpass';
        dto.metaKey = '003XXXXXXXXXXXXXXX';
        dto.attributesJson = '{"key":"value"}';
        
        Test.startTest();
        String soapEnvelope = BrilliantSurveyClient.buildSoapEnvelope(dto);
        Test.stopTest();
        
        System.assert(soapEnvelope.contains('EnqueueEmailWithMetaKeyAndAttributes'), 'Should use email method');
        System.assert(soapEnvelope.contains('<Email>test@example.com</Email>'), 'Should contain email element');
        System.assert(soapEnvelope.contains('<CompanyRefCode>COMPANY123</CompanyRefCode>'), 'Should contain company ref code');
        System.assert(soapEnvelope.contains('<AgentRefCode>AGENT456</AgentRefCode>'), 'Should contain agent ref code');
        System.assert(soapEnvelope.contains('<SurveyRefCode>SURVEY789</SurveyRefCode>'), 'Should contain survey ref code');
        System.assert(soapEnvelope.contains('<LanguageCode>en</LanguageCode>'), 'Should contain language code');
        System.assert(soapEnvelope.contains('<Username>testuser</Username>'), 'Should contain username');
        System.assert(soapEnvelope.contains('<Password>testpass</Password>'), 'Should contain password');
        System.assert(soapEnvelope.contains('<MetaKey>003XXXXXXXXXXXXXXX</MetaKey>'), 'Should contain meta key');
        System.assert(soapEnvelope.contains('<Attributes>{&quot;key&quot;:&quot;value&quot;}</Attributes>'), 'Should contain escaped attributes');
    }
    
    @isTest
    static void testBuildSoapEnvelope_XmlEscaping() {
        BrilliantSurveyClient.RequestDTO dto = new BrilliantSurveyClient.RequestDTO();
        dto.phoneOrEmail = 'test<>&"\'@example.com';
        dto.isEmail = true;
        dto.companyRefCode = 'COMPANY<>&"\'';
        dto.agentRefCode = 'AGENT';
        dto.surveyRefCode = 'SURVEY';
        dto.languageCode = 'en';
        dto.username = 'user';
        dto.password = 'pass';
        dto.metaKey = 'key';
        dto.attributesJson = '{}';
        
        Test.startTest();
        String soapEnvelope = BrilliantSurveyClient.buildSoapEnvelope(dto);
        Test.stopTest();
        
        System.assert(soapEnvelope.contains('&lt;'), 'Should escape < character');
        System.assert(soapEnvelope.contains('&gt;'), 'Should escape > character');
        System.assert(soapEnvelope.contains('&amp;'), 'Should escape & character');
        System.assert(soapEnvelope.contains('&quot;'), 'Should escape " character');
        System.assert(soapEnvelope.contains('&apos;'), 'Should escape \' character');
    }
    
    @isTest
    static void testBuildSoapEnvelope_NullValues() {
        BrilliantSurveyClient.RequestDTO dto = new BrilliantSurveyClient.RequestDTO();
        dto.isEmail = true;
        
        Test.startTest();
        String soapEnvelope = BrilliantSurveyClient.buildSoapEnvelope(dto);
        Test.stopTest();
        
        System.assert(soapEnvelope.contains('EnqueueEmailWithMetaKeyAndAttributes'), 'Should use email method');
        System.assert(soapEnvelope.contains('<Email></Email>'), 'Should handle null email');
        System.assert(soapEnvelope.contains('<CompanyRefCode></CompanyRefCode>'), 'Should handle null company ref code');
    }
    
    @isTest
    static void testLogToCallout_AllFields() {
        BrilliantSurveyClient.CalloutLog log = new BrilliantSurveyClient.CalloutLog();
        log.endpoint = '/test/endpoint';
        log.method = 'POST';
        log.requestBodyRedacted = 'Request body';
        log.responseBody = 'Response body';
        log.statusCode = 200;
        log.success = true;
        log.errorMessage = null;
        log.resultCode = 'Success';
        log.caseId = null;
        
        Test.startTest();
        Callout__c callout = BrilliantSurveyClient.logToCallout(log);
        Test.stopTest();
        
        System.assertEquals('/test/endpoint', callout.path__c, 'Path should match');
        System.assertEquals('Request body', callout.request__c, 'Request should match');
        System.assertEquals('Response body', callout.Response__c, 'Response should match');
        System.assertEquals('200', callout.Code__c, 'Status code should match');
        System.assertEquals('OK', callout.Status__c, 'Status should be OK');
        System.assertEquals('Success', callout.ExtraMessage__c, 'Result code should match');
        System.assertEquals('Brilliant', callout.Type__c, 'Type should be Brilliant');
    }
    
    @isTest
    static void testLogToCallout_FailedCallout() {
        BrilliantSurveyClient.CalloutLog log = new BrilliantSurveyClient.CalloutLog();
        log.endpoint = '/test/endpoint';
        log.method = 'POST';
        log.statusCode = 500;
        log.success = false;
        log.errorMessage = 'Internal Server Error';
        log.resultCode = 'Failure';
        
        Test.startTest();
        Callout__c callout = BrilliantSurveyClient.logToCallout(log);
        Test.stopTest();
        
        System.assertEquals('500', callout.Code__c, 'Status code should match');
        System.assertEquals('Failed', callout.Status__c, 'Status should be Failed');
        System.assertEquals('Internal Server Error', callout.errorLog__c, 'Error message should match');
        System.assertEquals('Failure', callout.ExtraMessage__c, 'Result code should match');
    }
    
    @isTest
    static void testRedactPasswordInBody() {
        String body = '<soap:Envelope><Password>SecretPassword123</Password></soap:Envelope>';
        
        Test.startTest();
        String redacted = BrilliantSurveyClient.redactPasswordInBody(body);
        Test.stopTest();
        
        System.assert(redacted.contains('<Password>******</Password>'), 'Password should be redacted');
        System.assert(!redacted.contains('SecretPassword123'), 'Original password should not be present');
    }
    
    @isTest
    static void testRedactPasswordInBody_CaseInsensitive() {
        String body = '<soap:Envelope><password>SecretPassword123</password></soap:Envelope>';
        
        Test.startTest();
        String redacted = BrilliantSurveyClient.redactPasswordInBody(body);
        Test.stopTest();
        
        System.assert(redacted.contains('<password>******</password>'), 'Password should be redacted (case insensitive)');
    }
    
    @isTest
    static void testRedactPasswordInBody_EmptyPassword() {
        String body = '<soap:Envelope><Password></Password></soap:Envelope>';
        
        Test.startTest();
        String redacted = BrilliantSurveyClient.redactPasswordInBody(body);
        Test.stopTest();
        
        System.assert(redacted.contains('<Password>******</Password>'), 'Empty password should be redacted');
    }
    
    @isTest
    static void testRedactPasswordInBody_BlankInput() {
        Test.startTest();
        String redacted = BrilliantSurveyClient.redactPasswordInBody('');
        Test.stopTest();
        
        System.assertEquals('', redacted, 'Blank input should return blank');
    }
    
    @isTest
    static void testRedactPasswordInBody_NullInput() {
        Test.startTest();
        String redacted = BrilliantSurveyClient.redactPasswordInBody(null);
        Test.stopTest();
        
        System.assertEquals(null, redacted, 'Null input should return null');
    }
}