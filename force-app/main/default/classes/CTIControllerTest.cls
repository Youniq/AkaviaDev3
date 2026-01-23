/**
 * @description       :
 * @author            : Malin Nilsson (Stretch Customer AB)
 * @group             :
 * @last modified on  : 2024-09-06
 * @last modified by  : Malin Nilsson (Stretch Customer AB)
 **/
@isTest
private class CTIControllerTest {
  @TestSetup
  static void makeData() {
    TestDataFactorySetupParams params = new TestDataFactorySetupParams();
    params.numberOfAccounts = 1;
    TestDataFactory.setupBasicTestData();
    TestDataFactory.setupTestData(params);
  }

  @isTest
  static void testGetPersonContactBySsn() {
    Id recordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName()
      .get('PersonAccount')
      .getRecordTypeId();

    Account a = [SELECT Id, SocialSecurityNumber__c FROM Account LIMIT 1];
    a.SocialSecurityNumber__c = '198101145211';
    update a;

    Test.startTest();
    CTIController.getPersonContactId('198101145211');
    Test.stopTest();
  }
}