@IsTest
private class NewBillectaAutogiroServiceTest {

    private class BillectaInitiateRetrievalMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            System.assertEquals('POST', req.getMethod());
            System.assert(req.getEndpoint().contains('/v1/bankAccount/InitiateRetrieval'));
            System.assertNotEquals(null, req.getHeader('Authorization'));
            System.assertEquals('application/json', req.getHeader('Content-Type'));

            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"SessionToken":"test-session-token","SessionId":"test-session-id"}');
            return res;
        }
    }

    private static void setupBillectaConfig() {
        NewBillectaBankAccountService.Config cfg = new NewBillectaBankAccountService.Config();
        cfg.baseEndpoint = 'https://apitest.billecta.com';
        cfg.creditorPublicId = '467fe7dd-529b-47cc-bc63-d840981a52aa';
        cfg.secureToken = 'secure-token-value';
        cfg.accountLookupBaseUrl = 'https://accountlookup.test.billecta.com';
        cfg.clientScriptUrl = 'https://accountlookup.test.billecta.com/js/client.js';
        NewBillectaBankAccountService.testConfig = cfg;
    }

    private static Account createPersonAccount() {
        Id personRtId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName()
            .get('PersonAccount')
            .getRecordTypeId();

        Account pa = new Account();
        pa.RecordTypeId = personRtId;
        pa.FirstName = 'Test';
        pa.LastName = 'Person';
        pa.PersonEmail = 'test.person@example.com';
        insert pa;

        return pa;
    }

    private static Account createBusinessAccount() {
        Account acc = new Account();
        acc.Name = 'Test Business Account';
        insert acc;
        return acc;
    }

    @IsTest
    static void testStartAutogiroChange_Success() {
        setupBillectaConfig();
        Test.setMock(HttpCalloutMock.class, new BillectaInitiateRetrievalMock());

        Account pa = createPersonAccount();

        Test.startTest();
        NewBillectaAutogiroService.StartAutogiroBankChangeResponse response =
            NewBillectaAutogiroService.startAutogiroChange(pa.Id, '740121-0674');
        Test.stopTest();

        System.assertNotEquals(null, response);
        System.assertEquals('test-session-token', response.sessionToken);
        System.assertEquals('test-session-id', response.sessionId);
        System.assertEquals('https://accountlookup.test.billecta.com', response.accountLookupBaseUrl);
        System.assertEquals('https://accountlookup.test.billecta.com/js/client.js', response.clientScriptUrl);
        System.assertNotEquals(null, response.autogiroChangeLogId);

        Autogiro_Change_Log__c logRec = [
            SELECT Id, Account__c, Status__c, Billecta_Session_Id__c, Started_At__c
            FROM Autogiro_Change_Log__c
            WHERE Id = :response.autogiroChangeLogId
            LIMIT 1
        ];

        System.assertEquals(pa.Id, logRec.Account__c);
        System.assertEquals('Started', logRec.Status__c);
        System.assertEquals('test-session-id', logRec.Billecta_Session_Id__c);
        System.assertNotEquals(null, logRec.Started_At__c);
    }

    @IsTest
    static void testCompleteAutogiroChange_Success() {
        Account pa = createPersonAccount();

        Autogiro_Change_Log__c logRec = new Autogiro_Change_Log__c(
            Account__c = pa.Id,
            Status__c = 'Started',
            Billecta_Session_Id__c = 'session-123',
            Started_At__c = System.now()
        );
        insert logRec;

        Test.startTest();
        Id resultId = NewBillectaAutogiroService.completeAutogiroChange(
            logRec.Id,
            'SIGNED',
            '1234',
            '1234567890',
            'BANK01',
            'Test Bank'
        );
        Test.stopTest();

        System.assertEquals(logRec.Id, resultId);

        Autogiro_Change_Log__c updated = [
            SELECT Id, Status__c, Session_State__c, Clearing_Number__c, Account_Number__c,
                   Bank_Code__c, Bank_Name__c, Error_Message__c, Completed_At__c
            FROM Autogiro_Change_Log__c
            WHERE Id = :logRec.Id
            LIMIT 1
        ];

        System.assertEquals('Completed', updated.Status__c);
        System.assertEquals('SIGNED', updated.Session_State__c);
        System.assertEquals('1234', updated.Clearing_Number__c);
        System.assertEquals('1234567890', updated.Account_Number__c);
        System.assertEquals('BANK01', updated.Bank_Code__c);
        System.assertEquals('Test Bank', updated.Bank_Name__c);
        System.assertEquals(null, updated.Error_Message__c);
        System.assertNotEquals(null, updated.Completed_At__c);
    }

    @IsTest
    static void testFailAutogiroChange_Success() {
        Account pa = createPersonAccount();

        Autogiro_Change_Log__c logRec = new Autogiro_Change_Log__c(
            Account__c = pa.Id,
            Status__c = 'Started',
            Billecta_Session_Id__c = 'session-456',
            Started_At__c = System.now()
        );
        insert logRec;

        Test.startTest();
        Id resultId = NewBillectaAutogiroService.failAutogiroChange(
            logRec.Id,
            'Failed',
            'ERROR',
            'Billecta returned an error.'
        );
        Test.stopTest();

        System.assertEquals(logRec.Id, resultId);

        Autogiro_Change_Log__c updated = [
            SELECT Id, Status__c, Session_State__c, Error_Message__c, Completed_At__c
            FROM Autogiro_Change_Log__c
            WHERE Id = :logRec.Id
            LIMIT 1
        ];

        System.assertEquals('Failed', updated.Status__c);
        System.assertEquals('ERROR', updated.Session_State__c);
        System.assertEquals('Billecta returned an error.', updated.Error_Message__c);
        System.assertNotEquals(null, updated.Completed_At__c);
    }

    @IsTest
    static void testFailAutogiroChange_DefaultStatusToFailed() {
        Account pa = createPersonAccount();

        Autogiro_Change_Log__c logRec = new Autogiro_Change_Log__c(
            Account__c = pa.Id,
            Status__c = 'Started',
            Billecta_Session_Id__c = 'session-789',
            Started_At__c = System.now()
        );
        insert logRec;

        Test.startTest();
        Id resultId = NewBillectaAutogiroService.failAutogiroChange(
            logRec.Id,
            null,
            'CANCELLED',
            'User cancelled flow.'
        );
        Test.stopTest();

        System.assertEquals(logRec.Id, resultId);

        Autogiro_Change_Log__c updated = [
            SELECT Id, Status__c, Session_State__c, Error_Message__c
            FROM Autogiro_Change_Log__c
            WHERE Id = :logRec.Id
            LIMIT 1
        ];

        System.assertEquals('Failed', updated.Status__c);
        System.assertEquals('CANCELLED', updated.Session_State__c);
        System.assertEquals('User cancelled flow.', updated.Error_Message__c);
    }

    @IsTest
static void testStartAutogiroChange_MissingAccountId() {
    Boolean didThrow = false;

    try {
        Test.startTest();
        NewBillectaAutogiroService.startAutogiroChange(null, '740121-0674');
        Test.stopTest();
    } catch (Exception e) {
        didThrow = true;
        System.debug('MissingAccountId exception: ' + e.getMessage());
    }

    System.assertEquals(true, didThrow, 'Expected exception was not thrown.');
    }

    @IsTest
    static void testStartAutogiroChange_NotPersonAccount() {
        Account acc = createBusinessAccount();
        Boolean didThrow = false;

        try {
            Test.startTest();
            NewBillectaAutogiroService.startAutogiroChange(acc.Id, '740121-0674');
            Test.stopTest();
        } catch (Exception e) {
            didThrow = true;
            System.debug('NotPersonAccount exception: ' + e.getMessage());
        }

        System.assertEquals(true, didThrow, 'Expected exception was not thrown.');
    }

    @IsTest
    static void testCompleteAutogiroChange_MissingLogId() {
        Boolean didThrow = false;

        try {
            Test.startTest();
            NewBillectaAutogiroService.completeAutogiroChange(
                null,
                'SIGNED',
                '1234',
                '1234567890',
                'BANK01',
                'Test Bank'
            );
            Test.stopTest();
        } catch (Exception e) {
            didThrow = true;
            System.debug('Complete missingLogId exception: ' + e.getMessage());
        }

        System.assertEquals(true, didThrow, 'Expected exception was not thrown.');
    }

    @IsTest
    static void testFailAutogiroChange_MissingLogId() {
        Boolean didThrow = false;

        try {
            Test.startTest();
            NewBillectaAutogiroService.failAutogiroChange(
                null,
                'Failed',
                'ERROR',
                'Missing log id.'
            );
            Test.stopTest();
        } catch (Exception e) {
            didThrow = true;
            System.debug('Fail missingLogId exception: ' + e.getMessage());
        }

        System.assertEquals(true, didThrow, 'Expected exception was not thrown.');
    }
}