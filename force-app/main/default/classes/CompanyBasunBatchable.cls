/**
 * Batch class to fetch updates on employers from BASUN
 * @author Ahmad Amiri
 * @since 2021-01-01
 */
global class CompanyBasunBatchable implements Database.Batchable<sObject>, Database.Stateful, Database.AllowsCallouts {
  public string soqlQuery = 'Select id, BasunID__c,BasunLastModified__c From Account ' +
                            'Where BasunID__c != null and ExcludeFromUpdate__c = false and RecordType.DeveloperName =\'Employer\'';
  public List<Id> accountIdFilter;
  Set<String> companyIdsToUpdate = new Set<String>();

  /**
   * Constructor used by scheduled job to fetch all employers and look for updates. 
   */
  global CompanyBasunBatchable(){
  }
  
  /**
   * Constructor used by screen flow on record page 
   * to fetch only one Employer and look for updates. 
   */
  global CompanyBasunBatchable (List<Id> accountIds){
    accountIdFilter = accountIds;
    soqlQuery = soqlQuery + ' AND Id IN: accountIdFilter';
  }
  
  global Database.QueryLocator start(Database.BatchableContext bc) {
    return Database.getQueryLocator(soqlQuery);
  }

  global void execute(Database.BatchableContext bc, List<Account> scope) {
    List<BasunCallout.CompnayChangesJSON> compJsonList = new List<BasunCallout.CompnayChangesJSON>();
    Id jobId = bc.getJobId();

    for (Account acc : scope) {
      if (acc.BasunLastModified__c != null) {
        BasunCallout.CompnayChangesJSON compJson = new BasunCallout.CompnayChangesJSON();
        compJson.companyId = acc.BasunID__c;
        compJson.since = acc.BasunLastModified__c.format(
          'yyyy-MM-dd\'T\'HH:mm:ss.SSS\'Z\''
        );
        compJsonList.add(compJson);
      }
    }

    try {
      List<CompanyChangesResponse.cls_changes> changeList;
      if (compJsonList.size() > 0)
        changeList = BasunCallout.subscribeCompanies(compJsonList, jobId)
          .changes;

      for (CompanyChangesResponse.cls_changes ch : changeList) {
        System.debug('ch.changeType.--> ' + ch.changeType);

        if (ch.changeType.equals('updated')) {
          System.debug(' changedFields.size--> ' + ch.changedFields.size());
          System.debug(' changedFields--> ' + ch.changedFields);
          companyIdsToUpdate.add(ch.companyId);
          System.debug('Update--> ' + ch);
        }
      }
    } catch (Exception ex) {
      System.debug('Exception--> Message: ' + ex.getMessage());
      System.debug('Cause: ' + ex.getCause());
      System.debug('Line number: ' + ex.getLineNumber());
      System.debug('StackTrace: ' + ex.getStackTraceString());
    }
  }

  global void finish(Database.BatchableContext bc) {
    System.debug('companyIdsToUpdate--> ' + companyIdsToUpdate);
    DownloadCompanyBatchable cb = new DownloadCompanyBatchable(
      companyIdsToUpdate
    );
    Database.executeBatch(cb, 10);
  }
}