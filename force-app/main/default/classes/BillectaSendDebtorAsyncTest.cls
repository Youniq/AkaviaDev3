
@IsTest
private class BillectaSendDebtorAsyncTest {

    private class DebtorMock implements HttpCalloutMock {

        private Integer createStatus;
        private Integer getStatus;
        private Integer updateStatus;
        private Boolean throwException;

        DebtorMock(
            Integer createStatus,
            Integer getStatus,
            Integer updateStatus,
            Boolean throwException
        ) {
            this.createStatus = createStatus;
            this.getStatus = getStatus;
            this.updateStatus = updateStatus;
            this.throwException = throwException;
        }

        public HttpResponse respond(HttpRequest req) {

            if (throwException) {
                throw new CalloutException(
                    'Simulated Billecta connection failure'
                );
            }

            HttpResponse res = new HttpResponse();
            res.setHeader(
                'Content-Type',
                'application/json'
            );

            String method = req.getMethod();

            if (method == 'GET') {

                res.setStatusCode(getStatus);

                res.setBody(
                    getStatus == 200
                        ? '{"PublicId":"TEST-DEBTOR",' +
                          '"Name":"Old Name",' +
                          '"OrgNo":"19900101-9999"}'
                        : '{"error":"GET debtor failed"}'
                );

            } else if (method == 'POST') {

                res.setStatusCode(createStatus);

                res.setBody(
                    createStatus == 201
                        ? '{"PublicId":"TEST-NEW-DEBTOR"}'
                        : '{"error":"Create debtor failed"}'
                );

            } else if (method == 'PUT') {

                res.setStatusCode(updateStatus);

                res.setBody(
                    updateStatus == 200
                        ? '{"PublicId":"TEST-DEBTOR"}'
                        : '{"error":"Update debtor failed"}'
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

    private static Account createAccount(
        Boolean existingDebtor
    ) {
        Account acc = new Account(
            FirstName = 'Billecta',
            LastName = 'Async Test',
            SocialSecurityNumber__c = '199001019999'
        );

        if (existingDebtor) {
            acc.BillectaID__c = 'TEST-DEBTOR';
        }

        insert acc;
        return acc;
    }

    private static void createCredentials() {
        insert new Billecta__c(
            Creditor__c = 'TEST-CREDITOR'
        );
    }

    private static Callout__c createCallout(
        Account acc,
        Boolean existingDebtor
    ) {
        Callout__c co = new Callout__c(
            Account__c = acc.Id,
            Status__c = 'Queued',
            Type__c = existingDebtor
                ? 'Billecta - Update Debtor'
                : 'Billecta - Create Debtor'
        );

        insert co;
        return co;
    }

    private static Callout__c runJob(
        Account acc,
        Boolean updatePaymentMethod,
        Callout__c co
    ) {
        Test.startTest();

        System.enqueueJob(
            new BillectaSendDebtorAsync(
                acc,
                updatePaymentMethod,
                co.Id
            )
        );

        Test.stopTest();

        return [
            SELECT Id, Status__c, Response__c,
                   ErrorLog__c, SentOn__c,
                   Duration__c, ExtraMessage__c
            FROM Callout__c
            WHERE Id = :co.Id
        ];
    }

    @IsTest
    static void testCreateDebtorSuccess() {

        Account acc = createAccount(false);
        createCredentials();

        Callout__c co = createCallout(acc, false);

        Test.setMock(
            HttpCalloutMock.class,
            new DebtorMock(201, 200, 200, false)
        );

        Callout__c result = runJob(acc, false, co);

        System.assertEquals(
            'OK',
            result.Status__c
        );

        Account updated = [
            SELECT BillectaID__c
            FROM Account
            WHERE Id = :acc.Id
        ];

        System.assertEquals(
            'TEST-NEW-DEBTOR',
            updated.BillectaID__c
        );

        System.assertNotEquals(
            null,
            result.SentOn__c
        );

        System.assert(
            result.Response__c.contains(
                'TEST-NEW-DEBTOR'
            )
        );
    }

    @IsTest
    static void testCreateDebtorFailure() {

        Account acc = createAccount(false);
        createCredentials();

        Callout__c co = createCallout(acc, false);

        Test.setMock(
            HttpCalloutMock.class,
            new DebtorMock(500, 200, 200, false)
        );

        Callout__c result = runJob(acc, false, co);

        System.assertEquals(
            'Failed',
            result.Status__c
        );

        System.assertNotEquals(
            null,
            result.ErrorLog__c
        );
    }

    @IsTest
    static void testMissingCredentials() {

        Account acc = createAccount(false);

        Callout__c co = createCallout(acc, false);

        Callout__c result = runJob(acc, false, co);

        System.assertEquals(
            'Failed',
            result.Status__c
        );

        System.assert(
            result.ErrorLog__c.contains(
                'Billecta configuration missing'
            )
        );
    }

    @IsTest
    static void testUpdateDebtorSuccess() {

        Account acc = createAccount(true);
        createCredentials();

        Callout__c co = createCallout(acc, true);

        Test.setMock(
            HttpCalloutMock.class,
            new DebtorMock(201, 200, 200, false)
        );

        Callout__c result = runJob(acc, false, co);

        System.assertEquals(
            'OK',
            result.Status__c
        );

        Account updated = [
            SELECT BillectaID__c,
                   LatestSentPMDetails_Billecta__c
            FROM Account
            WHERE Id = :acc.Id
        ];

        System.assertEquals(
            'TEST-DEBTOR',
            updated.BillectaID__c
        );

        System.assert(
            String.isBlank(
                updated.LatestSentPMDetails_Billecta__c
            ),
            'Inga betalmetodsdetaljer ska sparas.'
        );
    }

    @IsTest
    static void testGetDebtorFailure() {

        Account acc = createAccount(true);
        createCredentials();

        Callout__c co = createCallout(acc, true);

        Test.setMock(
            HttpCalloutMock.class,
            new DebtorMock(201, 500, 200, false)
        );

        Callout__c result = runJob(acc, false, co);

        System.assertEquals(
            'Failed',
            result.Status__c
        );

        System.assert(
            result.ErrorLog__c.contains(
                'GET debtor failed'
            )
        );
    }

    @IsTest
    static void testHttpException() {

        Account acc = createAccount(false);
        createCredentials();

        Callout__c co = createCallout(acc, false);

        Test.setMock(
            HttpCalloutMock.class,
            new DebtorMock(201, 200, 200, true)
        );

        Callout__c result = runJob(acc, false, co);

        System.assertEquals(
            'Failed',
            result.Status__c
        );

        System.assert(
            result.ErrorLog__c.contains(
                'Simulated Billecta connection failure'
            )
        );
    }
}
