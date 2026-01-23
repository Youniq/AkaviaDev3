/**
 * @description       :
 * @author            : Malin Nilsson (Stretch Customer AB)
 * @group             :
 * @last modified on  : 2024-09-09
 * @last modified by  : Malin Nilsson (Stretch Customer AB)
 **/
@isTest
public with sharing class SObjectController2Test {
  @TestSetup
  static void makeData() {
    TestDataFactorySetupParams params = new TestDataFactorySetupParams();
    params.numberOfAccounts = 2;
    TestDataFactory.setupBasicTestData();
    TestDataFactory.setupTestData(params);
  }

  static testMethod void test() {
    // Setting some account values here, those were added to account prior to changing to TestDataFactory for creating the accounts. Might not be necessary to set them.
    Account[] setValAccounts = [
      SELECT Id, AccountNumber, Website, Type, Description
      FROM Account
    ];
    for (Integer i = 0; i < setValAccounts.size(); i++) {
      Account currAcc = setValAccounts[i];
      currAcc.Type = 'Type' + String.valueOf(i + 1);
      currAcc.Description = 'D' + String.valueOf(i + 1);

      if (i == 0) {
        currAcc.Website = 'https://trailblazer.me/id/ericsmith';
      } else {
        currAcc.Website = 'https://ericsplayground.wordpress.com/blog/';
      }
    }
    update setValAccounts;

    Account[] accts = [SELECT Id, Name, OwnerId FROM Account];
    String fieldnames = 'Name,Id,OwnerId,AccountNumber,Website,Type,Description,IsDeleted,CreatedDate,AnnualRevenue,Fax,LastActivityDate';
    String testResponse = SObjectController2.getReturnResults(
      accts,
      fieldnames
    );
    System.assert(testResponse.contains('"noEditFieldList":['));
    System.assert(testResponse.contains('"lookupFieldList":["OwnerId"]'));

    Account[] empty = [
      SELECT Id, Name, OwnerId
      FROM Account
      WHERE Name = 'NotInAccounts'
    ];
    String testEmpty = SObjectController2.getReturnResults(empty, fieldnames);
    System.assert(testEmpty.contains('"objectName":"EmptyCollection"'));
  }
}