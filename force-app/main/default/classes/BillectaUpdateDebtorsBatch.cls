/**
 * @description       :
 * @author            :
 * @group             :
 * @last modified on  : 2025-07-03
 * @last modified by  : Malin Nilsson (Stretch Customer AB)
 **/
public class BillectaUpdateDebtorsBatch implements Database.Batchable<sObject>, Database.Stateful {
  public String query;
  public Set<Id> recordsLeftToProcess;
  public boolean updatePM;
  public String action; // action to perform in Billecta create / update / createOrUpdate
  public String calloutExtraMsg; // extra message to add to the callout record. In order to be able to identify the callout in the logs. Used for special cases.

  // Normal constructor.
  public BillectaUpdateDebtorsBatch(
    Set<Id> accountIds,
    String billectaAction,
    Boolean updatePaymentMethod
  ) {
    updatePM = updatePaymentMethod;
    action = billectaAction;
    recordsLeftToProcess = accountIds;
    initRun();
  }

  // Special constructor for special cases, adds the extra message to the callout record.
  public BillectaUpdateDebtorsBatch(
    Set<Id> accountIds,
    String billectaAction,
    Boolean updatePaymentMethod,
    String extraMessage
  ) {
    updatePM = updatePaymentMethod;
    action = billectaAction;
    recordsLeftToProcess = accountIds;
    calloutExtraMsg = extraMessage
;
    initRun();
  }

  private void initRun() {
    try {
      BillectaValidationHelper.validateBillectaActionInput(action);
    } catch (BillectaException e) {
      System.debug(
        LoggingLevel.ERROR,
        'Validation error in BillectaUpdateDebtorsBatch: ' + e.getMessage()
      );
      ApexLog.Error errLog = new ApexLog.Error(
        'BillectaUpdateDebtorsBatch',
        'BillectaUpdateDebtorsBatch()',
        true,
        e
      );
      ApexLog.createLogDebug(errLog);

      throw e;
      // cancel run immediately.
    }

    system.debug('recordsLeftToProcess : ' + recordsLeftToProcess.size());
    query =
      'SELECT Id,' +
      'BillectaID__c,' +
      'SocialSecurityNumber__c,' +
      'FirstName,' +
      'LastName,' +
      'CurrentCOAdress__c,' +
      'CurrentStreetAdress__c,' +
      'CurrentZipCode__c,' +
      'CurrentCity__c,' +
      'CurrentCountry__c,' +
      'CurrentCountryCode__c,' +
      'PersonMobilePhone,' +
      'PersonEmail,' +
      'MemberNumber__c,' +
      'FeeCategory__c,' +
      'ProtectedIdentity__c,' +
      'AutogiroBank__c,' +
      'AG_BankClearingNumber__c,' +
      'AG_BankAccountNumber__c,' +
      'AG_BankIDSignToken__c,' +
      'PaymentMethod__c,' +
      'DistributionMethod__c,' +
      'IsDistributionPostalPaperOnly__c,' +
      'BillectaMarkedForUpdate__c,' +
      'EinvoiceBank__c ' +
      'FROM Account WHERE Id IN: recordsLeftToProcess AND CancellationDateGDPR__c = NULL LIMIT 99';
  }

  public Database.QueryLocator start(Database.BatchableContext bc) {
    return Database.getQueryLocator(query);
  }
  
  public void execute(Database.BatchableContext bc, List<Account> scope) {
    // process each batch of records
    List<Callout__c> calloutsScheduled = new List<Callout__c>();

    for (Account acc : scope) {
      try {
        BillectaValidationHelper.validateAccountForAction(acc, action);

        Id jobId = System.enqueueJob(
          new BillectaSendDebtorAsync(acc, updatePM)
        );

        calloutsScheduled.add(
          new Callout__c(
              jobId__c = jobId,
              Type__c = acc.BillectaID__c == null ? 'Billecta - Create Debtor' : 'Billecta - Update Debtor',
              Account__c = acc.ID,
              Status__c = 'Queued',
              ExtraMessage__c = calloutExtraMsg
            )
          );

        System.debug('-----------JOB ID-------------' + jobId);
        recordsLeftToProcess.remove(acc.Id);
      } 
      catch (BillectaException e) {
        recordsLeftToProcess.remove(acc.Id);

        System.debug(
          LoggingLevel.ERROR,
          'BillectaUpdateDebtorsBatch.execute() ' + e.getMessage()
        );

        // Malin, Remove debug log creation later?
        ApexLog.Error errLog = new ApexLog.Error(
          'BillectaUpdateDebtorsBatch',
          'execute()',
          true,
          e
        );
        ApexLog.createLogDebug(errLog);
      }
    }

    //Insert Callout__c records
    if (calloutsScheduled.size() > 0) {
      System.debug('--- Create Callouts ---');
      try {
        insert calloutsScheduled;
      } catch (exception e) {
        System.debug('--- Error inserting Callouts --- ' + calloutsScheduled);
        ApexLog.Error logError = new ApexLog.Error(
          'BillectaUpdateDebtorBatch',
          'Execute',
          true,
          e
        );
        ApexLog.createLogDebug(logError);
      }
      System.debug('--- Created Callouts ---' + calloutsScheduled);
    }
  }
  public void finish(Database.BatchableContext bc) {
    // execute any post-processing operations
    system.debug(
      'FINISH recordsLeftToProcess : ' + recordsLeftToProcess.size()
    );
    if (recordsLeftToProcess.size() > 0) {

      
      BillectaUpdateDebtorsBatch nextBatch = new BillectaUpdateDebtorsBatch(
        recordsLeftToProcess,
        action,
        updatePM,
        calloutExtraMsg
      );
      Id batchId = Database.executeBatch(nextBatch, 1);
    }
  }
}