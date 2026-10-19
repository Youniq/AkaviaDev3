
/**
 * @description       : Tests BillectaSendDebtorFinalizer.
 * @last modified on  : 2026-10-19
 * @last modified by  : Stefan Trieton (Stretch Customer AB)
 */
@IsTest
private class BillectaSendDebtorFinalizerTest {

    /**
     * Queueable used to simulate an unhandled exception.
     */
    private class FailingQueueable implements Queueable {

        public void execute(QueueableContext context) {

            System.attachFinalizer(
                new BillectaSendDebtorFinalizer()
            );

            // Simulate an unhandled exception.
            throw new TestException(
                'Simulated Billecta failure'
            );
        }
    }

    private class SuccessfulQueueable implements Queueable {

        public void execute(QueueableContext context) {

            System.attachFinalizer(
                new BillectaSendDebtorFinalizer()
            );
        }
    }

    private class TestException extends Exception {}

    /**
     * Creates a Callout__c tracking record.
     */
    private static void createCallout(Id jobId) {

        insert new Callout__c(
            JobId__c = String.valueOf(jobId),
            Type__c = 'Billecta - Update Debtor',
            Status__c = 'Queued'
        );
    }

    /**
     * Verifies that an unhandled Queueable exception
     * is handled by the Finalizer.
     */
    @IsTest
    static void testFailedQueueable() {

        Test.startTest();

        Id jobId = System.enqueueJob(
            new FailingQueueable()
        );

        createCallout(jobId);

        Test.stopTest();

        Callout__c result = [
            SELECT Status__c, ErrorLog__c, SentOn__c
            FROM Callout__c
            WHERE JobId__c = :String.valueOf(jobId)
            LIMIT 1
        ];

        System.assertEquals(
            'Failed',
            result.Status__c,
            'Finalizer should mark Callout as Failed.'
        );

        System.assert(
            result.ErrorLog__c != null &&
            result.ErrorLog__c.contains('Simulated Billecta failure'),
            'Finalizer should save the exception message.'
        );

        System.assertNotEquals(
            null,
            result.SentOn__c,
            'Finalizer should set SentOn.'
        );
    }

    /**
     * Verifies that successful Queueable jobs
     * do not change Callout status.
     */
    @IsTest
    static void testSuccessfulQueueable() {

        Test.startTest();

        Id jobId = System.enqueueJob(
            new SuccessfulQueueable()
        );

        createCallout(jobId);

        Test.stopTest();

        Callout__c result = [
            SELECT Status__c
            FROM Callout__c
            WHERE JobId__c = :String.valueOf(jobId)
            LIMIT 1
        ];

        System.assertEquals(
            'Queued',
            result.Status__c,
            'Finalizer should not modify successful jobs.'
        );
    }

    /**
     * Verifies that the Finalizer handles
     * a missing Callout__c record.
     */
    @IsTest
    static void testMissingCallout() {

        Test.startTest();

        System.enqueueJob(
            new FailingQueueable()
        );

        Test.stopTest();

        // The Finalizer should handle a missing
        // Callout__c without causing another failure.
    }
}
