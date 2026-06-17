@IsTest
public with sharing class NewBillectaAutogiroServiceTest {

    private class MockBillectaResponse implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setHeader('Content-Type', 'application/json');

            res.setBody(
                '{"SessionToken":"token123","SessionId":"session123"}'
            );

            return res;
        }
    }

    @TestSetup
    static void makeData() {
        TestDataFactorySetupParams params = new TestDataFactorySetupParams();
        params.numberOfAccounts = 1;

        TestDataFactory.setupBasicTestData();
        TestDataFactory.setupTestData(params);
    }

    private static void setupBillectaConfig() {
        NewBillectaBankAccountService.Config cfg = new NewBillectaBankAccountService.Config();
        cfg.baseEndpoint = 'https://apitest.billecta.com';
        cfg.creditorPublicId = '467fe7dd-529b-47cc-bc63-d840981a52aa';
        cfg.secureToken = 'secure-token-value';
        cfg.accountLookupBaseUrl = 'https://accountlookup.test.billecta.com';
        NewBillectaBankAccountService.testConfig = cfg;
    }

    @IsTest
    static void testStartAutogiroChange() {
        setupBillectaConfig();

        Account acc = [
            SELECT Id, IsPersonAccount
            FROM Account
            LIMIT 1
        ];

        acc.SocialSecurityNumber__c = '197401210674';
        update acc;

        Test.setMock(HttpCalloutMock.class, new MockBillectaResponse());

        Test.startTest();

        NewBillectaAutogiroService.StartAutogiroBankChangeResponse response =
            NewBillectaAutogiroService.startAutogiroChange(acc.Id);

        Test.stopTest();

        Assert.isNotNull(response);
        Assert.areEqual('token123', response.sessionToken);
        Assert.areEqual('session123', response.sessionId);
        Assert.isNotNull(response.autogiroChangeLogId);

        Autogiro_Change_Log__c logRec = [
            SELECT Id,
                Account__c,
                Status__c,
                Billecta_Session_Id__c
            FROM Autogiro_Change_Log__c
            WHERE Id = :response.autogiroChangeLogId
            LIMIT 1
        ];

        Assert.areEqual(acc.Id, logRec.Account__c);
        Assert.areEqual('Started', logRec.Status__c);
        Assert.areEqual('session123', logRec.Billecta_Session_Id__c);
    }

    @IsTest
    static void testCompleteAutogiroChange() {

        Account acc = [
            SELECT Id
            FROM Account
            LIMIT 1
        ];

        Autogiro_Change_Log__c logRec = new Autogiro_Change_Log__c(
            Account__c = acc.Id,
            Status__c = 'Started',
            Started_At__c = System.now()
        );

        insert logRec;

        String autogiroJson =
            '{"Autogiro":{' +
            '"AccountNo":"123456789",' +
            '"ClearingNo":"1234",' +
            '"PaymentServiceSupplier":"Swedbank",' +
            '"Stage":"Approved"' +
            '}}';

        Test.startTest();

        Id resultId = NewBillectaAutogiroService.completeAutogiroChange(
            logRec.Id,
            'completed',
            '1234',
            '123456789',
            'Swedbank',
            'Swedbank',
            autogiroJson
        );

        Test.stopTest();

        Assert.areEqual(logRec.Id, resultId);

        Autogiro_Change_Log__c updatedLog = [
            SELECT Status__c,
                Session_State__c,
                Clearing_Number__c,
                Account_Number__c,
                Bank_Code__c,
                Bank_Name__c,
                Completed_At__c
            FROM Autogiro_Change_Log__c
            WHERE Id = :logRec.Id
        ];

        Assert.areEqual('Completed', updatedLog.Status__c);
        Assert.areEqual('completed', updatedLog.Session_State__c);
        Assert.areEqual('1234', updatedLog.Clearing_Number__c);
        Assert.areEqual('123456789', updatedLog.Account_Number__c);
        Assert.areEqual('Swedbank', updatedLog.Bank_Code__c);
    }

    @IsTest
    static void testFailAutogiroChange() {

        Account acc = [
            SELECT Id
            FROM Account
            LIMIT 1
        ];

        Autogiro_Change_Log__c logRec = new Autogiro_Change_Log__c(
            Account__c = acc.Id,
            Status__c = 'Started',
            Started_At__c = System.now()
        );

        insert logRec;

        Test.startTest();

        Id resultId = NewBillectaAutogiroService.failAutogiroChange(
            logRec.Id,
            'Failed',
            'cancelled',
            'Test error'
        );

        Test.stopTest();

        Assert.areEqual(logRec.Id, resultId);

        Autogiro_Change_Log__c updatedLog = [
            SELECT Status__c,
                Session_State__c,
                Error_Message__c,
                Completed_At__c
            FROM Autogiro_Change_Log__c
            WHERE Id = :logRec.Id
        ];

        Assert.areEqual('Failed', updatedLog.Status__c);
        Assert.areEqual('cancelled', updatedLog.Session_State__c);
        Assert.areEqual('Test error', updatedLog.Error_Message__c);
        Assert.isNotNull(updatedLog.Completed_At__c);
    }

    @IsTest
    static void testStartAutogiroChangeThrowsWhenNoSSN() {

        Account acc = [
            SELECT Id
            FROM Account
            LIMIT 1
        ];

        acc.SocialSecurityNumber__c = null;
        update acc;

        Boolean didThrow = false;

        Test.startTest();

        try {
            NewBillectaAutogiroService.startAutogiroChange(acc.Id);
        } catch (AuraHandledException e) {
            didThrow = true;
        }

        Test.stopTest();

        Assert.areEqual(true, didThrow);
    }
}