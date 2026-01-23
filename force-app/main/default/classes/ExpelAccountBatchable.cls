global class ExpelAccountBatchable implements Database.Batchable<Sobject>, Database.AllowsCallouts {
  List<Account> personList;

  public ExpelAccountBatchable(List<Account> persons) {
    personList = persons;
  }

  global Iterable<SObject> start(Database.BatchableContext bc) {
    return personList;
  }
    
  global void execute(Database.BatchableContext bc, List<Account> acctList) {
    try {
      ExpelAccountsHandler.expel(acctList);
    } catch (Exception ex) {
      String errorMessage = 'Cause--> ' +
        ex.getCause() +
        ' Message--> ' +
        ex.getMessage() +
        ' StackTrace--> ' +
        ex.getStackTraceString() +
        ' LineNumber--> ' +
        ex.getLineNumber();
      ApexLog.Information logError = new ApexLog.Information('ExpelAccountBatchable', 'Execute', true, errorMessage);
      ApexLog.createLogDebug(logError);
    }
  }

  global void finish(Database.BatchableContext bc) {
    
  }
}