/**
 * @description       :
 * @author            : Malin Nilsson (Stretch Customer AB)
 * @group             :
 * @last modified on  : 2024-09-06
 * @last modified by  : Malin Nilsson (Stretch Customer AB)
 **/
@isTest
private class UpdatePersonBatchableTest {
  @TestSetup
  static void makeData() {
    TestDataFactorySetupParams params = new TestDataFactorySetupParams();
    params.numberOfAccounts = 1;
    params.addMembershipsToMembers = true;

    TestDataFactory.setupBasicTestData();
    TestDataFactory.setupTestData(params);

    List<Account> testAccounts = new List<Account>();

    Account matchingAcc = [
      SELECT id, membershipStatus__c, LatestMembership__c
      FROM account
      LIMIT 1
    ];

    matchingAcc.BCIID__C = 'A2VT6BE7WP2J'; // Matching Gedi in http result (MockHttpResponseGenerator.BCIMonitoringResponseString())
    matchingAcc.socialSecuritynumber__c = '198701270491'; // Found on the mock result with the gedi: A2VT6BE7WP2J.

    testAccounts.add(matchingAcc);
    update testAccounts;
  }

  @isTest
  static void testUpdatePersonBatchable() {
    List<Account> accountList = [
      SELECT
        Id,
        SocialSecurityNumber__c,
        BCIID__c,
        FirstName,
        Lastname,
        recordTypeId
      FROM Account
      WHERE isPersonAccount = TRUE
    ];

    Test.startTest();
    UpdatePersonBatchable c = new UpdatePersonBatchable(accountList);
    Database.executeBatch(c);

    Test.stopTest();
  }

  @isTest
  static void testValidateAccountList() {
    TestDataFactorySetupParams params = new TestDataFactorySetupParams();
    params.numberOfAccounts = 4;
    List<Account> unexistingAccs = TestDataFactory.createTestAccounts(
      params,
      false
    );

    for (Integer i = 0; i < unexistingAccs.size(); i++) {
      Account cust = unexistingAccs[i];
      cust.LastName = 'NONCustomer ' + i;
      cust.FirstName = 'NONCustomer';
      cust.BCIID__c = String.valueOf(i + 'BC');
      cust.SocialSecurityNumber__c = '19320213557' + i;
    }

    List<Account> existingAccs = [
      SELECT
        Id,
        SocialSecurityNumber__c,
        BCIID__c,
        FirstName,
        Lastname,
        recordTypeId
      FROM Account
      WHERE isPersonAccount = TRUE
    ];

    List<Account> accountList = new List<Account>();
    accountList.addAll(unexistingAccs);
    accountList.addAll(existingAccs);

    Test.startTest();
    accountList = UpdatePersonBatchable.validateAccountList(accountList);
    Test.stopTest();

    for (Account a : accountList) {
      if (a.BCIID__c.contains('BC')) {
        System.assertEquals(a.FirstName, 'DELETE');
      } else {
        System.assertNotEquals(a.FirstName, 'DELETE');
      }
    }
  }

  @isTest
  static void testHandleUpsertError() {
    List<Account> accountList = [
      SELECT
        Id,
        SocialSecurityNumber__c,
        BCIID__c,
        FirstName,
        Lastname,
        recordTypeId
      FROM Account
      WHERE isPersonAccount = TRUE
    ];

    for (Account a : accountList) {
      a.SocialSecurityNumber__c += '111';
    }

    Test.startTest();
    UpdatePersonBatchable c = new UpdatePersonBatchable(accountList);
    Database.executeBatch(c);
    Test.stopTest();
  }
}