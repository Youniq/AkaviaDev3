@IsTest
private class NewBillectaBankAccountServiceTest {

    private class SuccessMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            System.assertEquals('POST', req.getMethod());
            System.assert(req.getEndpoint().contains('/v1/bankAccount/InitiateRetrieval'));

            System.assertEquals('application/json', req.getHeader('Content-Type'));
            System.assertEquals('application/json', req.getHeader('Accept'));

            String authHeader = req.getHeader('Authorization');
            System.assertNotEquals(null, authHeader);
            System.assert(
                authHeader.startsWith('SecureToken '),
                'Authorization header should start with SecureToken '
            );

            String body = req.getBody();
            System.assertNotEquals(null, body);
            System.assert(body.contains('CreditorPublicId'));
            System.assert(body.contains('467fe7dd-529b-47cc-bc63-d840981a52aa'));
            System.assert(body.contains('PersonalIdNumber'));
            System.assert(body.contains('740121-0674'));

            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"SessionToken":"token123","SessionId":"session456"}');
            return res;
        }
    }

    private class SuccessWithoutPnrMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            String body = req.getBody();
            System.assertNotEquals(null, body);
            System.assert(body.contains('CreditorPublicId'));
            System.assert(!body.contains('PersonalIdNumber'));

            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"SessionToken":"token123","SessionId":"session456"}');
            return res;
        }
    }

    private class ErrorMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(400);
            res.setBody('{"message":"Bad request"}');
            return res;
        }
    }

    private static void setupConfig() {
        NewBillectaBankAccountService.Config cfg = new NewBillectaBankAccountService.Config();
        cfg.baseEndpoint = 'https://apitest.billecta.com';
        cfg.creditorPublicId = '467fe7dd-529b-47cc-bc63-d840981a52aa';
        cfg.secureToken = 'secure-token-value';
        cfg.accountLookupBaseUrl = 'https://accountlookup.test.billecta.com';
        cfg.clientScriptUrl = 'https://accountlookup.billecta.com/js/client.js';

        NewBillectaBankAccountService.testConfig = cfg;
    }

    @IsTest
    static void testCreateLookupSession_Success() {
        setupConfig();
        Test.setMock(HttpCalloutMock.class, new SuccessMock());

        Test.startTest();
        NewBillectaDtos.ClientConfigResponse result =
            NewBillectaBankAccountService.createLookupSession('740121-0674');
        Test.stopTest();

        System.assertEquals('token123', result.sessionToken);
        System.assertEquals('session456', result.sessionId);
        System.assertEquals('https://accountlookup.test.billecta.com', result.accountLookupBaseUrl);
        System.assertEquals('https://accountlookup.billecta.com/js/client.js', result.clientScriptUrl);
    }

    @IsTest
    static void testCreateLookupSession_WithoutPersonalIdNumber() {
        setupConfig();
        Test.setMock(HttpCalloutMock.class, new SuccessWithoutPnrMock());

        Test.startTest();
        NewBillectaDtos.ClientConfigResponse result =
            NewBillectaBankAccountService.createLookupSession(null);
        Test.stopTest();

        System.assertEquals('token123', result.sessionToken);
        System.assertEquals('session456', result.sessionId);
        System.assertEquals('https://accountlookup.test.billecta.com', result.accountLookupBaseUrl);
        System.assertEquals('https://accountlookup.billecta.com/js/client.js', result.clientScriptUrl);
    }

    @IsTest
    static void testCreateLookupSession_ErrorResponse() {
        setupConfig();
        Test.setMock(HttpCalloutMock.class, new ErrorMock());

        Boolean exceptionThrown = false;

        Test.startTest();
        try {
            NewBillectaBankAccountService.createLookupSession('740121-0674');
        } catch (AuraHandledException e) {
            exceptionThrown = true;
        }
        Test.stopTest();

        System.assertEquals(true, exceptionThrown, 'Expected AuraHandledException was not thrown');
    }

    @IsTest
    static void testCreateLookupSession_MissingConfig() {
        NewBillectaBankAccountService.Config cfg = new NewBillectaBankAccountService.Config();
        NewBillectaBankAccountService.testConfig = cfg;

        Boolean exceptionThrown = false;

        Test.startTest();
        try {
            NewBillectaBankAccountService.createLookupSession('740121-0674');
        } catch (AuraHandledException e) {
            exceptionThrown = true;
        }
        Test.stopTest();

        System.assertEquals(true, exceptionThrown, 'Expected AuraHandledException was not thrown');
    }
}