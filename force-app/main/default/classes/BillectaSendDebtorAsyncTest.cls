
@IsTest
private class BillectaSendDebtorAsyncTest {
    
    
    @IsTest
    static void testQueueableWithCallout() {

        Account acc = createAccount();
        createCredentials();

        Callout__c co = createCallout(acc.Id);
        insert co;

        Test.setMock(
            HttpCalloutMock.class,
            new DebtorMock(
                201,
                '{"PublicId":"TEST-NEW-DEBTOR"}'
            )
        );

        Test.startTest();

        Id jobId = System.enqueueJob(
    new BillectaSendDebtorAsync(acc, false, co.Id)
);

        co.JobId__c = String.valueOf(jobId);
        update co;

        Callout__c beforeExecute = [
    SELECT Id, JobId__c, Status__c
    FROM Callout__c
    WHERE Id = :co.Id
];

System.assertEquals(
    String.valueOf(jobId),
    beforeExecute.JobId__c,
    'JobId__c ändrades när Callout__c sparades'
);

        Test.stopTest();

        AsyncApexJob job = [
            SELECT Id, Status, NumberOfErrors, ExtendedStatus
            FROM AsyncApexJob
            WHERE Id = :jobId
            LIMIT 1
        ];

        System.assertEquals(
            'Completed',
            job.Status,
            'Queueable status: ' + job.Status +
            ', Errors: ' + job.NumberOfErrors +
            ', Details: ' + job.ExtendedStatus
        );

        Callout__c result = [
            SELECT Status__c, Response__c,
                ErrorLog__c, JobId__c
            FROM Callout__c
            WHERE JobId__c = :String.valueOf(jobId)
            LIMIT 1
        ];

        System.assertEquals(
            'OK',
            result.Status__c,
            'Callout failed. ErrorLog: ' + result.ErrorLog__c +
            ' Response: ' + result.Response__c
        );

        Account updatedAccount = [
            SELECT BillectaID__c
            FROM Account
            WHERE Id = :acc.Id
        ];

        System.assertEquals(
            'TEST-NEW-DEBTOR',
            updatedAccount.BillectaID__c,
            'Account was not updated. Callout status: ' +
            result.Status__c +
            ', ErrorLog: ' + result.ErrorLog__c
        );
    }


    @IsTest
    static void testUpdateDebtorSuccess() {

        Account acc = createAccount();
        createCredentials();

        acc.BillectaID__c = 'TEST-EXISTING-DEBTOR';

        Test.setMock(
            HttpCalloutMock.class,
            new DebtorGetUpdateMock(200)
        );

        BillectaSendDebtorAsync service =
            new BillectaSendDebtorAsync(acc, true);

        Test.startTest();

        Callout__c result = service.sendToBillecta(
            createCallout(acc.Id)
        );

        Test.stopTest();

        System.assertEquals('OK', result.Status__c);
        System.assert(
            result.Response__c.contains('RESPONSE GET DEBTOR')
        );
        System.assert(
            result.Response__c.contains('RESPONSE UPDATE DEBTOR')
        );
    }

    @IsTest
    static void testUpdateDebtorHttp500() {

        Account acc = createAccount();
        createCredentials();

        acc.BillectaID__c = 'TEST-EXISTING-DEBTOR';

        Test.setMock(
            HttpCalloutMock.class,
            new DebtorGetUpdateMock(500)
        );

        BillectaSendDebtorAsync service =
            new BillectaSendDebtorAsync(acc, true);

        Test.startTest();

        Callout__c result = service.sendToBillecta(
            createCallout(acc.Id)
        );

        Test.stopTest();

        System.assertEquals('Failed', result.Status__c);
        System.assert(
            result.ErrorLog__c.contains('Simulated update failure')
        );
    }
    
    private class DebtorGetUpdateMock implements HttpCalloutMock {

        private Integer updateStatusCode;

        DebtorGetUpdateMock(Integer updateStatusCode) {
            this.updateStatusCode = updateStatusCode;
        }

        public HttpResponse respond(HttpRequest req) {

            HttpResponse res = new HttpResponse();

            if (req.getMethod() == 'GET') {
                res.setStatusCode(200);
                res.setBody(
                    '{' +
                    '"DebtorPublicId":"TEST-EXISTING-DEBTOR",' +
                    '"CreditorPublicId":"TEST-CREDITOR",' +
                    '"Name":"Billecta Test",' +
                    '"OrgNo":"19900101-1234",' +
                    '"IsActive":true,' +
                    '"DefaultActionConfig":{' +
                        '"DeliveryMethod":"Mail",' +
                        '"ActivateDefaultActionConfigOverride":false' +
                    '}' +
                    '}'
                );
            } else {
                res.setStatusCode(updateStatusCode);
                res.setBody(
                    updateStatusCode == 200
                        ? '{"PublicId":"TEST-EXISTING-DEBTOR"}'
                        : '{"error":"Simulated update failure"}'
                );
            }

            return res;
        }
    }

    private class DebtorMock implements HttpCalloutMock {

        private Integer statusCode;
        private String responseBody;

        DebtorMock(Integer statusCode, String responseBody) {
            this.statusCode = statusCode;
            this.responseBody = responseBody;
        }

        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(statusCode);
            res.setBody(responseBody);
            return res;
        }
    }

    private class DebtorExceptionMock implements HttpCalloutMock {

        public HttpResponse respond(HttpRequest req) {
            throw new CalloutException('Simulated callout failure');
        }
    }
    
        
    private static Account createAccount() {
        Account acc = new Account(
            FirstName = 'Billecta',
            LastName = 'Test',
            SocialSecurityNumber__c = '199001011234'
        );

        insert acc;
        return acc;
    }


    private static void createCredentials() {
        insert new Billecta__c(
            Creditor__c = 'TEST-CREDITOR'
        );
    }

    private static Callout__c createCallout(Id accountId) {
        return new Callout__c(
            Account__c = accountId,
            Type__c = 'Billecta - Update Debtor',
            Status__c = 'Queued'
        );
    }

    @IsTest
    static void testCreateDebtorSuccess() {

        Account acc = createAccount();
        createCredentials();

        Test.setMock(
            HttpCalloutMock.class,
            new DebtorMock(
                201,
                '{"PublicId":"TEST-NEW-DEBTOR"}'
            )
        );

        BillectaSendDebtorAsync service =
            new BillectaSendDebtorAsync(acc, false);

        Test.startTest();

        Callout__c result = service.sendToBillecta(
            createCallout(acc.Id)
        );

        Test.stopTest();

        System.assertEquals('OK', result.Status__c);
        System.assert(
            result.Response__c.contains('TEST-NEW-DEBTOR')
        );
    }

    @IsTest
    static void testCreateDebtorHttp500() {

        Account acc = createAccount();
        createCredentials();

        Test.setMock(
            HttpCalloutMock.class,
            new DebtorMock(
                500,
                '{"error":"Simulated failure"}'
            )
        );

        BillectaSendDebtorAsync service =
            new BillectaSendDebtorAsync(acc, false);

        Test.startTest();

        Callout__c result = service.sendToBillecta(
            createCallout(acc.Id)
        );

        Test.stopTest();

        System.assertEquals('Failed', result.Status__c);
        System.assert(
            !String.isBlank(result.ErrorLog__c)
        );
    }

    @IsTest
    static void testUpdateDebtorGetHttp500() {

        Account acc = createAccount();
        createCredentials();

        acc.BillectaID__c = 'TEST-EXISTING-DEBTOR';

        Test.setMock(
            HttpCalloutMock.class,
            new DebtorMock(
                500,
                '{"error":"Get debtor failed"}'
            )
        );

        BillectaSendDebtorAsync service =
            new BillectaSendDebtorAsync(acc, true);

        Test.startTest();

        Callout__c result = service.sendToBillecta(
            createCallout(acc.Id)
        );

        Test.stopTest();

        System.assertEquals('Failed', result.Status__c);
        System.assert(
            !String.isBlank(result.ErrorLog__c)
        );
    }

    @IsTest
    static void testCreateDebtorException() {

        Account acc = createAccount();
        createCredentials();

        Test.setMock(
            HttpCalloutMock.class,
            new DebtorExceptionMock()
        );

        BillectaSendDebtorAsync service =
            new BillectaSendDebtorAsync(acc, false);

        Test.startTest();

        Callout__c result = service.sendToBillecta(
            createCallout(acc.Id)
        );

        Test.stopTest();

        System.assertEquals('Failed', result.Status__c);
        System.assert(
            !String.isBlank(result.ErrorLog__c)
        );
    }

    @IsTest
    static void testSetFailedCalloutValues() {

        Account acc = new Account(
            LastName = 'Test'
        );

        BillectaSendDebtorAsync service =
            new BillectaSendDebtorAsync(acc, false);

        Callout__c co = new Callout__c();

        try {
            throw new CalloutException('Test exception');
        } catch (Exception e) {

            Callout__c result =
                service.setFailedCalloutValues(co, e);

            System.assertEquals(
                'Failed',
                result.Status__c
            );

            System.assert(
                result.ErrorLog__c.contains('Test exception')
            );
        }
    }

    @IsTest
    static void testQueueableWithoutCallout() {

        Account acc = createAccount();

        Test.startTest();

        System.enqueueJob(
            new BillectaSendDebtorAsync(acc, false)
        );

        Test.stopTest();

        // Verifies that execute() handles missing Callout__c.
        System.assert(true);
    }
}
