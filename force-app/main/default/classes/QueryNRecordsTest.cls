/**
 * @description       :
 * @author            : Malin Nilsson (Stretch Customer AB)
 * @group             :
 * @last modified on  : 2024-09-09
 * @last modified by  : Malin Nilsson (Stretch Customer AB)
 **/
@isTest
public with sharing class QueryNRecordsTest {
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

    QueryNRecords.QueryParameters testRequest = new QueryNRecords.QueryParameters();
    testRequest.objectApiName = 'Account';
    testRequest.fieldsToQuery = 'Name, AccountNumber, Website, Type, Description';
    testRequest.numberOfRecords = 3;

    List<QueryNRecords.QueryParameters> testRequestList = new List<QueryNRecords.QueryParameters>();
    testRequestList.add(testRequest);

    List<QueryNRecords.QueryResults> testResponseList = QueryNRecords.getNRecords(
      testRequestList
    );
    System.assert(testResponseList[0].recordString.contains('"Type":"Type2"'));
  }
}