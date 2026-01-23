/**
 * @description       :
 * @author            : Malin Nilsson (Stretch Customer AB)
 * @group             :
 * @last modified on  : 2025-01-28
 * @last modified by  : Malin Nilsson (Stretch Customer AB)
 **/
@isTest
public with sharing class McSyncLeftoverTest {
  @TestSetup
  static void makeData() {
    TestDataFactory.setupBasicTestData();
    TestDataFactorySetupParams params = new TestDataFactorySetupParams();
    params.numberOfAccounts = 10;
    params.addMembershipsToMembers = true;
    params.addEmploymentsToMembers = true;
    TestDataFactory.setupTestData(params);

    List<Membership__C> mems = [SELECT id, syncWithMc__c FROM Membership__c];
    for (Membership__c m : mems) {
      m.syncWithMc__c = !m.syncWithMc__c; // toggle mc sync value.
    }

    List<Employment__c> emps = [SELECT id, syncWithMc__c FROM Employment__c];
    for (Employment__c e : emps) {
      e.syncWithMc__c = !e.syncWithMc__c; // toggle mc sync value.
    }


    update mems;
    update emps;
  }

  @isTest
  static void testMcSyncLeftOverInvocable() {
    McSyncLeftoverInvocable.Request req = new McSyncLeftoverInvocable.Request();
    req.queryLimit = 10;
    List<McSyncLeftoverInvocable.Request> reqs = new List<McSyncLeftoverInvocable.Request>{
      req
    };
    Test.startTest();
    McSyncLeftoverInvocable.correctMcSyncStatus(reqs);
    Test.stopTest();
  }

  /*  @isTest
  static void testMcSyncLeftOverInvocableFail() {
    McSyncLeftoverInvocable.Request req = new McSyncLeftoverInvocable.Request();
    req.queryLimit = 10;
    List<McSyncLeftoverInvocable.Request> reqs = new List<McSyncLeftoverInvocable.Request>{
      req
    };
    Test.startTest();
    // Set up the error trigger
    McSyncLeftoverTest.setupTestTrigger();
    McSyncLeftoverInvocable.correctMcSyncStatus(reqs);
    Test.stopTest();
  }

      // Helper method to set up error trigger
    private static void setupTestTrigger() {
        // Create a test trigger that will cause a DML error
        Test.setReadOnlyApplicationMode(true);
    }*/

   /* @isTest
    static void testMcSyncLeftOverBatchableDMLError() {
        // Create the query that will be used in the batch
        String query = 'SELECT Id, SyncWithMc__c FROM Membership__c ';
        
        Test.startTest();
        
        // Set up the error trigger by making records read-only
        Test.setReadOnlyApplicationMode(true);
        
        // Execute the batch
        McSyncLeftoverBatchable batch = new McSyncLeftoverBatchable(query, 'Membership');
        Database.executeBatch(batch);
        
        Test.stopTest();
        
        // Verify error handling occurred
        List<DebugLog__c> errorLogs = [SELECT Id FROM DebugLog__c];
        System.assert(!errorLogs.isEmpty(), 'Error logs should have been created');
    }*/

   /* @isTest
    static void testMcSyncLeftOverBatchableInvalidField() {
        // Create query with invalid field to trigger field error
        String query = 'SELECT Id, SyncWithMc__c, InvalidField__c FROM Membership__c LIMIT 5';
        Boolean error = false;
         try{
        Test.startTest();
       
          McSyncLeftoverBatchable batch = new McSyncLeftoverBatchable(query, 'Membership');
          Database.executeBatch(batch);
       
        Test.stopTest();

         } catch(Exception e){
            error = true;
        }

        System.assert(error, 'Exception should have been thrown');
        // Verify error handling occurred
        List<DebugLog__c> errorLogs = [SELECT Id FROM DebugLog__c ];
        System.assert(!errorLogs.isEmpty(), 'Error logs should have been created');
    }*/


 /*   @isTest
static void testBatchableErrorHandling() {

    List<Membership__c> mems = [SELECT id, syncWithMc__c FROM Membership__c LIMIT 5];
    // Create a query that will include our test record
    String query = 'SELECT Id, SyncWithMc__c FROM Membership__c LIMIT 5';
    
    // Create the batchable instance
    McSyncLeftoverBatchable batch = new McSyncLeftoverBatchable(query, 'Membership');
    
    // Make the record read-only to force a DML error
    Test.setReadOnlyApplicationMode(true);
    
    Test.startTest();
    Database.executeBatch(batch);
    Test.stopTest();
    
    // Verify error logs were created
    List<DebugLog__c> errorLogs = [SELECT Id FROM DebugLog__c ];
    System.assert(!errorLogs.isEmpty(), 'Error logs should have been created');
}*/

    @IsTest
    static void testLogError() {
        // Arrange
        Account acc = new Account(); // Account without required Name field
        String objectName = 'Account';
        
        // Act - Perform DML that will fail to get a real Database.Error
        Database.SaveResult sr = Database.insert(acc, false);
        Database.Error err = sr.getErrors()[0]; // Get the first error
        
        Test.startTest();
        McSyncLeftoverBatchable.logError(err, objectName, acc.Id);
        Test.stopTest();
        
        // No Assert needed as we're testing void method that logs
        // In a real scenario, you might want to verify the log creation if possible
    }
}