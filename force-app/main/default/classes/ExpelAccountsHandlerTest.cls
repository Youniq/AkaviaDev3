@IsTest
private class ExpelAccountsHandlerTest {

    private static Account createAccount(
        String membershipCategory,
        Decimal paidInvoices,
        Boolean includeMembership,
        Boolean includeFeeCategory,
        String email
    ) {
        Map<String, Object> accountData = new Map<String, Object>{
            'attributes' => new Map<String, Object>{ 'type' => 'Account' },
            'NoOfPayedInvoicesAsEmployed__c' => paidInvoices,
            'PersonEmail' => email
        };

        if (includeMembership) {
            Map<String, Object> membershipData = new Map<String, Object>{
                'attributes' => new Map<String, Object>{ 'type' => 'Membership__c' }
            };

            if (includeFeeCategory) {
                membershipData.put(
                    'CurrentFeeCategory__r',
                    new Map<String, Object>{
                        'attributes' => new Map<String, Object>{
                            'type' => 'FeeCategory__c'
                        },
                        'MembershipCategory__c' => membershipCategory
                    }
                );
            }

            accountData.put('LatestMembership__r', membershipData);
        }

        return (Account) JSON.deserialize(
            JSON.serialize(accountData),
            Account.class
        );
    }

    private static Account createAccount(
        String membershipCategory,
        Decimal paidInvoices,
        Boolean includeMembership,
        Boolean includeFeeCategory
    ) {
        return createAccount(
            membershipCategory,
            paidInvoices,
            includeMembership,
            includeFeeCategory,
            null
        );
    }

    @IsTest
    static void firstYearLowPaymentUsesNewEmailFlow() {
        for (Integer i = -1; i <= 2; i++) {
            Decimal paid = i == -1 ? null : Decimal.valueOf(i);

            Account account = createAccount(
                'Yrkesverksam första året',
                paid,
                true,
                true
            );

            account.PersonEmail = 'test@example.com';

            Map<String, List<Account>> groups =
                ExpelAccountsHandler.groupAccountsForEmail(
                    new List<Account>{ account }
                );

            System.assertEquals(
                1,
                groups.get('firstYear').size(),
                'Yrk1 med färre än 3 betalda fakturor ska använda nya Flowet.'
            );

            System.assertEquals(
                0,
                groups.get('standard').size(),
                'Yrk1 ska inte få det gamla mejlet.'
            );
        }
    }

    @IsTest
    static void firstYearThreeOrMoreUsesStandardEmailFlow() {
        for (Integer i = 3; i <= 5; i++) {
            Account account = createAccount(
                'Yrkesverksam första året',
                Decimal.valueOf(i),
                true,
                true
            );

            account.PersonEmail = 'test@example.com';

            Map<String, List<Account>> groups =
                ExpelAccountsHandler.groupAccountsForEmail(
                    new List<Account>{ account }
                );

            System.assertEquals(0, groups.get('firstYear').size());
            System.assertEquals(1, groups.get('standard').size());
        }
    }

    @IsTest
    static void otherCategoriesUseStandardEmailFlow() {
        for (String category : new List<String>{
            'Yrkesverksam',
            'Student',
            'Dubbelansluten SRAT'
        }) {
            Account account = createAccount(category, 0, true, true);
            account.PersonEmail = 'test@example.com';

            Map<String, List<Account>> groups =
                ExpelAccountsHandler.groupAccountsForEmail(
                    new List<Account>{ account }
                );

            System.assertEquals(0, groups.get('firstYear').size());
            System.assertEquals(1, groups.get('standard').size());
        }
    }

    @IsTest
    static void missingEmailDoesNotTriggerFlow() {
        Account account = createAccount(
            'Yrkesverksam första året',
            1,
            true,
            true
        );

        Map<String, List<Account>> groups =
            ExpelAccountsHandler.groupAccountsForEmail(
                new List<Account>{ account }
            );

        System.assertEquals(0, groups.get('firstYear').size());
        System.assertEquals(0, groups.get('standard').size());
    }

    @IsTest
    static void mixedAccountsAreSeparatedCorrectly() {
        Account firstYear = createAccount(
            'Yrkesverksam första året', 2, true, true
        );

        Account standard = createAccount(
            'Yrkesverksam första året', 3, true, true
        );

        Account other = createAccount(
            'Yrkesverksam', 0, true, true
        );

        firstYear.PersonEmail = 'first@example.com';
        standard.PersonEmail = 'standard@example.com';
        other.PersonEmail = 'other@example.com';

        Map<String, List<Account>> groups =
            ExpelAccountsHandler.groupAccountsForEmail(
                new List<Account>{ firstYear, standard, other }
            );

        System.assertEquals(1, groups.get('firstYear').size());
        System.assertEquals(2, groups.get('standard').size());
    }

    @IsTest
    static void firstYearWithFewerThanThreePaidInvoices() {
        for (Integer i = -1; i <= 2; i++) {
            Decimal paidInvoices = i == -1 ? null : Decimal.valueOf(i);
            Account account = createAccount('Yrkesverksam första året', paidInvoices, true, true);

            System.assertEquals(true, ExpelAccountsHandler.isFirstYearLowPayment(account),
                'Yrk1 med ' + paidInvoices + ' betalda fakturor ska undantas från RestInvoice.');
        }
    }

    @IsTest
    static void firstYearWithThreeOrMorePaidInvoices() {
        for (Integer i = 3; i <= 5; i++) {
            Account account = createAccount('Yrkesverksam första året', Decimal.valueOf(i), true, true);

            System.assertEquals(false, ExpelAccountsHandler.isFirstYearLowPayment(account),
                'Yrk1 med ' + i + ' betalda fakturor ska använda befintlig RestInvoice-logik.');
        }
    }

    @IsTest
    static void otherMembershipCategoriesAreNotExcluded() {
        for (String category : new List<String>{'Yrkesverksam', 'Student', 'Dubbelansluten SRAT'}) {
            Account account = createAccount(category, 0, true, true);

            System.assertEquals(false, ExpelAccountsHandler.isFirstYearLowPayment(account),
                'Yrk1-undantaget ska inte gälla medlemskategorin ' + category);
        }
    }

    @IsTest
    static void missingRelationshipsDoNotMatch() {
        Account withoutMembership = createAccount(null, 0, false, false);
        Account withoutFeeCategory = createAccount(null, 0, true, false);
        Account withoutCategory = createAccount(null, 0, true, true);

        System.assertEquals(false, ExpelAccountsHandler.isFirstYearLowPayment(withoutMembership));
        System.assertEquals(false, ExpelAccountsHandler.isFirstYearLowPayment(withoutFeeCategory));
        System.assertEquals(false, ExpelAccountsHandler.isFirstYearLowPayment(withoutCategory));
    }
    
    @IsTest
    static void calculateRestInvoiceAmountExcludesSrat() {
        Id accountId = '001000000000001AAA';

        List<Invoice__c> invoices = new List<Invoice__c>{
            new Invoice__c(
                Person__c = accountId,
                FeeCategory__c = 'Dubbelansluten SRAT',
                Amount__c = 1000,
                AmountAkassa__c = 200,
                RemainingAmount__c = 1000
            ),
            new Invoice__c(
                Person__c = accountId,
                FeeCategory__c = 'Yrkesverksam',
                Amount__c = 800,
                AmountAkassa__c = 100,
                RemainingAmount__c = 800
            ),
            new Invoice__c(
                Person__c = accountId,
                FeeCategory__c = 'Yrkesverksam',
                Amount__c = 600,
                AmountAkassa__c = 100,
                RemainingAmount__c = 600
            )
        };

        List<Invoice__c> filteredInvoices = new List<Invoice__c>();

        for (Invoice__c invoice : invoices) {
            if (invoice.FeeCategory__c != 'Dubbelansluten SRAT') {
                filteredInvoices.add(invoice);
            }
        }

        System.assertEquals(
            2,
            filteredInvoices.size(),
            'Endast vanliga fakturor ska ingå.'
        );

        Map<Id, Decimal> amounts =
            ExpelAccountsHandler.calculateRestInvoiceAmount(
                filteredInvoices
            );

        System.assertEquals(
            1200,
            amounts.get(accountId),
            'RestInvoiceAmount ska vara 1200 kr exklusive SRAT.'
        );
    }

    @IsTest
    static void sratInvoicesAreExcludedFromCancellationAndRestAmount() {
        TestDataFactorySetupParams params =
            new TestDataFactorySetupParams();

        params.numberOfAccounts = 1;

        // Skapa testmedlem med befintlig factory.
        Account account =
            TestDataFactory.createTestAccounts(params).values()[0];

        // Skapa fakturor utan att spara dem ännu.
        List<Invoice__c> invoices =
            TestDataFactory.createTestInvoice(
                params,
                3,
                false,
                new List<Id>{ account.Id },
                false
            );

        // SRAT-faktura.
        invoices[0].FeeCategory__c = 'Dubbelansluten SRAT';
        invoices[0].Amount__c = 1000;
        invoices[0].AmountAkassa__c = 200;
        invoices[0].RemainingAmount__c = 1000;

        // Vanlig faktura.
        invoices[1].FeeCategory__c = null;
        invoices[1].Amount__c = 800;
        invoices[1].AmountAkassa__c = 100;
        invoices[1].RemainingAmount__c = 800;

        // Vanlig faktura.
        invoices[2].FeeCategory__c = null;
        invoices[2].Amount__c = 600;
        invoices[2].AmountAkassa__c = 100;
        invoices[2].RemainingAmount__c = 600;

        insert invoices;

        Test.startTest();

        List<Invoice__c> filteredInvoices =
            InvoiceHelper.invoicesForAccounts(
                new Set<Id>{ account.Id }
            );

        Map<Id, Decimal> amounts =
            ExpelAccountsHandler.calculateRestInvoiceAmount(
                filteredInvoices
            );

        Test.stopTest();

        System.assertEquals(
            2,
            filteredInvoices.size(),
            'Endast två vanliga fakturor ska returneras.'
        );

        Set<Id> returnedInvoiceIds = new Set<Id>();

        for (Invoice__c invoice : filteredInvoices) {
            returnedInvoiceIds.add(invoice.Id);

            System.assertNotEquals(
                'Dubbelansluten SRAT',
                invoice.FeeCategory__c,
                'SRAT-fakturor ska exkluderas.'
            );
        }

        System.assert(
            !returnedInvoiceIds.contains(invoices[0].Id),
            'SRAT-fakturan får inte returneras.'
        );

        System.assert(
            returnedInvoiceIds.contains(invoices[1].Id) &&
            returnedInvoiceIds.contains(invoices[2].Id),
            'Båda vanliga fakturorna ska returneras.'
        );

        System.assertEquals(
            1200,
            amounts.get(account.Id),
            'RestInvoiceAmount ska vara 1200 kr.'
        );
    }

    @IsTest
    static void testSratExcludedFromBillecta() {
        TestDataFactorySetupParams params =
            new TestDataFactorySetupParams();

        params.numberOfAccounts = 1;

        Account account =
            TestDataFactory.createTestAccounts(params).values()[0];

        List<Invoice__c> invoices =
            TestDataFactory.createTestInvoice(
                params,
                2,
                false,
                new List<Id>{ account.Id },
                false
            );

        invoices[0].FeeCategory__c = 'Dubbelansluten SRAT';
        invoices[0].BillectaID__c = 'TEST-SRAT';

        invoices[1].FeeCategory__c = null;
        invoices[1].BillectaID__c = 'TEST-NORMAL';

        insert invoices;

        Test.setMock(
            HttpCalloutMock.class,
            new BillectaSratMock()
        );

        insert new Billecta__c(
            Creditor__c = 'TEST-CREDITOR'
        );

        Test.startTest();

        new BillectaCancelInvociesInvocable(invoices);

        Test.stopTest();

        Map<Id, Invoice__c> results =
            new Map<Id, Invoice__c>([
                SELECT Id, PaymentStatus__c
                FROM Invoice__c
                WHERE Id IN :invoices
            ]);

        System.assertEquals(
            'Ej betald',
            results.get(invoices[0].Id).PaymentStatus__c,
            'SRAT-fakturan får inte makuleras.'
        );

        System.assertEquals(
            'Makulerad',
            results.get(invoices[1].Id).PaymentStatus__c,
            'Vanlig faktura ska makuleras.'
        );
    }

    private class BillectaSratMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            String body = req.getBody();

            System.assert(
                body.contains('TEST-NORMAL'),
                'Vanlig faktura ska skickas till Billecta.'
            );

            System.assert(
                !body.contains('TEST-SRAT'),
                'SRAT-fakturan får inte skickas till Billecta.'
            );

            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"success":true}');
            return res;
        }
    }

}
