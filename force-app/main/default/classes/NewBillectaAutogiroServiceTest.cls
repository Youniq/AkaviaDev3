@IsTest
private class NewBillectaAutogiroServiceTest {

    @TestSetup
    static void setup() {

        Account pa = new Account(
            RecordTypeId = getPersonAccountRecordTypeId(),
            FirstName = 'Stefan',
            LastName = 'Testsson',
            PersonEmail = 'stefan.test@example.com',
            SocialSecurityNumber__c = '740121-0674'
        );

        insert pa;
    }

    @IsTest
    static void testStartAutogiroChange() {

        Account pa = [
            SELECT Id, SocialSecurityNumber__c
            FROM Account
            LIMIT 1
        ];

        // Mock Billecta config
        NewBillectaBankAccountService.Config cfg =
            new NewBillectaBankAccountService.Config();

        cfg.baseEndpoint = 'https://test.billecta.com';
        cfg.creditorPublicId = 'creditor-test';
        cfg.secureToken = 'secure-token';
        cfg.accountLookupBaseUrl = 'https://lookup.test';

        NewBillectaBankAccountService.testConfig = cfg;

        // Mock HTTP response
        Test.setMock(HttpCalloutMock.class, new BillectaLookupMock());

        Test.startTest();

        NewBillectaAutogiroService.StartAutogiroBankChangeResponse response =
            NewBillectaAutogiroService.startAutogiroChange(pa.Id);

        Test.stopTest();

        System.assertNotEquals(null, response);
        System.assertEquals('session-token-test', response.sessionToken);
        System.assertEquals('session-id-test', response.sessionId);

        Autogiro_Change_Log__c logRec = [
            SELECT Id,
                   Account__c,
                   Status__c,
                   Billecta_Session_Id__c
            FROM Autogiro_Change_Log__c
            LIMIT 1
        ];

        System.assertEquals(pa.Id, logRec.Account__c);
        System.assertEquals('Started', logRec.Status__c);
        System.assertEquals('session-id-test', logRec.Billecta_Session_Id__c);
    }

    @IsTest
    static void testCompleteAutogiroChange() {

        Account pa = [
            SELECT Id, DistributionMethod__c
            FROM Account
            LIMIT 1
        ];

        Autogiro_Change_Log__c logRec = new Autogiro_Change_Log__c(
            Account__c = pa.Id,
            Status__c = 'Started',
            Started_At__c = System.now()
        );

        insert logRec;

        Test.startTest();

        Id resultId = NewBillectaAutogiroService.completeAutogiroChange(
            logRec.Id,
            'Completed',
            '1234',
            '1234567890',
            'SEB',
            'Skandinaviska Enskilda Banken'
        );

        Test.stopTest();

        Autogiro_Change_Log__c updatedLog = [
            SELECT Status__c,
                   Session_State__c,
                   Clearing_Number__c,
                   Account_Number__c,
                   Bank_Code__c,
                   Bank_Name__c,
                   Completed_At__c
            FROM Autogiro_Change_Log__c
            WHERE Id = :resultId
        ];

        System.assertEquals('Completed', updatedLog.Status__c);
        System.assertEquals('1234', updatedLog.Clearing_Number__c);
        System.assertEquals('1234567890', updatedLog.Account_Number__c);
        System.assertEquals('SEB', updatedLog.Bank_Code__c);

        Account updatedAcc = [
            SELECT PaymentMethod__c,
                DistributionMethod__c,
                LatestSentPMDetails_Billecta__c
            FROM Account
            WHERE Id = :pa.Id
        ];
        System.assertEquals('AG', updatedAcc.PaymentMethod__c);
        System.assertEquals('Ingen leverans', updatedAcc.DistributionMethod__c);
        System.assertEquals(
            'AG : Ingen leverans',
            updatedAcc.LatestSentPMDetails_Billecta__c
        );
    }

    @IsTest
    static void testFailAutogiroChange() {

        Account pa = [
            SELECT Id
            FROM Account
            LIMIT 1
        ];

        Autogiro_Change_Log__c logRec = new Autogiro_Change_Log__c(
            Account__c = pa.Id,
            Status__c = 'Started',
            Started_At__c = System.now()
        );

        insert logRec;

        Test.startTest();

        Id resultId = NewBillectaAutogiroService.failAutogiroChange(
            logRec.Id,
            'Failed',
            'ErrorState',
            'Tekniskt fel'
        );

        Test.stopTest();

        Autogiro_Change_Log__c updatedLog = [
            SELECT Status__c,
                   Session_State__c,
                   Error_Message__c
            FROM Autogiro_Change_Log__c
            WHERE Id = :resultId
        ];

        System.assertEquals('Failed', updatedLog.Status__c);
        System.assertEquals('ErrorState', updatedLog.Session_State__c);
        System.assertEquals('Tekniskt fel', updatedLog.Error_Message__c);
    }

    private static Id getPersonAccountRecordTypeId() {

        return [
            SELECT Id
            FROM RecordType
            WHERE SObjectType = 'Account'
            AND IsPersonType = true
            LIMIT 1
        ].Id;
    }

    private class BillectaLookupMock implements HttpCalloutMock {

        public HTTPResponse respond(HTTPRequest req) {

            System.assertEquals(
                'https://test.billecta.com/v1/bankAccount/InitiateRetrieval',
                req.getEndpoint()
            );

            System.assert(req.getBody().contains('740121-0674'));

            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setHeader('Content-Type', 'application/json');

            res.setBody(
                '{"SessionToken":"session-token-test",' +
                '"SessionId":"session-id-test"}'
            );

            return res;
        }
    }
}