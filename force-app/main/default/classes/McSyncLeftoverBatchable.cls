/**
 * @description       :
 * @author            : Malin Nilsson (Stretch Customer AB)
 * @group             :
 * @last modified on  : 2025-01-28
 * @last modified by  : Malin Nilsson (Stretch Customer AB)
 **/
public with sharing class McSyncLeftoverBatchable implements Database.Batchable<SObject> {
  private String query;
  private String runningObject; // only for logging purposes

  public McSyncLeftoverBatchable(String inputQuery, String inputObject) {
    this.query = inputQuery;
    this.runningObject = inputObject;
  }

  public Database.QueryLocator start(Database.BatchableContext context) {
    return Database.getQueryLocator(this.query);
  }

  public void execute(Database.BatchableContext context, List<SObject> scope) {
    //List<SObject> recsToUpdate = new List<SObject>();
    System.debug(
      LoggingLevel.DEBUG,
      'In  McSyncLeftoverBatchable for ' +
      this.runningObject +
      ' Batch Job id: ' +
      context.getJobId()
    );

    String mcSyncFieldName = 'SyncWithMc__c';
    try {
      for (SObject o : scope) {
        Boolean prevSyncVal = (Boolean) o.get(mcSyncFieldName);
        o.put(mcSyncFieldName, !prevSyncVal); // toggle the boolean field value
        //recsToUpdate.add(o);
      }

      Database.SaveResult[] saveResult = Database.update(scope, false);
      // Iterate through saveResultList based on isSuccess and capture the failed records
      for (Database.SaveResult sr : saveResult) {
        if (!sr.isSuccess()) {
          for (Database.Error err : sr.getErrors()) {
           logError(err, this.runningObject, sr.getId());
          }
        }
      }
    } catch (Exception ex) {
      System.debug(
        'Cause--> ' +
        ex.getCause() +
        'Message--> ' +
        ex.getMessage()
      );
      System.debug(
        'tackTrace--> ' +
        ex.getStackTraceString() +
        'tLineNumber--> ' +
        ex.getLineNumber()
      );

      ApexLog.Error logError = new ApexLog.error('MCSyncLeftoverBatchable','execute()', true, ex);
      ApexLog.createLogDebug(logError);
    }
  }

  public void finish(Database.BatchableContext info) {
  }

  @TestVisible
  private static void logError(Database.Error err, String objectName,  String jobId){
     System.debug('The following error has occurred.');
      System.debug(err.getStatusCode() + ': ' + err.getMessage());
      System.debug(
        'Account fields that affected this error: ' + err.getFields()
      );

      ApexLog.Information logError = new ApexLog.Information(
        'MCSyncLeftoverBatchable',
        'Execute() SaveResult Error',
        true,
        objectName +
        ' record id: ' +
        jobId +
        '. ' +
        err.getMessage() +
        ' AND Affected Fields: ' +
        err.getFields() +
        '.'
      );

      logError.recordId = jobId;
      ApexLog.createLogDebug(logError);
  }
}