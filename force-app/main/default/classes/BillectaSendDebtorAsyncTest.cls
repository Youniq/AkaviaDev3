
@IsTest
private class BillectaSendDebtorAsyncTest {

    @IsTest
    static void testBillectaHttp500() {

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

        // Create Billecta configuration for the test.
        insert new Billecta__c(
            Creditor__c = 'TEST-CREDITOR'
        );

        // Existing Billecta debtor.
        Account debtor = new Account(
            Id = acc.Id,
            BillectaID__c = 'TEST-BILLECTA-ID'
        );

        BillectaSendDebtorAsync service =
            new BillectaSendDebtorAsync(
                debtor,
                true
            );

        Callout__c co = new Callout__c(
            Account__c = acc.Id,
            Type__c = 'Billecta - Update Debtor',
            Status__c = 'Queued'
        );

        Test.startTest();

        Callout__c result = service.sendToBillecta(co);

        Test.stopTest();

        System.assertEquals(
            'Failed',
            result.Status__c,
            'HTTP 500 should mark Callout as Failed.'
        );

        System.assert(
            !String.isBlank(result.ErrorLog__c),
            'ErrorLog should contain error details.'
        );
    }
}
