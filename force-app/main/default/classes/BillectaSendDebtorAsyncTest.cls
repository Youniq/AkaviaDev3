
@IsTest
private class BillectaSendDebtorAsyncTest {

    @IsTest
    static void testBillectaHttp500() {

        // Simulate Billecta returning HTTP 500.
        Test.setMock(
            HttpCalloutMock.class,
            new BillectaHttpMock(
                500,
                '{"error":"Simulated Billecta failure"}'
            )
        );

        Account acc = new Account(
            LastName = 'Billecta Test'
        );
        insert acc;

        // Existing debtor ensures GET Debtor is called.
        // This test uses a detached Account object
        // to avoid updating real Billecta data.
        Account debtor = new Account(
            Id = acc.Id,
            BillectaID__c = 'TEST-BILLECTA-ID'
        );

        Test.startTest();

        Id jobId = System.enqueueJob(
            new BillectaSendDebtorAsync(
                debtor,
                true
            )
        );

        insert new Callout__c(
            JobId__c = String.valueOf(jobId),
            Account__c = acc.Id,
            Type__c = 'Billecta - Update Debtor',
            Status__c = 'Queued'
        );

        Test.stopTest();

        Callout__c result = [
            SELECT Status__c, ErrorLog__c
            FROM Callout__c
            WHERE JobId__c = :String.valueOf(jobId)
            LIMIT 1
        ];

        System.assertEquals(
            'Failed',
            result.Status__c,
            'HTTP 500 should mark Callout as Failed.'
        );

        System.assert(
            result.ErrorLog__c != null &&
            result.ErrorLog__c.contains('500'),
            'HTTP status code should be logged.'
        );
    }
}
