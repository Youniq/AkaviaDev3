
@IsTest
private class BillectaSendDebtorFinalizerTest {

    @IsTest
    static void testMarkCalloutFailed() {

        Account acc = new Account(
            LastName = 'Billecta Finalizer Test'
        );
        insert acc;

        String jobId = 'TEST-JOB-001';

        Callout__c co = new Callout__c(
            Account__c = acc.Id,
            JobId__c = jobId,
            Type__c = 'Billecta - Update Debtor',
            Status__c = 'Queued'
        );
        insert co;

        Test.startTest();

        BillectaSendDebtorFinalizer.markCalloutFailed(
            jobId,
            'Simulated Queueable failure'
        );

        Test.stopTest();

        Callout__c result = [
            SELECT Status__c, ErrorLog__c, SentOn__c
            FROM Callout__c
            WHERE Id = :co.Id
        ];

        System.assertEquals(
            'Failed',
            result.Status__c
        );

        System.assert(
            result.ErrorLog__c.contains(
                'Simulated Queueable failure'
            )
        );

        System.assertNotEquals(
            null,
            result.SentOn__c
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
}
