global class DownloadWorksiteBatchable implements Database.Batchable<String>, Database.AllowsCallouts {
  public List<String> basunIds;
  List<WorksiteDetails> result = new List<WorksiteDetails>();
  private String query;

  public DownloadWorksiteBatchable(Set<String> worksiteds) {
    basunIds = new List<String>();
    basunIds.addAll(worksiteds);
  }

  global Iterable<String> start(Database.BatchableContext bc) {
    return basunIds;
  }

  global void execute(Database.BatchableContext bc, List<String> acctIds) {
    List<Account> acclistToUpdate = new List<Account>();
    try {
      for (String acctId : acctIds) {
        WorksiteDetails changeList = BasunCallout.getWorksiteInfo(acctId, 'sv');
        result.add(changeList);
        if (changeList != null)
          acclistToUpdate.add(
            CompanyController.createWorksiteUpdate(changeList)
          );
      }

      system.debug('acclistToUpdate ' + acclistToUpdate);
      system.debug(
        'Heap size is ' +
        limits.getHeapSize() +
        ' enforced is ' +
        limits.getLimitHeapSize()
      );

      Schema.SObjectField basunExternalIdField = Account.Fields.BasunID__c;
      Database.UpsertResult[] upsertList = Database.upsert(
        acclistToUpdate,
        basunExternalIdField,
        false
      );
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
    }
  }

  global void finish(Database.BatchableContext bc) {
    //System.debug('result--> ' + result.size());
  }
}