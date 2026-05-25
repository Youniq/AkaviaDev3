@isTest
private class GdprRegisterutdragControllerTest {

    @TestSetup
    static void makeData() {
        TestDataFactory.setupBasicTestData();
        TestDataFactorySetupParams params = new TestDataFactorySetupParams();
        params.numberOfAccounts = 1;
        TestDataFactory.setupTestData(params);
    }

    private static Id getPersonAccountId() {
        return [SELECT Id FROM Account WHERE IsPersonAccount = TRUE LIMIT 1].Id;
    }

    @isTest
    static void testGenerateForAccount_Null() {
        GdprRegisterutdragService.Result r = GdprRegisterutdragController.generateForAccount(null);
        System.assertNotEquals(null, r);
        System.assertEquals(false, r.success);
    }

    @isTest
    static void testGenerateForAccount_Success() {
        Id accountId = getPersonAccountId();

        Test.startTest();
        GdprRegisterutdragService.Result r = GdprRegisterutdragController.generateForAccount(accountId);
        Test.stopTest();

        System.assertNotEquals(null, r);
        System.assertEquals(true, r.success, r.message);
        System.assertNotEquals(null, r.contentDocumentId);
    }

    @isTest
    static void testGenerateForAccountWithFormat_Success() {
        Id accountId = getPersonAccountId();

        Test.startTest();
        GdprRegisterutdragService.Result r = GdprRegisterutdragController.generateForAccountWithFormat(
            accountId,
            'CSV'
        );
        Test.stopTest();

        System.assertNotEquals(null, r);
        System.assertEquals(true, r.success, r.message);
    }
}