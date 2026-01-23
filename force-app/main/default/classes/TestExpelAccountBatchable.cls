/**
 * @description       :
 * @author            : Malin Nilsson (Stretch Customer AB)
 * @group             :
 * @last modified on  : 2023-12-13
 * @last modified by  : Malin Nilsson (Stretch Customer AB)
 **/
@isTest
public class TestExpelAccountBatchable {
  @isTest
  static void test_expelMembers() {
    Date lastDayOfPreviousMonth = Date.today().toStartOfMonth().addDays(-1);

    List<Account> accounts = TestExpelAccountsHandler.setupAccounts(1, 1);
    Test.startTest();
    Database.executeBatch(new ExpelAccountBatchable(accounts));
    Test.stopTest();
    // Query for the accounts after they have been processed
    Map<Id, Account> accountsMap = new Map<Id, Account>();
    accountsMap = ExpelAccountsHandler.withChildInfo(accounts);
    for (Account account : accountsMap.Values()) {
      Date expectedCancellationDate = lastDayOfPreviousMonth;
      System.assert(account.ActivePortalUser__c == false);
      System.assert(
        account.CancellationReason__c == 'Utesluten pga bristande betalning'
      );
      System.assert(account.Expell__c == false);
      System.assert(account.CancellationDate__c == expectedCancellationDate);
    }
  }
}