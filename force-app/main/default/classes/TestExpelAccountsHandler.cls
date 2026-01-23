/**
 * @description       :
 * @author            : Malin Nilsson (Stretch Customer AB)
 * @group             :
 * @last modified on  : 2025-01-24
 * @last modified by  : Malin Nilsson (Stretch Customer AB)
 **/
@isTest
public class TestExpelAccountsHandler {
  //Next step:
  //Test setupAccounts and make sure all data looks good.
  public static List<Account> setupAccounts(
    Integer numberOfStudentAccounts,
    Integer numberOfNonStudentAccounts
  ) {
    Date today = Date.today();
    Date membershipStartDate = Date.parse('2020-10-01');

    //Basic testdata
    TestDataFactory.setupBasicTestData();

    //Student Accounts
    if (numberOfStudentAccounts > 0) {
      TestDataFactorySetupParams studentParams = new TestDataFactorySetupParams();
      studentParams.numberOfAccounts = numberOfStudentAccounts;
      studentParams.numberOfBenefits = 1;
      studentParams.addAssignmentToMembers = true;
      studentParams.addMembershipsToMembers = true;
      studentParams.addStudentFeeCategoryToMemberships = true;
      studentParams.addEmploymentsToMembers = true;
      studentParams.addMembershipBenefitsToMembers = true;
      TestDataFactory.setupTestData(studentParams);
    }

    //Yrkesverksam Accounts
    if (numberOfNonStudentAccounts > 0) {
      TestDataFactorySetupParams nonStudentParams = new TestDataFactorySetupParams();
      nonStudentParams.numberOfAccounts = numberOfNonStudentAccounts;
      nonStudentParams.numberOfBenefits = 1;
      nonStudentParams.addAssignmentToMembers = true;
      nonStudentParams.addMembershipsToMembers = true;
      nonStudentParams.addYrkesverksamFeeCategoryToMemberships = true;
      nonStudentParams.addEmploymentsToMembers = true;
      nonStudentParams.addMembershipBenefitsToMembers = true;
      TestDataFactory.setupTestData(nonStudentParams);
    }

    List<Account> membersToUpdate = new List<Account>();
    for (Account member : [
      SELECT Id, ActivePortalUser__c, LatestMembership__c
      FROM Account
      WHERE isPersonAccount = TRUE
    ]) {
      member.ActivePortalUser__c = true;
      membersToUpdate.add(member);
    }
    update membersToUpdate;
    return ExpelAccountsHandler.withChildInfo([SELECT Id FROM Account])
      .values();
  }

  static Account setupStudentAccount() {
    return setupAccounts(1, null)[0];
  }

  static Account setupFullMemberAccount() {
    return setupAccounts(null, 1)[0];
  }

  @isTest
  static void test_expelMembers() {
    Date lastDayOfPreviousMonth = Date.today().toStartOfMonth().addDays(-1);

    List<Account> accounts = setupAccounts(2, 2);
    Map<Id, Account> accountsToExpel = new Map<Id, Account>();

    accountsToExpel.put(accounts.get(0).Id, accounts.get(0));
    accountsToExpel.put(accounts.get(1).Id, accounts.get(1));

    Test.startTest();
    ExpelAccountsHandler.expel(accountsToExpel.values());
    Test.stopTest();

    // Query for the accounts after they have been processed
    Integer numberOfExpelledAccounts = 0;
    accounts = ExpelAccountsHandler.withChildInfo(accounts).values();
    for (Account account : accounts) {
      if (accountsToExpel.containsKey(account.Id)) {
        numberOfExpelledAccounts += 1;
        Date expectedCancellationDate = lastDayOfPreviousMonth;
        System.assert(account.ActivePortalUser__c == false);
        System.assert(
          account.CancellationReason__c == 'Utesluten pga bristande betalning'
        );
        System.assert(account.Expell__c == false);
        System.assert(account.CancellationDate__c == expectedCancellationDate);
      } else {
        System.assert(account.ActivePortalUser__c == true);
        System.assert(account.CancellationReason__c == null);
        System.assert(account.Expell__c == false);
        System.assert(account.CancellationDate__c == null);
      }
    }
    System.assert(numberOfExpelledAccounts == 2);
  }

  @isTest
  static void test_expelFullMember() {
    Date lastDayOfPreviousMonth = Date.today().toStartOfMonth().addDays(-1);
    Account account = setupFullMemberAccount();
    List<Account> accounts = new List<Account>();
    accounts.add(account);
    ExpelAccountsHandler.expel(accounts);

    // Query for the accounts after they have been processed
    account = ExpelAccountsHandler.withChildInfo(accounts).values()[0];
    System.assert(account.ActivePortalUser__c == false);
    System.assert(
      account.CancellationReason__c == 'Utesluten pga bristande betalning'
    );
    System.assert(account.Expell__c == false);
    System.assert(account.CancellationDate__c == lastDayOfPreviousMonth);

    List<Membership__c> memberships = soqlForObject('Membership__c', accounts);
    System.assert(memberships[0].EndDate__c == lastDayOfPreviousMonth);
    System.assert(memberships[0].Expelled__c == true, 'Membership Expelled__c should be set to true when member is expelled');

    List<Assignment__c> assignments = soqlForObject('Assignment__c', accounts);
    System.assert(assignments[0].EndDate__c == lastDayOfPreviousMonth);

    List<MembershipBenefit__c> membershipBenefits = soqlForObject(
      'MembershipBenefit__c',
      accounts
    );
    System.assert(membershipBenefits[0].EndDate__c == lastDayOfPreviousMonth);

    List<Employment__c> employments = soqlForObject('Employment__c', accounts);
    System.assert(employments.size() == 0);
  }

  // @isTest
  //   static void test_expelStudentMember() {
  //     Account account = setupStudentAccount();
  //     Date feeCategoryStartDate = ExpelAccountsHandler.studentCancellationDate(
  //       account
  //     );
  //     List<Account> accounts = new List<Account>();
  //     accounts.add(account);

  //     ExpelAccountsHandler.expel(accounts);

  //     // Query for the accounts after they have been processed
  //     account = ExpelAccountsHandler.withChildInfo(accounts).values()[0];
  //     System.assert(account.ActivePortalUser__c == false);
  //     System.assert(
  //       account.CancellationReason__c == 'Utesluten pga bristande betalning'
  //     );
  //     System.assert(account.Expell__c == false);
  //     System.assert(account.CancellationDate__c == feeCategoryStartDate);
  //     System.assert(account.CancellationDate__c != null);

  //     List<Membership__c> memberships = soqlForObject('Membership__c', accounts);
  //     System.assert(memberships[0].EndDate__c == feeCategoryStartDate);

  //     List<Assignment__c> assignments = soqlForObject('Assignment__c', accounts);
  //     System.assert(assignments[0].EndDate__c == feeCategoryStartDate);

  //     List<MembershipBenefit__c> membershipBenefits = soqlForObject(
  //       'MembershipBenefit__c',
  //       accounts
  //     );
  //     System.assert(membershipBenefits[0].EndDate__c == feeCategoryStartDate);

  //     List<Employment__c> employments = soqlForObject('Employment__c', accounts);
  //     System.assert(employments.size() == 0);
  //   }

  //   @isTest
  //   public static void test_isFullMemberAccount() {
  //     Account account = setupFullMemberAccount();
  //     Boolean isStudent = ExpelAccountsHandler.isStudent(account);
  //     System.assert(isStudent == false);
  //   }

  // @isTest
  //   public static void test_isStudentAccount() {
  //     Account account = setupStudentAccount();
  //     Boolean isStudent = ExpelAccountsHandler.isStudent(account);
  //     System.assert(isStudent);
  //   }

  //   @isTest
  //   public static void test_isStudent_forAccountWithoutMembership() {
  //     TestDataFactory.setupBasicTestData();
  //     TestDataFactorySetupParams setupParams = new TestDataFactorySetupParams();
  //     setupParams.numberOfAccounts = 1;
  //     TestDataFactory.setupTestData(setupParams);
  //     Account account = ExpelAccountsHandler.withChildInfo(
  //         [SELECT Id FROM Account]
  //       )
  //       .values()[0];
  //     Boolean isStudent = ExpelAccountsHandler.isStudent(account);
  //     System.assert(isStudent == false);
  //   }

  public static List<sObject> soqlForObject(
    String objectType,
    List<Account> accounts
  ) {
    List<Id> accountIds = new List<Id>(new Map<Id, Account>(accounts).keySet());
    String fields = 'Id, Person__c, EndDate__c';
    if (objectType == 'Membership__c') {
      fields += ', Expelled__c';
    }
    String query =
      'SELECT ' + fields + ' FROM ' +
      objectType +
      ' WHERE Person__c IN: accounts';
    System.debug('QUERY');
    System.debug(query);
    return Database.query(query);
  }

  @isTest
  public static void test_cleanAccountsMapAfterUpdate_Membership() {
    List<Account> accountsList = setupAccounts(2, 2);
    Map<Id, Account> accounts = ExpelAccountsHandler.withChildInfo(
      accountsList
    );
    List<Membership__c> mList = soqlForObject(
      'Membership__c',
      accounts.values()
    );
    Map<Id, Membership__c> memberships = new Map<Id, Membership__c>(mList);
    List<Database.SaveResult> fakeSaveResult = createFakeSaveResult(
      memberships.values()
    );

    system.debug(fakeSaveResult);

    System.debug(accounts.size());
    Map<Id, Account> result = ExpelAccountsHandler.cleanAccountsMapAfterUpdate(
      fakeSaveResult,
      memberships,
      'Person__c',
      accounts
    );
    System.debug(result.size());
    System.assertEquals(0, result.size());
    //Database.SaveResult[] srList, Map<Id, sObject> updatedRecords, String updatedRecordsPersonField, Map<Id, Account> accountsMapToClean
  }

  public static void test_cleanAccountsMapAfterUpdate_FeeCategory() {
    List<Account> accountsList = setupAccounts(2, 2);
    Map<Id, Account> accounts = ExpelAccountsHandler.withChildInfo(
      accountsList
    );
    List<Membership__c> mList = soqlForObject(
      'Membership__c',
      accounts.values()
    );
    Map<Id, Membership__c> memberships = new Map<Id, Membership__c>(mList);
    Map<Id, FeeCategory__c> feeCategories = ExpelAccountsHandler.feeCategoriesForMemberships(
      memberships.keyset()
    );
    List<Database.SaveResult> fakeSaveResult = createFakeSaveResult(
      feeCategories.values()
    );

    system.debug(fakeSaveResult);

    System.debug(accounts.size());
    Map<Id, Account> result = ExpelAccountsHandler.cleanAccountsMapAfterUpdate(
      fakeSaveResult,
      feeCategories,
      'Membership__r.Person__c',
      accounts
    );
    System.debug(result.size());
    System.assertEquals(0, result.size());
    //Database.SaveResult[] srList, Map<Id, sObject> updatedRecords, String updatedRecordsPersonField, Map<Id, Account> accountsMapToClean
  }

  public static List<Database.SaveResult> createFakeSaveResult(
    List<sObject> sobjList
  ) {
    String jsonString = '';
    List<Database.SaveResult> result = new List<Database.SaveResult>();
    for (sObject m : sobjList) {
      jsonString =
        '{"errors": [{"fields": ["IsActive"], "message": "Whoops!"}], "id": "' +
        m.Id +
        '", "success": false}';

      result.add(
        (Database.SaveResult) JSON.deserialize(
          jsonString,
          Database.SaveResult.class
        )
      );
    }
    System.debug(jsonString);
    return result;
  }

  public static List<Database.DeleteResult> createFakeDeleteResult(
    List<sObject> sobjList
  ) {
    String jsonString = '';
    List<Database.DeleteResult> result = new List<Database.DeleteResult>();
    for (sObject m : sobjList) {
      jsonString = '{"errors": [{"fields": ["IsActive"], "message": "Whoops!"}], "id": "", "success": false}';

      result.add(
        (Database.DeleteResult) JSON.deserialize(
          jsonString,
          Database.DeleteResult.class
        )
      );
    }
    System.debug(jsonString);
    return result;
  }
}