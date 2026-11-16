
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

        TestDataFactorySetupParams params =
            new TestDataFactorySetupParams();

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

    // Callout__c.jobId__c lagrar endast 15 tecken.
    // Salesforce Queueable Job ID returneras med 18 tecken.
    // Använd samma format vid lagring och uppslag.
    // TODO: Utöka jobId__c till 18 tecken och använd hela ID:t.
    private static String getJobId15(Id jobId) {

        return String.valueOf(jobId).substring(0, 15);
    }

    private static Id enqueueWithLog(
        List<Invoice__c> invoices
    ) {

        Id jobId = System.enqueueJob(
            new BillectaCancelInvociesQueuable(invoices)
        );

        String jobId15 = getJobId15(jobId);

        insert new Callout__c(
            jobId__c = jobId15,
            Type__c = 'Billecta - Cancel Invoices',
            Status__c = 'Queued'
        );

        List<Callout__c> savedLogs = [
            SELECT Id, jobId__c, Status__c
            FROM Callout__c
            WHERE jobId__c = :jobId15
        ];

        System.assertEquals(
            1,
            savedLogs.size(),
            'Callout__c måste finnas innan Queueable-jobbet körs.'
        );

        System.assertEquals(
            'Queued',
            savedLogs[0].Status__c
        );

        return jobId;
    }

    private static Callout__c getCalloutLog(Id jobId) {

        String jobId15 = getJobId15(jobId);

        List<Callout__c> logs = [
            SELECT Id,
                   jobId__c,
                   Status__c,
                   Code__c,
                   Response__c,
                   errorLog__c
            FROM Callout__c
            WHERE jobId__c = :jobId15
            LIMIT 1
        ];

        System.assertEquals(
            1,
            logs.size(),
            'Callout__c saknas för Queueable Job ID: ' +
            jobId15
        );

        return logs[0];
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
            new List<Invoice__c>{
                normal,
                srat
            }
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
            invoices.get(normal.Id).PaymentStatus__c,
            'Vanlig faktura ska makuleras.'
        );

        System.assertEquals(
            'Ej betald',
            invoices.get(srat.Id).PaymentStatus__c,
            'SRAT-faktura får inte makuleras.'
        );

        Callout__c log = getCalloutLog(jobId);

        System.assertEquals(
            'OK',
            log.Status__c,
            'Callout ska ha status OK.'
        );

        System.assertEquals(
            '200',
            log.Code__c,
            'Billecta ska returnera HTTP 200.'
        );

        System.assert(
            log.Response__c.contains('"success":true'),
            'Billecta ska returnera success=true.'
        );
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
            SELECT Id, PaymentStatus__c
            FROM Invoice__c
            WHERE Id = :invoice.Id
        ];

        System.assertEquals(
            'Ej betald',
            result.PaymentStatus__c,
            'Fakturan får inte makuleras vid HTTP 500.'
        );

        Callout__c log = getCalloutLog(jobId);

        System.assertEquals(
            'Failed',
            log.Status__c,
            'Callout ska ha status Failed.'
        );

        System.assertEquals(
            '500',
            log.Code__c,
            'Billecta ska returnera HTTP 500.'
        );
    }

    @IsTest
    static void emptyInvoiceList() {

        Test.startTest();

        Id jobId = enqueueWithLog(
            new List<Invoice__c>()
        );

        Test.stopTest();

        Callout__c log = getCalloutLog(jobId);

        System.assertEquals(
            'OK',
            log.Status__c,
            'Tom fakturalista ska hanteras utan fel.'
        );

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

        Invoice__c result = [
            SELECT Id, PaymentStatus__c
            FROM Invoice__c
            WHERE Id = :srat.Id
        ];

        System.assertEquals(
            'Ej betald',
            result.PaymentStatus__c,
            'SRAT-faktura får inte makuleras.'
        );

        Callout__c log = getCalloutLog(jobId);

        System.assertEquals(
            'OK',
            log.Status__c,
            'Exkluderade fakturor ska hanteras utan fel.'
        );

        System.assertEquals(
            'No eligible invoices to cancel',
            log.Response__c
        );
    }
}
