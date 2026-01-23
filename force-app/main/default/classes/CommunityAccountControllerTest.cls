/**
 * @description       :
 * @author            : Malin Nilsson (Stretch Customer AB)
 * @group             :
 * @last modified on  : 2024-04-02
 * @last modified by  : Malin Nilsson (Stretch Customer AB)
 **/
@IsTest
public with sharing class CommunityAccountControllerTest {
  @TestSetup
  static void makeData() {
    TestDataFactorySetupParams params = new TestDataFactorySetupParams();
    params.numberOfAccounts = 1;
    TestDataFactory.setupBasicTestData();
    TestDataFactory.setupTestData(params);
  }

  private static String getPersonRtId() {
    RecordType personRT = [
      SELECT Id, DeveloperName
      FROM RecordType
      WHERE SObjectType = 'Account' AND DeveloperName = 'PersonAccount'
      LIMIT 1
    ];
    return personRT.Id;
  }

  @isTest
  static void TestUpdateAccount() {
    Account testAcc = [
      SELECT id
      FROM Account
      WHERE RecordTypeId = :getPersonRtId()
    ];
    testAcc.Phone = '0001111';

    //Start test
    Test.startTest();

    // call your method
    Boolean result = CommunityAccountController.updateAccount(testAcc);
    Test.stopTest();

    //assert correct data
    Assert.areEqual(true, result);
  }

  @isTest
  static void TestCatchUpdateAccount() {
    Boolean errorCaught = false;

    //Start test
    Test.startTest();

    // call your method
    try {
      Boolean result = CommunityAccountController.updateAccount(null);
    } catch (Exception e) {
      //assert correct data
      errorCaught = e != null;
    }

    Test.stopTest();
    Assert.areEqual(true, errorCaught);
  }
}