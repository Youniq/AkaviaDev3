/**
 * @description       : 
 * @author            : Malin Nilsson (Stretch Customer AB)
 * @group             : 
 * @last modified on  : 2026-01-09
 * @last modified by  : Malin Nilsson (Stretch Customer AB)
**/
@IsTest
private class GetSobjectByIndexInvocableTest {
    
    @IsTest
    static void testGetSObjectByIndex() {
        TestDataFactorySetupParams params = new TestDataFactorySetupParams();
        params.numberOfAccounts = 3;
        TestDataFactory.setupTestData(params);
        List<Account> accounts = [SELECT Id, Name FROM Account];
        
        // Create input parameters
        GetSObjectByIndexInvocable.InputParams invParams = new GetSObjectByIndexInvocable.InputParams();
        invParams.recordList = accounts;
        invParams.index = 1; // Get second account
        
        // Test the invocable method
        Test.startTest();
        List<SObject> result = GetSObjectByIndexInvocable.getSObjectByIndex(new List<GetSObjectByIndexInvocable.InputParams>{invParams});
        Test.stopTest();
        
        // Verify results
        System.assertEquals(1, result.size(), 'Should return one result');
        System.assertNotEquals(null, result[0], 'Result should not be null');
        System.assertEquals(accounts[1].Id, ((Account)result[0]).Id, 'Should return the second account');
    }
    
    @IsTest
    static void testGetSObjectByIndexWithEmptyList() {
        // Create input parameters with empty list
        GetSObjectByIndexInvocable.InputParams params = new GetSObjectByIndexInvocable.InputParams();
        params.recordList = new List<Account>();
        params.index = 0;
        
        // Test the invocable method
        Test.startTest();
        List<SObject> result = GetSObjectByIndexInvocable.getSObjectByIndex(new List<GetSObjectByIndexInvocable.InputParams>{params});
        Test.stopTest();
        
        // Verify results
        System.assertEquals(1, result.size(), 'Should return one result');
        System.assertEquals(null, result[0], 'Result should be null for empty list');
    }
    
    @IsTest
    static void testGetSObjectByIndexOutOfBounds() {
        TestDataFactorySetupParams params = new TestDataFactorySetupParams();
        params.numberOfAccounts = 1;
        TestDataFactory.setupTestData(params);
        List<Account> accounts = [SELECT Id, Name FROM Account];
        
        // Create input parameters with index out of bounds
        GetSObjectByIndexInvocable.InputParams invParams = new GetSObjectByIndexInvocable.InputParams();
        invParams.recordList = accounts;
        invParams.index = 5; // Index larger than list size
        
        // Test the invocable method
        Test.startTest();
        List<SObject> result = GetSObjectByIndexInvocable.getSObjectByIndex(new List<GetSObjectByIndexInvocable.InputParams>{invParams});
        Test.stopTest();
        
        // Verify results
        System.assertEquals(1, result.size(), 'Should return one result');
        System.assertEquals(null, result[0], 'Result should be null for out of bounds index');
    }

    @IsTest
    static void testMultipleInputParams() {
        // Setup test data using TestDataFactory
        TestDataFactorySetupParams params = new TestDataFactorySetupParams();
        params.numberOfAccounts = 3;
        TestDataFactory.setupTestData(params);
        List<Account> accounts = [SELECT Id, Name FROM Account];

          // Create multiple input parameters
        List<GetSObjectByIndexInvocable.InputParams> inputs = new List<GetSObjectByIndexInvocable.InputParams>();
        Integer reqIndex = 0;   
        for(Account a : accounts) {
            GetSObjectByIndexInvocable.InputParams inputParam = new GetSObjectByIndexInvocable.InputParams();
            inputParam.index = reqIndex;
            inputParam.recordList = accounts;
            inputs.add(inputParam);    
            reqIndex++;
        }

        // Execute the invocable method
        Test.startTest();
        List<SObject> results = GetSObjectByIndexInvocable.getSObjectByIndex(inputs);
        Test.stopTest();

        // Verify results
        System.assertEquals(3, results.size(), 'Should return 3 records');
        System.assertEquals(accounts[0].Id, ((Account)results[0]).Id, 'First result should match first account');
        System.assertEquals(accounts[1].Id, ((Account)results[1]).Id, 'Second result should match second account');
        System.assertEquals(accounts[2].Id, ((Account)results[2]).Id, 'Third result should match third account');
    }
}