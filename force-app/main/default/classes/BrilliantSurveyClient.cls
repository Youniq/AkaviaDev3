public with sharing class BrilliantSurveyClient {
    public class Settings {
        public String Username;
        public String Password;
        public String CompanyRefCode;
        public String DefaultLanguageCode;
        public String DefaultSurveyRefCode;
        public String DefaultAgentRefCode;
        public Boolean EnableDebugLog;
        public String SurveyType; // Identifies the survey configuration
        public Integer MaxRetries; // Maximum retry attempts
    }

    public class RequestDTO {
        public Id caseId;
        public Id calloutId; // Callout__c record Id for tracking
        public String phoneOrEmail;
        public Boolean isEmail; // true if phoneOrEmail contains email, false for phone
        public String agentRefCode;
        public String surveyRefCode;
        public String languageCode;
        public String metaKey;
        public String attributesJson;

        // Filled from settings
        public String username;
        public String password;
        public String companyRefCode;
    }

    public static Settings getSettings() {
        // Using Custom Metadata: Brilliant_Settings__mdt with a default record named 'Default'
        Brilliant_Settings__mdt s = [
            SELECT Username__c, Password__c, CompanyRefCode__c, DefaultLanguageCode__c, DefaultSurveyRefCode__c, DefaultAgentRefCode__c, EnableDebugLog__c, MaxRetries__c
            FROM Brilliant_Settings__mdt
            WHERE DeveloperName = 'Default'
            LIMIT 1
        ];
        Settings res = new Settings();
        res.Username = s.Username__c;
        res.Password = s.Password__c;
        res.CompanyRefCode = s.CompanyRefCode__c;
        res.DefaultLanguageCode = s.DefaultLanguageCode__c;
        res.DefaultSurveyRefCode = s.DefaultSurveyRefCode__c;
        res.DefaultAgentRefCode = s.DefaultAgentRefCode__c;
        res.EnableDebugLog = s.EnableDebugLog__c;
        res.MaxRetries = s.MaxRetries__c != null ? Integer.valueOf(s.MaxRetries__c) : 3;
        res.SurveyType = 'Default';
        return res;
    }

    // Get settings by survey type (e.g., based on Case RecordType or Type field)
    // Only ServiceCase and LegalCase are supported - no fallback to Default
    public static Settings getSettingsByType(String surveyType) {
        if (String.isBlank(surveyType)) {
            throw new IllegalArgumentException('SurveyType cannot be blank. Only ServiceCase and LegalCase are supported.');
        }
        
        // Only allow ServiceCase and LegalCase - no fallback to Default
        if (surveyType != 'ServiceCase' && surveyType != 'LegalCase') {
            throw new IllegalArgumentException('Unsupported SurveyType: ' + surveyType + '. Only ServiceCase and LegalCase are supported.');
        }
        
        List<Brilliant_Settings__mdt> settingsList = [
            SELECT Username__c, Password__c, CompanyRefCode__c, DefaultLanguageCode__c, 
                   DefaultSurveyRefCode__c, DefaultAgentRefCode__c, EnableDebugLog__c, DeveloperName, MaxRetries__c
            FROM Brilliant_Settings__mdt
            WHERE DeveloperName = :surveyType
            LIMIT 1
        ];
        
        if (settingsList.isEmpty()) {
            throw new IllegalArgumentException('Brilliant_Settings__mdt metadata not found for SurveyType: ' + surveyType + '. Please ensure metadata exists for ServiceCase and LegalCase.');
        }
        
        Brilliant_Settings__mdt s = settingsList[0];
        Settings res = new Settings();
        res.Username = s.Username__c;
        res.Password = s.Password__c;
        res.CompanyRefCode = s.CompanyRefCode__c;
        res.DefaultLanguageCode = s.DefaultLanguageCode__c;
        res.DefaultSurveyRefCode = s.DefaultSurveyRefCode__c;
        res.DefaultAgentRefCode = s.DefaultAgentRefCode__c;
        res.EnableDebugLog = s.EnableDebugLog__c;
        res.MaxRetries = s.MaxRetries__c != null ? Integer.valueOf(s.MaxRetries__c) : 3;
        res.SurveyType = s.DeveloperName;
        return res;
    }

    public static String buildSoapEnvelope(RequestDTO d) {
        // Build SOAP 1.2 envelope with proper namespaces
        String soap12Ns = 'http://www.w3.org/2003/05/soap-envelope';
        String xsiNs = 'http://www.w3.org/2001/XMLSchema-instance';
        String xsdNs = 'http://www.w3.org/2001/XMLSchema';
        String targetNs = 'http://www.brightnavigator.se';
        
        // Always use Email method - no SMS
        String methodName = 'EnqueueEmailWithMetaKeyAndAttributes';
        
        // Build the element with all parameters
        List<String> elements = new List<String>();
        elements.add('<Email>' + escapeXml(safe(d.phoneOrEmail)) + '</Email>');
        elements.add('<CompanyRefCode>' + escapeXml(safe(d.companyRefCode)) + '</CompanyRefCode>');
        elements.add('<AgentRefCode>' + escapeXml(safe(d.agentRefCode)) + '</AgentRefCode>');
        elements.add('<SurveyRefCode>' + escapeXml(safe(d.surveyRefCode)) + '</SurveyRefCode>');
        elements.add('<LanguageCode>' + escapeXml(safe(d.languageCode)) + '</LanguageCode>');
        elements.add('<Username>' + escapeXml(safe(d.username)) + '</Username>');
        elements.add('<Password>' + escapeXml(safe(d.password)) + '</Password>');
        elements.add('<MetaKey>' + escapeXml(safe(d.metaKey)) + '</MetaKey>');
        
        // Handle Attributes - ensure valid JSON string
        String attributes = String.isNotBlank(d.attributesJson) ? d.attributesJson : '{}';
        elements.add('<Attributes>' + escapeXml(attributes) + '</Attributes>');
        
        String enqueueBody = String.join(elements, '');
        
        // Build complete SOAP 1.2 envelope with dynamic method name
        String soapEnvelope = '<?xml version="1.0" encoding="utf-8"?>' +
            '<soap12:Envelope xmlns:xsi="' + xsiNs + '" xmlns:xsd="' + xsdNs + '" xmlns:soap12="' + soap12Ns + '">' +
            '<soap12:Body>' +
            '<' + methodName + ' xmlns="' + targetNs + '">' +
            enqueueBody +
            '</' + methodName + '>' +
            '</soap12:Body>' +
            '</soap12:Envelope>';
        
        return soapEnvelope;
    }

    private static String safe(String s) {
        return s == null ? '' : s;
    }

    private static String escapeXml(String s) {
        if (s == null) return '';
        return s.replace('&', '&amp;')
                .replace('<', '&lt;')
                .replace('>', '&gt;')
                .replace('"', '&quot;')
                .replace('\'', '&apos;');
    }

    public class CalloutLog {
        public String endpoint = null;
        public String method = null;
        public String requestBodyRedacted = null;
        public String responseBody = null;
        public Integer statusCode = null;
        public Boolean success = null;
        public String errorMessage = null;
        public String integration = 'Brilliant';
        public String resultCode = null;
        public Id caseId = null;
    }

    public static Callout__c logToCallout(CalloutLog l) {
        Callout__c c = new Callout__c();
        if (l.endpoint != null) c.path__c = l.endpoint;
        if (l.requestBodyRedacted != null) c.request__c = l.requestBodyRedacted;
        if (l.responseBody != null) c.Response__c = l.responseBody;
        if (l.statusCode != null) c.Code__c = String.valueOf(l.statusCode);
        if (l.success != null) c.Status__c = l.success ? 'OK' : 'Failed';
        if (l.errorMessage != null) c.errorLog__c = l.errorMessage;
        if (l.resultCode != null) c.ExtraMessage__c = l.resultCode;
        if (l.caseId != null) c.Case__c = l.caseId;
        c.Type__c = l.integration;
        return c;

    }

    public static String redactPasswordInBody(String body) {
        if (String.isBlank(body)) return body;
        // Redact Password element value in SOAP XML
        // Pattern: <Password>something</Password>
        String redacted = body.replaceAll('(?i)(<Password>)([^<]*)(</Password>)', '$1******$3');
        return redacted;
    }
}