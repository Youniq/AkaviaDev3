
@IsTest
private class BillectaSendDebtorFinalizerTest {

    private class MockFinalizerContext implements FinalizerContext {

        private ParentJobResult result;
        private Id jobId;
        private Exception jobException;

        MockFinalizerContext(
            ParentJobResult result,
            Id jobId,
            Exception jobException
        ) {
            this.result = result;
            this.jobId = jobId;
            this.jobException = jobException;
        }

        public ParentJobResult getResult() {
            return result;
        }

        public Id getAsyncApexJobId() {
            return jobId;
        }

        public Exception getException() {
            return jobException;
        }

        public Id getRequestId() {
            return jobId;
        }
    }

    private static Account createAccount() {
        Account acc = new Account(
            LastName = 'Billecta Finalizer Test'
        );
        insert acc;
        return acc;
    }

    private static Callout__c createCallout(
        Id accountId,
        String jobId,
        String errorLog
    ) {
        Callout__c co = new Callout__c(
            Account__c = accountId,
            JobId__c = jobId,
            Type__c = 'Billecta - Update Debtor',
            Status__c = 'Queued',
            ErrorLog__c = errorLog
        );
        insert co;
        return co;
    }

    @IsTest
    static void testMarkCalloutFailed() {

        Account acc = createAccount();

        Callout__c co = createCallout(
            acc.Id,
            'TEST-JOB-001',
            null
        );

        Test.startTest();

        BillectaSendDebtorFinalizer.markCalloutFailed(
            'TEST-JOB-001',
            'Simulated Queueable failure'
        );

        Test.stopTest();

        Callout__c result = [
            SELECT Status__c, ErrorLog__c, SentOn__c
            FROM Callout__c
            WHERE Id = :co.Id
        ];

        System.assertEquals('Failed', result.Status__c);
        System.assert(
            result.ErrorLog__c.contains(
                'Simulated Queueable failure'
            )
        );
        System.assertNotEquals(null, result.SentOn__c);
    }

    @IsTest
    static void testExistingErrorLog() {

        Account acc = createAccount();

        Callout__c co = createCallout(
            acc.Id,
            'TEST-JOB-002',
            'Previous error'
        );

        Test.startTest();

        BillectaSendDebtorFinalizer.markCalloutFailed(
            'TEST-JOB-002',
            'New error'
        );

        Test.stopTest();

        Callout__c result = [
            SELECT Status__c, ErrorLog__c
            FROM Callout__c
            WHERE Id = :co.Id
        ];

        System.assertEquals('Failed', result.Status__c);
        System.assert(
            result.ErrorLog__c.contains('Previous error')
        );
        System.assert(
            result.ErrorLog__c.contains('New error')
        );
    }

    @IsTest
    static void testMissingCallout() {

        Test.startTest();

        BillectaSendDebtorFinalizer.markCalloutFailed(
            'NON-EXISTING-JOB',
            'Simulated failure'
        );

        Test.stopTest();

        System.assertEquals(
            0,
            [
                SELECT COUNT()
                FROM Callout__c
                WHERE JobId__c = 'NON-EXISTING-JOB'
            ]
        );
    }

    @IsTest
    static void testExecuteSuccess() {

        BillectaSendDebtorFinalizer finalizer =
            new BillectaSendDebtorFinalizer();

        MockFinalizerContext ctx =
            new MockFinalizerContext(
                ParentJobResult.SUCCESS,
                null,
                null
            );

        Test.startTest();
        finalizer.execute(ctx);
        Test.stopTest();

        System.assert(true);
    }

    @IsTest
    static void testExecuteUnhandledException() {

        Account acc = createAccount();

        Id jobId = System.enqueueJob(
            new DummyQueueable()
        );

        Callout__c co = createCallout(
            acc.Id,
            String.valueOf(jobId),
            null
        );

        MockFinalizerContext ctx =
            new MockFinalizerContext(
                ParentJobResult.UNHANDLED_EXCEPTION,
                jobId,
                new TestException('Simulated finalizer error')
            );

        Test.startTest();
        new BillectaSendDebtorFinalizer().execute(ctx);
        Test.stopTest();

        Callout__c result = [
            SELECT Status__c, ErrorLog__c
            FROM Callout__c
            WHERE Id = :co.Id
        ];

        System.assertEquals('Failed', result.Status__c);
        System.assert(
            result.ErrorLog__c.contains(
                'Simulated finalizer error'
            )
        );
    }

    private class TestException extends Exception {}

    private class DummyQueueable implements Queueable {
        public void execute(QueueableContext context) {}
    }
}
