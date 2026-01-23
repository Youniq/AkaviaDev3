/**
 * @description       : DISCONTINUED 2023-12-14 - This class was used in a one time job for cleaning up data quality
 * @author            : Malin Nilsson (Stretch Customer AB)
 * @group             :
 * @last modified on  : 2023-12-14
 * @last modified by  : Malin Nilsson (Stretch Customer AB)
 **/
@isTest
public class TEMP_SetCorrectEndDate_Test {
  public static List<Account> setupAccounts(Integer numberOfAccounts) {
    Date today = Date.today();
    Date membershipStartDate = Date.parse('2020-10-01');
    TestDataFactory.setupBasicTestData();
    TestDataFactorySetupParams setupParams = new TestDataFactorySetupParams();
    setupParams.numberOfAccounts = numberOfAccounts;
    TestDataFactory.setupTestData(setupParams);
    Benefit__c benefit = new Benefit__c(Name = 'Testbenefit');
    insert benefit;

    List<Account> accounts = [SELECT Id FROM Account];
    Map<Id, Account> accountsMap = new Map<Id, Account>();

    List<Membership__c> memberships = new List<Membership__c>();
    Map<Id, Membership__c> membershipsMap = new Map<Id, Membership__c>();
    List<Assignment__c> assignments = new List<Assignment__c>();
    List<MembershipBenefit__c> membershipBenefits = new List<MembershipBenefit__c>();
    List<Employment__c> employments = new List<Employment__c>();

    for (Account account : accounts) {
      accountsMap.put(account.Id, account);
      memberships.add(
        new Membership__c(
          Person__c = account.Id,
          StartDate__c = today.toStartOfMonth(),
          EndDate__c = today.toStartOfMonth()
        )
      );
    }
    insert memberships;

    List<FeeCategory__c> categories = new List<FeeCategory__c>();

    Boolean isStudent = false;
    for (Membership__c membership : memberships) {
      membershipsMap.put(membership.Id, membership);
      FeeCategory__c category = null;
      if (isStudent) {
        category = new FeeCategory__c(
          AutoUpgrade__c = true,
          Membership__c = membership.Id,
          MembershipCategory__c = 'Studerande',
          StartDate__c = membershipStartDate
        );
      } else {
        category = new FeeCategory__c(
          AutoUpgrade__c = false,
          Membership__c = membership.Id,
          MembershipCategory__c = 'Yrkesverksam'
        );
      }
      isStudent = !isStudent;
      categories.add(category);
    }
    insert categories;

    for (FeeCategory__c category : categories) {
      Membership__c membership = membershipsMap.get(category.Membership__c);
      membership.CurrentFeeCategory__c = category.Id;
    }

    for (Membership__c membership : memberships) {
      Account account = accountsMap.get(membership.Person__c);
      account.ActivePortalUser__c = true;
      account.LatestMembership__c = membership.Id;
    }
    update memberships;
    update accounts;
    return TEMP_BatchSetCorrectEndDate.withChildInfo([SELECT Id FROM Account])
      .values();
  }

  static Account setupStudentAccount() {
    return setupAccounts(2)[1];
  }

  @isTest
  static void test_expelStudentMember() {
    Account account = setupStudentAccount();
    // Date feeCategoryStartDate = TEMP_BatchSetCorrectEndDate.studentCancellationDate(
    //   account
    // );
    List<Account> accounts = new List<Account>();
    accounts.add(account);

    String Qry = 'Select Id FROM Account WHERE Id IN (SELECT Person__c FROM Membership__c WHERE SameStartEndDate__c = true) AND NoOfPayedInvoicesAsEmployed__c = 0';

    TEMP_BatchSetCorrectEndDate bc = new TEMP_BatchSetCorrectEndDate(Qry);
    Database.executeBatch(bc, 10);
  }
}