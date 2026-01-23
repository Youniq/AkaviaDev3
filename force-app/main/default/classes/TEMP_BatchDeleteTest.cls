/**
 * @description       :
 * @author            : Malin Nilsson (Stretch Customer AB)
 * @group             :
 * @last modified on  : 2024-04-02
 * @last modified by  : Malin Nilsson (Stretch Customer AB)
 **/
@isTest
public class TEMP_BatchDeleteTest {
  @TestSetup
  static void makeData() {
    TestDataFactorySetupParams params = new TestDataFactorySetupParams();
    params.numberOfWorkplaceAccounts = 1;
    params.numberOfAccounts = 2;
    params.addEmploymentsToMembers = true;

    TestDataFactory.setupBasicTestData();
    TestDataFactory.setupTestData(params);
  }

  @isTest
  public static void testTEMP_Delete() {
    // Add a cancellationDate to one person account
    Account a = [
      SELECT Id, CancellationDate__c
      FROM Account
      WHERE isPersonAccount = TRUE
      LIMIT 1
    ];
    a.CancellationDate__c = Date.newInstance(2022, 2, 22);
    update a;

    // Gets all employments where account is cancelled
    String query = 'SELECT id from Employment__c where Person__r.IsPersonAccount = true and Person__r.CancellationDate__c != null and Person__r.CancellationDate__c < LAST_N_DAYS:31';
    Test.startTest();

    TEMP_BatchDelete pds = new TEMP_BatchDelete(query);
    Database.executeBatch(pds, 200);

    test.stopTest();

    List<Employment__c> emps = [SELECT Id FROM Employment__c];
    system.assertEquals(1, emps.size());
  }
}