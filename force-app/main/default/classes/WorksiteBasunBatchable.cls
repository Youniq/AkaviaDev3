/**
 * Batch class to fetch updates on workplaces from BASUN
 * @author Ahmad Amiri
 * @since 2021-01-01
 */
global class WorksiteBasunBatchable implements Database.Batchable<sObject>, Database.Stateful, Database.AllowsCallouts {
  public string soqlQuery = 'Select id, BasunID__c,BasunLastModified__c From Account ' +
                            'Where BasunID__c != null and ExcludeFromUpdate__c = false and RecordType.DeveloperName =\'Workplace\'';
  public List<Id> accountIdFilter;
  public Set<String> worksiteIdsToUpdate = new Set<String>();

  /**
   * Constructor used by scheduled job to fetch all workplaces and look for updates. 
   */
  global WorksiteBasunBatchable(){
  }
  
  /**
   * Constructor used by screen flow on record page 
   * to fetch only one workplaces and look for updates. 
   */
  global WorksiteBasunBatchable (List<Id> accountIds){
    accountIdFilter = accountIds;
    soqlQuery = soqlQuery + ' AND Id IN: accountIdFilter';
  }
  
  
  global Database.QueryLocator start(Database.BatchableContext bc) {
    return Database.getQueryLocator(soqlQuery);
  }

  global void execute(Database.BatchableContext bc, List<Account> scope) {

    System.debug('Scope : ' + scope);

    List<BasunCallout.WorksiteChangesJSON> jList = new List<BasunCallout.WorksiteChangesJSON>();
    Id jobId = bc.getJobId();
    for (Account acc : scope) {
      if (acc.BasunLastModified__c != null) {
        BasunCallout.WorksiteChangesJSON compJson = new BasunCallout.WorksiteChangesJSON();
        compJson.worksiteId = acc.BasunID__c;
        compJson.since = acc.BasunLastModified__c.format(
          'yyyy-MM-dd\'T\'HH:mm:ss.SSS\'Z\''
        );
        jList.add(compJson);
      }
    }

    try {
      List<WorksiteChangesResponse.cls_changes> changeList;
      if (jList.size() > 0)
        changeList = BasunCallout.subscribeWorksites(jList, jobId).changes;

      for (WorksiteChangesResponse.cls_changes ch : changeList) {
        System.debug('ch.changeType.--> ' + ch.changeType);
        if (ch.changeType.equals('updated')) {
          System.debug('ch.--> ' + ch);
          worksiteIdsToUpdate.add(ch.worksiteId);
        } else if (ch.changeType.equals('removed')) {
          for (
            WorksiteChangesResponse.cls_changedFields remove : ch.changedFields
          ) {
            System.debug('Remove fält --> ' + remove);
          }
        }
      }
    } catch (Exception ex) {
      System.debug('Exception--> Message: ' + ex.getMessage());
      System.debug('Cause: ' + ex.getCause());
      System.debug('Line number: ' + ex.getLineNumber());
    }
  }

  global void finish(Database.BatchableContext bc) {
    System.debug('worksiteIdsToUpdate--> ' + worksiteIdsToUpdate);
    DownloadWorksiteBatchable cb = new DownloadWorksiteBatchable(
      worksiteIdsToUpdate
    );
    Database.executeBatch(cb, 10);
  }
}