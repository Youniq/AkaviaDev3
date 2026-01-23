/**
 * @description       : DISCONTINUED 2023-12-14 - This class was used in a one time job for cleaning up data quality
 * @author            : Jenny Blomberg (Stretch Customer AB)
 * @last modified on  : 2023-12-14
 * @last modified by  : Malin Nilsson (Stretch Customer AB)
 **/
public class TEMP_BatchSetCorrectEndDate implements Database.Batchable<sObject> {
  public final String Query;

  public TEMP_BatchSetCorrectEndDate(String q) {
    Query = q;
  }

  public Database.QueryLocator start(Database.BatchableContext BC) {
    return Database.getQueryLocator(Query);
  }

  public void execute(Database.BatchableContext BC, List<Account> scope) {
    expel(scope);
  }

  public void finish(Database.BatchableContext BC) {
  }

  public static void expel(List<Account> accounts) {
    Date lastDayOfPreviousMonth = Date.today().toStartOfMonth().addDays(-1);

    //Data Setup
    Map<Id, Account> accountsMap = withChildInfo(accounts);
    // Map<Id, Account> studentAccounts = new Map<Id, Account>();
    // for(Account account : accountsMap.values()) {
    //     if (isStudent(account)) {
    //       	studentAccounts.put(account.Id, account);
    //         system.debug(account.Id + 'is Student');
    //     }
    // }

    //FeeCategories need end date and status
    Map<Id, Membership__c> memberships = membershipsForAccounts(
      accountsMap.keyset()
    );
    Map<Id, FeeCategory__c> feeCategories = feeCategoriesForMemberships(
      memberships.keyset()
    );
    Map<Id, FeeCategory__c> feeCategoriesToDelete = new Map<Id, FeeCategory__c>();
    Map<Id, FeeCategory__c> feeCategoriesToUpdate = new Map<Id, FeeCategory__c>();
    // Map<Id, Id> studentFeeCategoryByMembershipId = new Map<Id, Id>();
    for (FeeCategory__c feeCategory : feeCategories.values()) {
      Id accountId = feeCategory.Membership__r.Person__c;
      //Boolean isStudent = studentAccounts.containsKey(accountId);

      switch on feeCategory.Status__c {
        when 'Kommande' {
          //Delete all fee categories that have status = "Kommande"
          feeCategoriesToDelete.put(feeCategory.Id, feeCategory);
          continue;
        }
        when 'Aktiv' {
          // Active Fee Categories should be updated with EndDate
          // feeCategory.EndDate__c = isStudent ? studentCancellationDate(studentAccounts.get(accountId)) : lastDayOfPreviousMonth;
          feeCategory.EndDate__c = lastDayOfPreviousMonth;
          feeCategoriesToUpdate.put(feeCategory.Id, feeCategory);
          continue;
        }
        // when 'Avslutad' {	// For Students we want to update Membership with Studerande as latest FeeCategory
        //     if(isStudent && feeCategory.MembershipCategory__c == 'Studerande'){
        //         feeCategory.EndDate__c = studentCancellationDate(studentAccounts.get(accountId));
        //         feeCategoriesToUpdate.put(feeCategory.Id, feeCategory);
        //         studentFeeCategoryByMembershipId.put(feeCategory.Membership__c, feeCategory.Id);
        //     }
        // }
      }
    }

    Database.SaveResult[] feeCategoriesSRlist = Database.update(
      feeCategoriesToUpdate.values(),
      false
    );

    Database.DeleteResult[] feeCategoriesDRlist = Database.delete(
      feeCategoriesToDelete.values(),
      false
    );

    //Memberships need
    memberships = membershipsForAccounts(accountsMap.keyset());
    for (Membership__c membership : memberships.values()) {
      Id accountId = membership.Person__c;
      membership.CurrentFeeCategory__c = membership.CurrentFeeCategory__c;
      //Boolean isStudent = studentAccounts.containsKey(accountId);
      //Boolean updateFeeCategory = studentFeeCategoryByMembershipId.containsKey(membership.Id);
      // if(isStudent){
      //   membership.EndDate__c = studentCancellationDate(studentAccounts.get(accountId));
      // }
      //membership.CurrentFeeCategory__c = updateFeeCategory ? studentFeeCategoryByMembershipId.get(membership.Id) : membership.CurrentFeeCategory__c;
    }

    Database.SaveResult[] membershipsSRlist = Database.update(
      memberships.values(),
      false
    );
  }

  public static Map<Id, Membership__c> membershipsForAccounts(
    Set<Id> accountIds
  ) {
    return new Map<Id, Membership__c>(
      [
        SELECT Id, Person__c, EndDate__c, CurrentFeeCategory__c
        FROM Membership__c
        WHERE Person__c IN :accountIds
      ]
    );
  }

  public static Map<Id, FeeCategory__c> feeCategoriesForMemberships(
    Set<Id> membershipIds
  ) {
    return new Map<Id, FeeCategory__c>(
      [
        SELECT
          Id,
          Status__c,
          MembershipCategory__c,
          EndDate__c,
          Membership__r.Person__c
        FROM FeeCategory__c
        WHERE Membership__c IN :membershipIds
        ORDER BY StartDate__c DESC
      ]
    );
  }

  public static Map<Id, Account> withChildInfo(List<Account> accounts) {
    return new Map<Id, Account>(
      [
        SELECT
          Id,
          LatestMembership__r.CurrentFeeCategory__r.AutoUpgrade__c,
          LatestMembership__r.CurrentFeeCategory__r.StartDate__c,
          ActivePortalUser__c,
          PersonContactId,
          PersonEmail,
          CancellationReason__c,
          Expell__c,
          CancellationDate__c,
          NoOfPayedInvoicesAsEmployed__c
        FROM Account
        WHERE Id IN :accounts
      ]
    );
  }

  /** DISCONTINUED 2023-12-14 : No longer ending Yrk1 membersships (memberships prev Students, without any payed invoices) as Student members.  */
  // Returns false if there is no Latest Membership or CurrentFeeCategory, as expected
  //   public static Boolean isStudent(Account account) {
  //     if (Test.isRunningTest()) {
  //       return account.LatestMembership__r.CurrentFeeCategory__r.AutoUpgrade__c;
  //     }
  //     if (
  //       account.NoOfPayedInvoicesAsEmployed__c == 0 &&
  //       account.LatestMembership__r.CurrentFeeCategory__r.AutoUpgrade__c
  //     ) {
  //       return true;
  //     } else {
  //       return false;
  //     }
  //   }

  /** DISCONTINUED 2023-12-14  - No longer ending Yrk1 membersships (memberships prev Students, without any payed invoices) as Student members.  */
  //   public static Date studentCancellationDate(Account account) {
  //     return account.LatestMembership__r.CurrentFeeCategory__r.StartDate__c - 1;
  //   }
}