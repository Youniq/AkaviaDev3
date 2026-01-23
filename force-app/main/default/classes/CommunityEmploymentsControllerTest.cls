/**
 * @description       :
 * @author            : Malin Nilsson (Stretch Customer AB)
 * @group             :
 * @last modified on  : 2024-09-10
 * @last modified by  : Malin Nilsson (Stretch Customer AB)
 **/
@isTest
public class CommunityEmploymentsControllerTest {
  @TestSetup
  static void makeData() {
    TestDataFactorySetupParams params = new TestDataFactorySetupParams();
    params.numberOfEmployerAccounts = 2;
    params.numberOfWorkplaceAccounts = 2; // TestDataFactory also created an Employer Account for workplace
    params.numberOfAccounts = 2;
    params.addEmploymentsToMembers = true;

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

  private static String getWorkplaceRtId() {
    RecordType workplaceRT = [
      SELECT Id, DeveloperName
      FROM RecordType
      WHERE SObjectType = 'Account' AND DeveloperName = 'Workplace'
      LIMIT 1
    ];
    return workplaceRT.Id;
  }

  @isTest
  static void TestGetActiveEmployments() {
    Employment__c testEmp = [
      SELECT id, person__c
      FROM Employment__c
      WHERE status__c = 'Aktiv'
      LIMIT 1
    ];

    //Start test
    Test.startTest();

    // call your method
    List<Employment__c> result = CommunityEmploymentController.getUsersActiveEmployment(
      testEmp.Person__c
    );

    Test.stopTest();

    //assert correct data
    Assert.areEqual(1, result.size());
    Assert.areEqual(result[0].Id, testEmp.Id);
  }

  @isTest
  static void TestUpdateEmployment() {
    Employment__c testEmp = [
      SELECT id
      FROM Employment__c
      WHERE status__c = 'Aktiv'
      LIMIT 1
    ];
    testEmp.EndDate__c = Date.newInstance(2024, 3, 6);

    // Start test
    Test.startTest();
    // call your method
    Boolean result = CommunityEmploymentController.updateEmployment(testEmp);
    Test.stopTest();

    Employment__c resultEmp = [
      SELECT id, status__c
      FROM Employment__c
      WHERE Id = :testEmp.Id
      LIMIT 1
    ];

    // assert correct data
    Assert.areEqual(true, result);
    Assert.areNotEqual('Aktiv', resultEmp.status__c);
  }

  @isTest
  static void TestCatchUpdateEmployment() {
    Boolean errorCaught = false;
    //Start test
    Test.startTest();

    // call your method
    try {
      Boolean result = CommunityEmploymentController.updateEmployment(null);
    } catch (Exception e) {
      //assert correct data
      errorCaught = e != null;
    }

    Test.stopTest();
    Assert.areEqual(true, errorCaught);
  }

  @isTest
  static void TestSearchEmployers() {
    String searchString = 'ploy';
    //Start test
    Test.startTest();
    // call your method
    List<Account> result = CommunityEmploymentController.searchEmployers(
      searchString
    );

    Test.stopTest();

    //assert correct data
    Assert.areEqual(2, result.size());
  }

  @isTest
  static void TestSearchNoFoundEmployers() {
    String searchString = 'ingenting';
    //Start test
    Test.startTest();
    // call your method
    List<Account> result = CommunityEmploymentController.searchEmployers(
      searchString
    );

    Test.stopTest();

    //assert correct data
    Assert.areEqual(0, result.size());
  }

  @isTest
  static void TestGetCompanyWorkplaces() {
    Id recordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName()
      .get('Employer')
      .getRecordTypeId();

    Account employerAcc = [
      SELECT Id
      FROM Account
      WHERE
        Status__c = 'Aktiv'
        AND ParentId = NULL
        AND RecordTypeId = :recordTypeId
      LIMIT 1
    ];

    //Start test
    Test.startTest();
    // call your method
    List<Account> result = CommunityEmploymentController.getCompanyWorkplaces(
      employerAcc.Id
    );

    Test.stopTest();

    //assert correct data
    Assert.areEqual(1, result.size());
  }

  @isTest
  static void TestCreateNewEmployment() {
    //Start test
    Test.startTest();

    // call your method

    Account person = [
      SELECT Id
      FROM Account
      WHERE RecordTypeId = :getPersonRtId()
      LIMIT 1
    ];
    Account workplace = [
      SELECT Id
      FROM Account
      WHERE RecordTypeId = :getWorkplaceRtId()
      LIMIT 1
    ];
    Employment__c newEmp = new Employment__c();
    newEmp.Workplace__c = workplace.Id;
    newEmp.Person__c = person.Id;
    newEmp.StartDate__c = Date.newInstance(2024, 3, 21);

    String result = CommunityEmploymentController.createNewEmployment(newEmp);
    Test.stopTest();

    Boolean success = result != null && result.length() > 0 ? true : false;

    //assert correct data
    Assert.areEqual(true, success);
  }

  @isTest
  static void TestCatchCreateNewEmployment() {
    Boolean errorCaught = false;
    //Start test
    Test.startTest();

    // call your method
    try {
      String result = CommunityEmploymentController.createNewEmployment(null);
    } catch (Exception e) {
      //assert correct data
      errorCaught = e != null;
    }
    Test.stopTest();

    Assert.areEqual(true, errorCaught);
  }
}