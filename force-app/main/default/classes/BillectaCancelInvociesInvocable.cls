/**
 * @description       :
 * @author            : Malin Nilsson (Stretch Customer AB)
 * @group             :
 * @last modified on  : 2025-01-24
 * @last modified by  : Malin Nilsson (Stretch Customer AB)
 **/
public class BillectaCancelInvociesInvocable {
  public String Result;

  public BillectaCancelInvociesInvocable(List<Account> accounts) {
    Map<Id, Account> accountMap = new Map<Id, Account>(accounts);
    Set<Id> accIdSet = accountMap.keySet();
    List<Id> accIdList = new List<Id>(accIdSet);

    
    List<Invoice__c> invoices = invoicesForAccounts(accIdList);

      if(invoices.size() > 0){
      // Running the callout of cancelling invoices in a queuable to have private transaction with more room before hitting limitation errors.
      BillectaCancelInvociesQueuable q = new BillectaCancelInvociesQueuable(
        invoices
      );
      Id jobId = System.enqueueJob(q);

      createCalloutLog(jobId, accIdList);
    } else{
      System.debug('No invoices to cancel');
    }
  }

  public BillectaCancelInvociesInvocable(List<Id> accountIds) {
    this.Result = null;
    List<Invoice__c> invoices = invoicesForAccounts(accountIds);

    if(invoices.size() > 0){
      // Running the callout of cancelling invoices in a queuable to have private transaction with more room before hitting limitation errors.
      BillectaCancelInvociesQueuable q = new BillectaCancelInvociesQueuable(
        invoices
      );

      Id jobId = System.enqueueJob(q);
      createCalloutLog(jobId, accountIds);
    } else{
      System.debug('No invoices to cancel');
    }
  }


  public BillectaCancelInvociesInvocable(List<Invoice__c> invoices) {
      this.Result = null;

      if (invoices == null || invoices.isEmpty()) {
          System.debug('No invoices to cancel');
          return;
      }

      Set<Id> invoiceIds = new Set<Id>();

      for (Invoice__c invoice : invoices) {
          if (invoice.Id != null) {
              invoiceIds.add(invoice.Id);
          }
      }

      if (invoiceIds.isEmpty()) {
          System.debug('No persisted invoices to cancel');
          return;
      }

      // Hämta avgiftsklass från databasen, inte från inkommande objekt.
      List<Invoice__c> safeInvoices = [
          SELECT Id, BillectaID__c, Person__c,
                FeeCategory__c, PaymentStatus__c
          FROM Invoice__c
          WHERE Id IN :invoiceIds
          AND BillectaID__c != NULL
          AND PaymentStatus__c NOT IN ('Betald', 'Makulerad')
          AND (
              FeeCategory__c = NULL
              OR FeeCategory__c != 'Dubbelansluten SRAT'
          )
      ];

      if (safeInvoices.isEmpty()) {
          System.debug('No eligible invoices to cancel');
          return;
      }

      Set<Id> accountIds = new Set<Id>();

      for (Invoice__c invoice : safeInvoices) {
          if (invoice.Person__c != null) {
              accountIds.add(invoice.Person__c);
          }
      }

      BillectaCancelInvociesQueuable q =
          new BillectaCancelInvociesQueuable(safeInvoices);

      Id jobId = System.enqueueJob(q);

      createCalloutLog(jobId, new List<Id>(accountIds));
  }


  @invocableMethod(callout=true)
  public static void BillectaCancelInvociesInvocable(
    List<String> accountIdsAsString
  ) {
    List<Id> accountIdsAsIds = new List<Id>();
    for (String s : accountIdsAsString) {
      accountIdsAsIds.add(Id.valueOf(s));
    }
    BillectaCancelInvociesInvocable BCII = new BillectaCancelInvociesInvocable(
      accountIdsAsIds
    );
  }


  public List<Invoice__c> invoicesForAccounts(List<Id> accountIds) {
      return InvoiceHelper.invoicesForAccounts(
          new Set<Id>(accountIds)
      );
  }


  private static void createCalloutLog(Id jobId, List<Id> accIds) {
    String accId;
    if (accIds != null && accIds.size() == 1) {
      accId = accIds[0];
    }

    Callout__c callout = new Callout__c(
      jobId__c = jobId,
      Type__c = 'Billecta - Cancel Invoices',
      Account__c = accId, // Acc refrence will be null if there are multiple accounts.
      Status__c = 'Queued'
    );

    insert callout;
  }
}