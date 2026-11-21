
@IsTest
private class BillectaInitiateSendDebtorTest {

    private static Integer accountCounter = 0;

    private static Account createAccount() {
        accountCounter++;

        String ssn =
            '19900101' +
            String.valueOf(accountCounter).leftPad(4, '0');

        Account acc = new Account(
            FirstName = 'Billecta',
            LastName = 'Test ' + accountCounter,
            SocialSecurityNumber__c = ssn
        );

        insert acc;
        return acc;
    }

    private static void createCredentials() {
        insert new Billecta__c(
            Creditor__c = 'TEST-CREDITOR'
        );
    }

    private class DebtorMock implements HttpCalloutMock {

        public HttpResponse respond(HttpRequest req) {

            HttpResponse res = new HttpResponse();
            res.setHeader(
                'Content-Type',
                'application/json'
            );

            String method = req.getMethod();

            if (method == 'POST') {
                res.setStatusCode(201);
                res.setBody(
                    '{"PublicId":"TEST-NEW-DEBTOR"}'
                );
            } else if (method == 'GET') {
                res.setStatusCode(200);
                res.setBody(
                    '{"PublicId":"TEST-DEBTOR",' +
                    '"Name":"Old Name",' +
                    '"OrgNo":"19900101-9999"}'
                );
            } else if (method == 'PUT') {
                res.setStatusCode(200);
                res.setBody(
                    '{"PublicId":"TEST-DEBTOR"}'
                );
            } else {
                res.setStatusCode(400);
                res.setBody(
                    '{"error":"Unexpected HTTP method"}'
                );
            }

            return res;
        }
    }

    private static BillectaInitiateSendDebtor.Request createRequest(
        String recordId,
        String action
    ) {
        BillectaInitiateSendDebtor.Request req =
            new BillectaInitiateSendDebtor.Request();

        req.recordId = recordId;
        req.billectaAction = action;

        return req;
    }

    @IsTest
    static void testNullAndEmptyRequests() {

        System.assertEquals(
            0,
            BillectaInitiateSendDebtor.sendDebtorWithPaymentMethod(null).size()
        );

        System.assertEquals(
            0,
            BillectaInitiateSendDebtor.sendDebtorWithPaymentMethod(
                    new List<BillectaInitiateSendDebtor.Request>()
                )
                .size()
        );

        System.assertEquals(
            0,
            BillectaInitiateSendDebtor.sendDebtor(null, false).size()
        );

        System.assertEquals(
            0,
            BillectaInitiateSendDebtor.sendDebtor(
                    new Map<Id, String>(),
                    false
                )
                .size()
        );
    }

    @IsTest
    static void testInvalidRequests() {

        List<BillectaInitiateSendDebtor.Request> requests =
            new List<BillectaInitiateSendDebtor.Request>{
                null,
                createRequest(null, 'create'),
                createRequest('', 'create'),
                createRequest('INVALID-ID', 'create')
            };

        List<BillectaInitiateSendDebtor.Response> responses =
            BillectaInitiateSendDebtor.sendDebtorWithPaymentMethod(requests);

        System.assertEquals(4, responses.size());

        System.assertEquals(
            'Account Id saknas.',
            responses[0].errorMsg
        );

        System.assertEquals(
            'Account Id saknas.',
            responses[1].errorMsg
        );

        System.assertEquals(
            'Account Id saknas.',
            responses[2].errorMsg
        );

        System.assert(
            responses[3].errorMsg.contains(
                'Ogiltigt Account Id'
            )
        );
    }

    @IsTest
    static void testValidationErrorUpdateWithoutBillectaId() {

        Account acc = createAccount();

        List<BillectaInitiateSendDebtor.Response> responses =
            BillectaInitiateSendDebtor.sendDebtorWithPaymentMethod(
                    new List<BillectaInitiateSendDebtor.Request>{
                        createRequest(
                            String.valueOf(acc.Id),
                            'update'
                        )
                    }
                );

        System.assertEquals(1, responses.size());

        System.assert(
            responses[0].errorMsg.contains(
                'Billecta Id missing'
            )
        );

        System.assertEquals(
            0,
            [
                SELECT COUNT()
                FROM Callout__c
                WHERE Account__c = :acc.Id
            ]
        );
    }

    @IsTest
    static void testInvalidAction() {

        Account acc = createAccount();

        List<String> results =
            BillectaInitiateSendDebtor.sendDebtor(
                new Map<Id, String>{
                    acc.Id => 'invalid-action'
                },
                false
            );

        System.assertEquals(1, results.size());
        System.assertNotEquals(null, results[0]);

        System.assertEquals(
            0,
            [
                SELECT COUNT()
                FROM Callout__c
                WHERE Account__c = :acc.Id
            ]
        );
    }

    @IsTest
    static void testMissingAccount() {

        Account acc = createAccount();
        Id accountId = acc.Id;

        delete acc;

        List<String> results =
            BillectaInitiateSendDebtor.sendDebtor(
                new Map<Id, String>{
                    accountId => 'create'
                },
                false
            );

        System.assertEquals(1, results.size());

        System.assertEquals(
            'Account hittades inte eller är GDPR-avslutat.',
            results[0]
        );
    }

    @IsTest
    static void testCreateDebtorSchedulesCallout() {

        Account acc = createAccount();
        createCredentials();

        Test.setMock(
            HttpCalloutMock.class,
            new DebtorMock()
        );

        Test.startTest();

        List<String> results =
            BillectaInitiateSendDebtor.sendDebtor(
                new Map<Id, String>{
                    acc.Id => 'create'
                },
                false
            );

        Test.stopTest();

        System.assertEquals(1, results.size());
        System.assertEquals(null, results[0]);

        List<Callout__c> callouts = [
            SELECT Id, JobId__c, Status__c,
                   Type__c, Response__c
            FROM Callout__c
            WHERE Account__c = :acc.Id
        ];

        System.assertEquals(1, callouts.size());

        System.assertEquals(
            'Billecta - Create Debtor',
            callouts[0].Type__c
        );

        System.assertNotEquals(
            null,
            callouts[0].JobId__c
        );

        System.assertEquals(
            'OK',
            callouts[0].Status__c
        );
    }

    @IsTest
    static void testInvocableSuccess() {

        Account acc = createAccount();
        createCredentials();

        Test.setMock(
            HttpCalloutMock.class,
            new DebtorMock()
        );

        Test.startTest();

        List<BillectaInitiateSendDebtor.Response> responses =
            BillectaInitiateSendDebtor.sendDebtorWithPaymentMethod(
                    new List<BillectaInitiateSendDebtor.Request>{
                        createRequest(
                            String.valueOf(acc.Id),
                            'create'
                        )
                    }
                );

        Test.stopTest();

        System.assertEquals(1, responses.size());

        System.assertEquals(
            null,
            responses[0].errorMsg
        );

        List<Callout__c> callouts = [
            SELECT Id, Status__c
            FROM Callout__c
            WHERE Account__c = :acc.Id
        ];

        System.assertEquals(1, callouts.size());

        System.assertEquals(
            'OK',
            callouts[0].Status__c
        );
    }

    @IsTest
    static void testMultipleRequestsPreserveOrder() {

        Account validAcc = createAccount();
        Account invalidAcc = createAccount();

        createCredentials();

        Test.setMock(
            HttpCalloutMock.class,
            new DebtorMock()
        );

        List<BillectaInitiateSendDebtor.Request> requests =
            new List<BillectaInitiateSendDebtor.Request>{
                createRequest(null, 'create'),
                createRequest(
                    String.valueOf(invalidAcc.Id),
                    'update'
                ),
                createRequest(
                    String.valueOf(validAcc.Id),
                    'create'
                )
            };

        Test.startTest();

        List<BillectaInitiateSendDebtor.Response> responses =
            BillectaInitiateSendDebtor.sendDebtorWithPaymentMethod(requests);

        Test.stopTest();

        System.assertEquals(3, responses.size());

        System.assertEquals(
            'Account Id saknas.',
            responses[0].errorMsg
        );

        System.assertNotEquals(
            null,
            responses[1].errorMsg
        );

        System.assertEquals(
            null,
            responses[2].errorMsg
        );

        List<Callout__c> callouts = [
            SELECT Id, Status__c
            FROM Callout__c
            WHERE Account__c = :validAcc.Id
        ];

        System.assertEquals(1, callouts.size());

        System.assertEquals(
            'OK',
            callouts[0].Status__c
        );
    }

    @IsTest
    static void testBatchMixedActionsRejected() {

        List<Account> accountsToInsert =
            new List<Account>();

        for (Integer i = 0; i < 50; i++) {
            accountsToInsert.add(
                new Account(
                    LastName = 'Billecta Batch ' + i
                )
            );
        }

        insert accountsToInsert;

        Map<Id, String> accountActions =
            new Map<Id, String>();

        for (Integer i = 0; i < accountsToInsert.size(); i++) {
            accountActions.put(
                accountsToInsert[i].Id,
                i == 0 ? 'update' : 'create'
            );
        }

        Boolean exceptionThrown = false;

        try {
            BillectaInitiateSendDebtor.sendDebtor(
                accountActions,
                false
            );
        } catch (BillectaException e) {
            exceptionThrown = true;

            System.assert(
                e.getMessage().contains(
                    'samma Billecta-åtgärd'
                )
            );
        }

        System.assertEquals(
            true,
            exceptionThrown
        );
    }
}
