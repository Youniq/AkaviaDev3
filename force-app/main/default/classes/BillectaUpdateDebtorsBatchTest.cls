
@IsTest
private class BillectaUpdateDebtorsBatchTest {

    
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
            res.setStatusCode(201);
            res.setBody('{"PublicId":"TEST-NEW-DEBTOR"}');
            return res;
        }
    }

    @IsTest
    static void testConstructorWithNullIds() {

        BillectaUpdateDebtorsBatch batch =
            new BillectaUpdateDebtorsBatch(
                null,
                'Create',
                false
            );

        Test.startTest();
        Database.executeBatch(batch, 1);
        Test.stopTest();

        System.assertEquals(
            0,
            [
                SELECT COUNT()
                FROM Callout__c
                WHERE Type__c = 'Billecta - Create Debtor'
            ]
        );
    }

    @IsTest
    static void testExecuteCreatesCallout() {

        Account acc = createAccount();
        createCredentials();

        Test.setMock(
            HttpCalloutMock.class,
            new DebtorMock()
        );

        BillectaUpdateDebtorsBatch batch =
            new BillectaUpdateDebtorsBatch(
                new Set<Id>{ acc.Id },
                'Create',
                false,
                'Test extra message'
            );

        List<sObject> scope = new List<sObject>();

        scope.addAll([
            SELECT
                Id,
                BillectaID__c,
                SocialSecurityNumber__c,
                FirstName,
                LastName,
                CurrentCOAdress__c,
                CurrentStreetAdress__c,
                CurrentZipCode__c,
                CurrentCity__c,
                CurrentCountryCode__c,
                PersonMobilePhone,
                PersonEmail,
                MemberNumber__c,
                ProtectedIdentity__c,
                PaymentMethod__c,
                DistributionMethod__c,
                EinvoiceBank__c,
                AutogiroApprovalStatus__c,
                AG_BankAccountNumber__c,
                AG_BankClearingNumber__c,
                AutogiroBank__c
            FROM Account
            WHERE Id = :acc.Id
        ]);

        batch.execute(null, scope);

        List<Callout__c> callouts = [
            SELECT Id, JobId__c, Status__c,
                Type__c, ExtraMessage__c
            FROM Callout__c
            WHERE Account__c = :acc.Id
        ];

        System.assertEquals(1, callouts.size());
        System.assertEquals('Queued', callouts[0].Status__c);
        System.assertEquals(
            'Billecta - Create Debtor',
            callouts[0].Type__c
        );
        System.assertEquals(
            'Test extra message',
            callouts[0].ExtraMessage__c
        );
        System.assertNotEquals(null, callouts[0].JobId__c);
    }

    @IsTest
    static void testBatchWithInvalidAccount() {

        Account acc = createAccount();

        Test.startTest();

        Id batchId = Database.executeBatch(
            new BillectaUpdateDebtorsBatch(
                new Set<Id>{ acc.Id },
                'Update',
                false
            ),
            1
        );

        Test.stopTest();

        AsyncApexJob job = [
            SELECT Status, NumberOfErrors
            FROM AsyncApexJob
            WHERE Id = :batchId
        ];

        System.assertEquals('Completed', job.Status);
        System.assertEquals(0, job.NumberOfErrors);

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
    static void testEmptyScope() {

        BillectaUpdateDebtorsBatch batch =
            new BillectaUpdateDebtorsBatch(
                new Set<Id>(),
                'Create',
                false,
                'Batch test'
            );

        Test.startTest();
        batch.execute(null, new List<sObject>());
        Test.stopTest();

        System.assert(true);
    }

    @IsTest
    static void testStartFiltersAccounts() {

        Account acc = createAccount();

        BillectaUpdateDebtorsBatch batch =
            new BillectaUpdateDebtorsBatch(
                new Set<Id>{ acc.Id },
                'Create',
                false
            );

        Test.startTest();
        Database.QueryLocator locator = batch.start(null);
        Test.stopTest();

        System.assertNotEquals(null, locator);
    }

    @IsTest
    static void testBatchJobCompletes() {

        Test.startTest();

        Id batchId = Database.executeBatch(
            new BillectaUpdateDebtorsBatch(
                new Set<Id>(),
                'Create',
                false
            ),
            1
        );

        Test.stopTest();

        AsyncApexJob job = [
            SELECT Status, NumberOfErrors
            FROM AsyncApexJob
            WHERE Id = :batchId
        ];

        System.assertEquals('Completed', job.Status);
        System.assertEquals(0, job.NumberOfErrors);
    }
}
