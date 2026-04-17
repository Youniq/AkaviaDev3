@IsTest
private class NewBillectaDtosTest {

    @IsTest
    static void testInitiateRetrievalRequest() {
        NewBillectaDtos.InitiateRetrievalRequest dto =
            new NewBillectaDtos.InitiateRetrievalRequest();

        dto.creditorPublicId = 'creditor-123';
        dto.personalIdNumber = '740121-0674';

        System.assertEquals('creditor-123', dto.creditorPublicId);
        System.assertEquals('740121-0674', dto.personalIdNumber);
    }

    @IsTest
    static void testInitiateRetrievalResponse() {
        NewBillectaDtos.InitiateRetrievalResponse dto =
            new NewBillectaDtos.InitiateRetrievalResponse();

        dto.sessionToken = 'token123';
        dto.sessionId = 'session456';
        dto.statusCode = 200;
        dto.rawBody = '{"SessionToken":"token123","SessionId":"session456"}';

        System.assertEquals('token123', dto.sessionToken);
        System.assertEquals('session456', dto.sessionId);
        System.assertEquals(200, dto.statusCode);
        System.assertEquals('{"SessionToken":"token123","SessionId":"session456"}', dto.rawBody);
    }

    @IsTest
    static void testLookupSuccessPayload() {
        NewBillectaDtos.LookupSuccessPayload dto =
            new NewBillectaDtos.LookupSuccessPayload();

        dto.sessionState = 'Success';
        dto.clearingNo = '8123';
        dto.accountNo = '1234567890';
        dto.bank = 'SEB';
        dto.bankName = 'Skandinaviska Enskilda Banken';

        System.assertEquals('Success', dto.sessionState);
        System.assertEquals('8123', dto.clearingNo);
        System.assertEquals('1234567890', dto.accountNo);
        System.assertEquals('SEB', dto.bank);
        System.assertEquals('Skandinaviska Enskilda Banken', dto.bankName);
    }

    @IsTest
    static void testLookupErrorPayload() {
        NewBillectaDtos.LookupErrorPayload dto =
            new NewBillectaDtos.LookupErrorPayload();

        dto.sessionState = 'Failed';
        dto.errorMessage = 'Technical error';

        System.assertEquals('Failed', dto.sessionState);
        System.assertEquals('Technical error', dto.errorMessage);
    }

    @IsTest
    static void testClientConfigResponse() {
        NewBillectaDtos.ClientConfigResponse dto =
            new NewBillectaDtos.ClientConfigResponse();

        dto.sessionToken = 'token123';
        dto.sessionId = 'session456';
        dto.accountLookupBaseUrl = 'https://accountlookup.test.billecta.com';
        dto.clientScriptUrl = 'https://accountlookup.billecta.com/js/client.js';

        System.assertEquals('token123', dto.sessionToken);
        System.assertEquals('session456', dto.sessionId);
        System.assertEquals('https://accountlookup.test.billecta.com', dto.accountLookupBaseUrl);
        System.assertEquals('https://accountlookup.billecta.com/js/client.js', dto.clientScriptUrl);
    }
}