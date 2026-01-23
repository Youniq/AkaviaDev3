/**
 * @description       :
 * @author            : Malin Nilsson (Stretch Customer AB)
 * @group             :
 * @last modified on  : 2024-02-12
 * @last modified by  : Malin Nilsson (Stretch Customer AB)
 **/
@isTest
public with sharing class sakerStartMigrationBatchTest {
  @TestSetup
  static void makeData() {
    List<User> testUsers = [
      SELECT Id, IsActive, FirstName, FederationIdentifier
      FROM User
      WHERE
        Profile.Name = 'Akavia Member'
        AND IsActive = TRUE
        AND FederationIdentifier != NULL
      LIMIT 5
    ];
    List<User> updUsers = new List<User>();
    for (Integer i = 0; i < testUsers.size(); i++) {
      User currUsr = testUsers[i];

      if (i == testUsers.size() - 1) {
        currUsr.IsActive = false;
      }

      currUsr.FirstName = 'testClassUser ' + i;
      updUsers.add(currUsr);
    }

    update updUsers;
  }

  @isTest
  private static void test_migrationBatchJob() {
    Test.startTest();
    sakerStartMigrationBatch batch = new sakerStartMigrationBatch();
    Database.executeBatch(batch, 10); // batch_size is an integer specifying the number of records to be processed in each batch
    Test.stopTest();
  }
}