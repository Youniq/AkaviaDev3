@IsTest
private class BillectaCancelInvociesQueuableTest {

    private class BillectaMock implements HttpCalloutMock {

        private Integer statusCode;

        BillectaMock(Integer statusCode) {
            this.statusCode = statusCode;
        }

        public HttpResponse respond(HttpRequest request) {

            String body = request.getBody();

            System.assert(
                body.contains('TEST-NORMAL'),
                'Vanlig faktura ska skickas till Billecta.'
            );

            System.assert(
                !body.contains('TEST-SRAT'),
                'SRAT-faktura får inte skickas.'
            );

            HttpResponse response = new HttpResponse();
            response.setStatusCode(statusCode);
            response.setBody(
                statusCode == 200
                    ? '{"success":true}'
                    : '{"error":"Test failure"}'
            );

            return response;
        }
    }

    private static Account createAccount() {

        TestDataFactorySetupParams params = new TestDataFactorySetupParams();

        params.numberOfAccounts = 1;

        return TestDataFactory.createTestAccounts(params).values()[0];
    }

    private static Invoice__c createInvoice(
        Id accountId,
        String billectaId,
        String category,
        String paymentStatus
    ) {

        TestDataFactorySetupParams params =
            new TestDataFactorySetupParams();

        Invoice__c invoice =
            TestDataFactory.createTestInvoice(
                params,
                1,
                false,
                new List<Id>{ accountId },
                false
            )[0];

        invoice.BillectaID__c = billectaId;
        invoice.FeeCategory__c = category;
        invoice.PaymentStatus__c = paymentStatus;

        insert invoice;

        return invoice;
    }

    private static Id enqueueWithLog(
        List<Invoice__c> invoices
    ) {

        Id jobId = System.enqueueJob(
            new BillectaCancelInvociesQueuable(invoices)
        );

        insert new Callout__c(
            jobId__c = String.valueOf(jobId),
            Type__c = 'Billecta - Cancel Invoices',
            Status__c = 'Queued'
        );

        return jobId;
    }

    @IsTest
    static void successfulCancellation() {

        Account account = createAccount();

        TestDataFactory.setupBasicTestData();

        Invoice__c normal = createInvoice(
            account.Id,
            'TEST-NORMAL',
            null,
            'Ej betald'
        );

        Invoice__c srat = createInvoice(
            account.Id,
            'TEST-SRAT',
            'Dubbelansluten SRAT',
            'Ej betald'
        );

        Test.setMock(
            HttpCalloutMock.class,
            new BillectaMock(200)
        );

        Test.startTest();

        Id jobId = enqueueWithLog(
            new List<Invoice__c>{ normal, srat }
        );

        Test.stopTest();

        Map<Id, Invoice__c> invoices =
            new Map<Id, Invoice__c>([
                SELECT Id, PaymentStatus__c
                FROM Invoice__c
                WHERE Id IN :new Set<Id>{
                    normal.Id,
                    srat.Id
                }
            ]);

        System.assertEquals(
            'Makulerad',
            invoices.get(normal.Id).PaymentStatus__c
        );

        System.assertEquals(
            'Ej betald',
            invoices.get(srat.Id).PaymentStatus__c
        );

        Callout__c log = [
            SELECT Status__c, Code__c
            FROM Callout__c
            WHERE jobId__c = :jobId
            LIMIT 1
        ];

        System.assertEquals('OK', log.Status__c);
        System.assertEquals('200', log.Code__c);
    }

    @IsTest
    static void failedCancellation() {

        Account account = createAccount();

        TestDataFactory.setupBasicTestData();

        Invoice__c invoice = createInvoice(
            account.Id,
            'TEST-NORMAL',
            null,
            'Ej betald'
        );

        Test.setMock(
            HttpCalloutMock.class,
            new BillectaMock(500)
        );

        Test.startTest();

        Id jobId = enqueueWithLog(
            new List<Invoice__c>{ invoice }
        );

        Test.stopTest();

        Invoice__c result = [
            SELECT PaymentStatus__c
            FROM Invoice__c
            WHERE Id = :invoice.Id
        ];

        System.assertEquals(
            'Ej betald',
            result.PaymentStatus__c
        );

        Callout__c log = [
            SELECT Status__c
            FROM Callout__c
            WHERE jobId__c = :jobId
            LIMIT 1
        ];

        System.assertEquals('Failed', log.Status__c);
    }

    @IsTest
    static void emptyInvoiceList() {

        Test.startTest();

        Id jobId = enqueueWithLog(
            new List<Invoice__c>()
        );

        Test.stopTest();

        Callout__c log = [
            SELECT Status__c, Response__c
            FROM Callout__c
            WHERE jobId__c = :jobId
            LIMIT 1
        ];

        System.assertEquals('OK', log.Status__c);
        System.assertEquals(
            'No invoices to cancel',
            log.Response__c
        );
    }

    @IsTest
    static void onlyExcludedInvoices() {

        Account account = createAccount();

        Invoice__c srat = createInvoice(
            account.Id,
            'TEST-SRAT',
            'Dubbelansluten SRAT',
            'Ej betald'
        );

        Test.startTest();

        Id jobId = enqueueWithLog(
            new List<Invoice__c>{ srat }
        );

        Test.stopTest();

        Callout__c log = [
            SELECT Status__c, Response__c
            FROM Callout__c
            WHERE jobId__c = :jobId
            LIMIT 1
        ];

        System.assertEquals('OK', log.Status__c);
        System.assertEquals(
            'No eligible invoices to cancel',
            log.Response__c
        );
    }
}
