global class DownloadCompanyTemp implements Database.Batchable<sObject>, Database.AllowsCallouts {
  public List<String> basunIds;
  List<CompanyDetails> result = new List<CompanyDetails>();

  global Database.QueryLocator start(Database.BatchableContext bc) {
    Id recordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName()
      .get('Employer')
      .getRecordTypeId();
    String soqlQuery =
      'Select id, BasunID__c From Account where BasunID__c != null and BasunLastModified__c = null and RecordTypeId =\'' +
      recordTypeId +
      '\'';
    return Database.getQueryLocator(soqlQuery);
  }
  global void execute(Database.BatchableContext bc, List<Account> acctIds) {
    List<Account> acclistToUpdate = new List<Account>();
    try {
      for (Account acctId : acctIds) {
        CompanyDetails changeList = BasunCallout.getCompanyInfo(
          acctId.BasunID__c,
          'sv'
        );
        result.add(changeList);
        if (changeList != null)
          acclistToUpdate.add(
            CompanyController.createCompanyUpdate(changeList)
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