/**
 * @description       :
 * @author            : Malin Nilsson (Stretch Customer AB)
 * @group             :
 * @last modified on  : 2024-09-09
 * @last modified by  : Malin Nilsson (Stretch Customer AB)
 **/
@isTest
private class BCIUpdatePersonTest {
  @TestSetup
  static void makeData() {
    TestDataFactorySetupParams params = new TestDataFactorySetupParams();
    params.numberOfAccounts = 1;
    TestDataFactory.setupBasicTestData();
    TestDataFactory.setupTestData(params);
  }

  @isTest
  static void testGetPersonInfo() {
    Test.setMock(
      HttpCalloutMock.class,
      new MockHttpResponseGenerator('getDownloadPersonInfo')
    );

    Account cust = [
      SELECT
        Id,
        Lastname,
        Firstname,
        SocialSecurityNumber__c,
        BasunLastModified__c,
        recordtypeId,
        BCIID__c,
        MemberNumber__c
      FROM Account
      LIMIT 1
    ];

    cust.SocialSecurityNumber__c = '198101145211';
    cust.BCIID__c = '12340';
    update cust;

    BCIUpdatePerson.FlowInputs input = new BCIUpdatePerson.FlowInputs();
    input.accountRecord = cust;
    input.portfolioId = 'Defualt';
    List<BCIUpdatePerson.FlowInputs> inputs = new List<BCIUpdatePerson.FlowInputs>();
    inputs.add(input);

    Test.startTest();
    BCIUpdatePerson.getPersonInfo(inputs);
    Test.stopTest();
  }
}