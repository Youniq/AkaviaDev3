public with sharing class NewBillectaDtos {
    public class InitiateRetrievalRequest {
        @AuraEnabled public String creditorPublicId;
        @AuraEnabled public String personalIdNumber;
    }

    public class InitiateRetrievalResponse {
        @AuraEnabled public String sessionToken;
        @AuraEnabled public String sessionId;
        @AuraEnabled public Integer statusCode;
        @AuraEnabled public String rawBody;
    }

    public class LookupSuccessPayload {
        @AuraEnabled public String sessionState;
        @AuraEnabled public String clearingNo;
        @AuraEnabled public String accountNo;
        @AuraEnabled public String bank;
        @AuraEnabled public String bankName;
    }

    public class LookupErrorPayload {
        @AuraEnabled public String sessionState;
        @AuraEnabled public String errorMessage;
    }

    public class ClientConfigResponse {
        @AuraEnabled public String sessionToken;
        @AuraEnabled public String sessionId;
        @AuraEnabled public String accountLookupBaseUrl;
        @AuraEnabled public String clientScriptUrl;
    }
}