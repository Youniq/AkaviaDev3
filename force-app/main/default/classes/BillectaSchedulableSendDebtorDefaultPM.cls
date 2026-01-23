/**
 * @description       : Finds Accounts that should be updated with Kivra as delivery nethod in Billecta
 * Initially Accounts and debtors are created with Postal as delivery method but that shouls asap be updated to Kivre
 * In Billecta Kivra means that the debtor in first hand sent Kivra invoice and postal invoice as fallback. 
 * @author            : Malin Nilsson (Stretch Customer AB)
 * @group             : 
 * @last modified on  : 2025-07-03
 * @last modified by  : Malin Nilsson (Stretch Customer AB)
**/
public with sharing class BillectaSchedulableSendDebtorDefaultPM implements Schedulable, Database.AllowsCallouts {
    public static final String CRON_EXPR = '0 15 7 * * ? *'; //Daily at 07:15 

  public static String scheduleIt() {
    BillectaSchedulableSendDebtor job = new BillectaSchedulableSendDebtor();
    String jobName = 'BillectaSchedulableSendDebtorDefaultPM';
    if (Test.isRunningTest()) {
      jobName = jobName + 'Test';
    }

    return System.schedule(jobName, CRON_EXPR, job);
  }

  public static void execute(SchedulableContext SC) {
    runJob();
  }

  public static void runJob() {
    Set<Id> ids = new Map<Id, Account>(
        [
          SELECT Id
          FROM Account
          WHERE
           BillectaID__c != NULL AND DistributionMethod__c = 'Post' 
           AND IsDistributionPostalPaperOnly__c = False AND PaymentMethod__c = 'BG'
            AND MembershipStatus__c IN ('Kommande','Aktiv','Begärt utträde')
            AND CancellationDateGDPR__c = NULL
            AND BillectaMarkedForUpdate__c = NULL
          ORDER BY BillectaMarkedForUpdate__c DESC
          LIMIT 1000
        ]
      )
      .keySet();

      if(ids.size() > 0) {
        BillectaUpdateDebtorsBatch BC = new BillectaUpdateDebtorsBatch(
            ids,
            'update',
            true,  // true = send debtor w payment info to billecta
            'Defaulting to Kivra'
        );
        Id batchId = Database.executeBatch(BC, 1); // the batch initiates a queuable for each account => only allowed with one queuable transaction per batch.
      }
    }
}