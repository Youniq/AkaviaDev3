
/**
 * @description       : Test for Invoice Helper
 * @author            : Håkon Kavli
 * @group             : Stretch
 * @last modified on  : 2026-11-13
 **/
@IsTest
public with sharing class InvoiceHelperTest {

    @TestSetup
    static void makeData() {

        TestDataFactorySetupParams params =
            new TestDataFactorySetupParams();

        params.numberOfAccounts = 1;
        params.numberOfPaidInvoices = 10;
        params.numberOfUnpaidInvoices = 3;

        TestDataFactory.setupTestData(params);
    }

    @IsTest
    private static void testGetInvoices() {

        Account personAccount = [
            SELECT Id
            FROM Account
            LIMIT 1
        ];

        Test.startTest();

        List<Invoice__c> invoices =
            InvoiceHelper.getInvoices(
                String.valueOf(personAccount.Id),
                2
            );

        Test.stopTest();

        System.assertEquals(
            2,
            invoices.size(),
            'List has two items'
        );
    }

    @IsTest
    private static void testGetUnpaidInvoices() {

        Account personAccount = [
            SELECT Id
            FROM Account
            LIMIT 1
        ];

        Test.startTest();

        List<Invoice__c> invoices =
            InvoiceHelper.getUnpaidInvoices(
                String.valueOf(personAccount.Id)
            );

        Test.stopTest();

        System.assertEquals(
            3,
            invoices.size(),
            'List has three unpaid invoices'
        );
    }

    @IsTest
    private static void testInvoicesForAccounts() {

        Account account = [
            SELECT Id
            FROM Account
            LIMIT 1
        ];

        List<Invoice__c> unpaidInvoices = [
            SELECT
                Id,
                BillectaID__c,
                PaymentStatus__c,
                FeeCategory__c
            FROM Invoice__c
            WHERE Person__c = :account.Id
            AND PaymentStatus__c = 'Ej betald'
            ORDER BY CreatedDate
            LIMIT 3
        ];

        System.assertEquals(
            3,
            unpaidInvoices.size(),
            'Tre obetalda fakturor ska finnas.'
        );

        // Vanlig faktura
        unpaidInvoices[0].FeeCategory__c = null;

        // SRAT-faktura ska exkluderas
        unpaidInvoices[1].FeeCategory__c =
            'Dubbelansluten SRAT';

        // Faktura utan BillectaID ska exkluderas
        unpaidInvoices[2].FeeCategory__c = null;
        unpaidInvoices[2].BillectaID__c = null;

        update unpaidInvoices;

        Test.startTest();

        List<Invoice__c> result =
            InvoiceHelper.invoicesForAccounts(
                new Set<Id>{ account.Id }
            );

        Test.stopTest();

        System.assertEquals(
            1,
            result.size(),
            'Endast en faktura ska vara giltig.'
        );

        System.assertEquals(
            unpaidInvoices[0].Id,
            result[0].Id,
            'Endast vanlig obetald faktura ska returneras.'
        );
    }

    @IsTest
    private static void testInvoicesForAccountsEmptySet() {

        Test.startTest();

        List<Invoice__c> result =
            InvoiceHelper.invoicesForAccounts(
                new Set<Id>()
            );

        Test.stopTest();

        System.assertEquals(
            0,
            result.size(),
            'Tom Set ska returnera tom lista.'
        );
    }

    @IsTest
    private static void testInvoicesForAccountsNull() {

        Test.startTest();

        List<Invoice__c> result =
            InvoiceHelper.invoicesForAccounts(null);

        Test.stopTest();

        System.assertEquals(
            0,
            result.size(),
            'Null ska returnera tom lista.'
        );
    }

    @IsTest
    private static void testInvoicesForAccountsPaidInvoices() {

        Account account = [
            SELECT Id
            FROM Account
            LIMIT 1
        ];

        Test.startTest();

        List<Invoice__c> result =
            InvoiceHelper.invoicesForAccounts(
                new Set<Id>{ account.Id }
            );

        Test.stopTest();

        // Endast de tre obetalda fakturorna
        // ska returneras från ursprunglig testdata.
        System.assertEquals(
            3,
            result.size(),
            'Betalda fakturor ska exkluderas.'
        );

        for (Invoice__c invoice : result) {

            System.assertNotEquals(
                'Betald',
                invoice.PaymentStatus__c
            );

            System.assertNotEquals(
                'Dubbelansluten SRAT',
                invoice.FeeCategory__c
            );
        }
    }
}
