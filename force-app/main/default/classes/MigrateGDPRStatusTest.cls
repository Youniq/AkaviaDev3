@isTest
public class MigrateGDPRStatusTest {
    
    @TestSetup
    static void Setup(){
        System.debug('*** MigrateGDPRStatusTest Setup() starting ***');
        TestDataFactorySetupParams setupParams = new TestDataFactorySetupParams();
        setupParams.numberOfAccounts = 1;
        setupParams.cancelledAccounts = true;
        TestDataFactory.createTestAccounts(setupParams);
    }
    
    @isTest 
    static void TestSetGDPRStatusField() {
        
        //List<Account> DataBeforeTest = [Select Id from Account Where GDPRStatus__c != null];   
        test.startTest();
        new MigrateGDPRStatus();
        test.stopTest();
        List<Account> DataAfterTest = [Select Id from Account Where GDPRStatus__c != null];
        System.assertEquals(1, DataAfterTest.Size());

    }
}