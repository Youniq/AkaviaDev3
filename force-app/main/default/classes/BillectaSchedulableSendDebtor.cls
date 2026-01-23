/**
 * @description       : Updates debtors contact info in Billecta
 * @author            : Malin Nilsson (Stretch Customer AB)
 * @group             :
 * @last modified on  : 2025-07-02
 * @last modified by  : Malin Nilsson (Stretch Customer AB)
 **/
global class BillectaSchedulableSendDebtor implements Schedulable, Database.AllowsCallouts {
  public static final String CRON_EXPR = '0 45 * * * ? *'; //Daily att 01:30

  global static String scheduleIt() {
    BillectaSchedulableSendDebtor job = new BillectaSchedulableSendDebtor();
    String jobName;
    if (Test.isRunningTest()) {
      jobName = 'TestBillectaSchedulableSendDebtor';
    } else {
      jobName = 'BillectaSchedulableSendDebtor';
    }
    return System.schedule(jobName, CRON_EXPR, job);
  }

  global void execute(SchedulableContext SC) {
    Set<Id> ids = new Map<Id, Account>([
          SELECT Id
          FROM Account
          WHERE
           BillectaMarkedForUpdate__c != NULL
            AND MembershipStatus__c IN ('Kommande','Aktiv','Begärt utträde')
            AND CancellationDateGDPR__c = NULL
          ORDER BY BillectaMarkedForUpdate__c DESC
          LIMIT 1000]).keySet();

      if(ids.size() > 0) {
    BillectaUpdateDebtorsBatch BC = new BillectaUpdateDebtorsBatch(
      ids,
      'update',
      false  // false = send only contact info to billecta (no payment info)
    );
    Id batchId = Database.executeBatch(BC, 1); // the batch initiates a queuable for each account => only allowed with one queuable transaction per batch.
      }
  }
}