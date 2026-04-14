@IsTest
private class NewBillectaBankAccountServiceTest {

    private class InitiateRetrievalMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            System.assertEquals('POST', req.getMethod());
            System.assert(req.getEndpoint().contains('/v1/bankAccount/InitiateRetrieval'));
            System.assertEquals('application/json', req.getHeader('Content-Type'));
            System.assert(req.getHeader('Authorization').startsWith('SecureToken '));

            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"SessionToken":"token123","SessionId":"session456"}');
            return res;
        }
    }

    @IsTest
    static void testCreateLookupSession() {
        insert new Billecta_Settings__mdt(
            DeveloperName = 'Default',
            MasterLabel = 'Default',
            Base_Endpoint__c = 'https://apitest.billecta.com',
            Account_Lookup_Base_Url__c = 'https://accountlookup.test.billecta.com',
            Client_Script_Url__c = 'https://accountlookup.billecta.com/js/client.js',
            Secure_Token__c = 'secure-token-value',
            Creditor_Public_Id__c = '467fe7dd-529b-47cc-bc63-d840981a52aa',
            Is_Test_Mode__c = true
        );

        Test.setMock(HttpCalloutMock.class, new InitiateRetrievalMock());

        Test.startTest();
        BillectaDtos.ClientConfigResponse result =
            BillectaBankAccountService.createLookupSession('740121-0674');
        Test.stopTest();

        System.assertEquals('token123', result.sessionToken);
        System.assertEquals('session456', result.sessionId);
        System.assertEquals('https://accountlookup.test.billecta.com', result.accountLookupBaseUrl);
    }

    @IsTest
    static void testSaveSuccessfulLookup() {
        Test.startTest();
        Id resultId = BillectaBankAccountPersistenceService.saveSuccessfulLookup(
            null,
            'Success',
            '8123',
            '1234567890',
            'SEB',
            'Skandinaviska Enskilda Banken'
        );
        Test.stopTest();

        Billecta_Bank_Account_Result__c rec = [
            SELECT Status__c, Session_State__c, Clearing_Number__c, Account_Number__c, Bank_Code__c, Bank_Name__c
            FROM Billecta_Bank_Account_Result__c
            WHERE Id = :resultId
        ];

        System.assertEquals('Success', rec.Status__c);
        System.assertEquals('Success', rec.Session_State__c);
        System.assertEquals('8123', rec.Clearing_Number__c);
    }

    @IsTest
    static void testSaveFailedLookup() {
        Test.startTest();
        Id resultId = BillectaBankAccountPersistenceService.saveFailedLookup(
            null,
            'Failed',
            'Failed',
            'Technical error'
        );
        Test.stopTest();

        Billecta_Bank_Account_Result__c rec = [
            SELECT Status__c, Session_State__c, Error_Message__c
            FROM Billecta_Bank_Account_Result__c
            WHERE Id = :resultId
        ];

        System.assertEquals('Failed', rec.Status__c);
        System.assertEquals('Technical error', rec.Error_Message__c);
    }
}
