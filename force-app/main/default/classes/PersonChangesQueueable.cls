/**
 * @description       :
 * @author            : Unknown
 * @group             :
 * @last modified on  : 2024-09-25
 * @last modified by  : Malin Nilsson (Stretch Customer AB)
 **/
public class PersonChangesQueueable implements Queueable, Database.AllowsCallouts {
  String nextPage = null;
  public PersonChangesQueueable(String id) {
    this.nextPage = id;
  }
  public void execute(QueueableContext context) {
    getPersonsChanges();
  }

  public void getPersonsChanges() {
    List<Account> acctList = new List<Account>();
    List<Callout__c> calloutLogs = new List<Callout__c>();
    String cursorNext = nextPage;
    system.debug('cursorNext --> ' + cursorNext);
    Boolean hasMoreEntities = false;
    Boolean errorStatus = false;
    PersonData[] changedEntities;
    BCI_MonitoringResponse.cls_errorEntities[] errorEntities;
    Integer numberOfEntities;
    String errorMessage = 'Error: ';
    Integer accCountLimit = 40000;

    if (Test.isRunningTest()) {
      accCountLimit = 100;
    }

    do {
      SparCallout.ResponseWrapper respWrapper = sparCallout.getChangesPersonInfo(
        'default',
        cursorNext,
        calloutLogs
      );
      BCI_MonitoringResponse respBCI;

      if (respWrapper.status) {
        respBCI = BCI_MonitoringResponse.parse(respWrapper.statusMessage);
        numberOfEntities = respBCI.numberOfEntities;
        hasMoreEntities = respBCI.hasMoreEntities;
        cursorNext = respBCI.cursor.next;
        changedEntities = respBCI.changedEntities;
        system.debug('numberOfEntities-->' + numberOfEntities);
        system.debug('changedEntities-->' + changedEntities);
        system.debug('cursorNext-->' + cursorNext);
        system.debug('hasMoreEntities-->' + hasMoreEntities);

        for (PersonData personInfo : changedEntities) {
          Account acct = sparCallout.MapPersonAccount(
            new Account(),
            personInfo
          );
          acctList.add(acct);
        }
      } else {
        errorStatus = true;
        errorMessage += respWrapper.statusMessage;
      }

      if (Limits.getCallouts() > 90) {
        System.debug('Limits.getCallouts() --> ' + Limits.getCallouts());
        errorMessage =
          'Limits callout --> ' +
          Limits.getCallouts() +
          ' Next cursor: ' +
          cursorNext;
        errorMessage +=
          ' Run SchedulableDailyPersonBCI job = new SchedulableDailyPersonBCI(); job.getPersonsChanges(' +
          cursorNext +
          ') to get persons info';
        errorStatus = true;
        break;
      }
    } while (numberOfEntities > 0 && acctList.size() < accCountLimit);
    // Checking numberOfEntities > 0 instead of hasMoreEntities == true as adviced by DnB.

    System.debug(
      'do-while loop has finished. hasMoreEntities: ' + hasMoreEntities
    );
    System.debug(
      'do-while loop has finished. numberOfEntities: ' + numberOfEntities
    );

    if (errorStatus) {
      ApexLog.Information logError = new ApexLog.Information(
        'SchedulableDailyPersonBCI',
        'getPersonsChanges()',
        false,
        errorMessage +
        ' cursorNext: ' +
        cursorNext
      );
      ApexLog.createLogDebug(logError);
    }

    // Få instansen av hierarki Custom Setting
    bisnode__c bisnodeSetting = bisnode__c.getOrgDefaults();

    if (cursorNext != null && bisnodeSetting != null) {
      // Save the cursor value in a custom setting for usage on next scheduled run.
      bisnodeSetting.bisnodeCursor__c = cursorNext;
      upsert bisnodeSetting;
    }

    infoLogger(acctList, cursorNext, hasMoreEntities);

    if (calloutLogs.size() > 0) {
      // insert callout logs after all callouts have been made. The calloutLogs list is sent to the sparCallout.getChangesPersonInfo() method and filled with callout logs for each cursor call
      insert GenericUtils.getListUpsideDown(calloutLogs);
    }

    if (acctList.size() > 0) {
      System.debug(
        'acctList.Size() when starting UpdatePersonBatchable(accList): ' +
        acctList.Size()
      );
      Database.executeBatch(new UpdatePersonBatchable(acctList), 200);
    }
  }

  /**
   * @description - Logs info about result set fetched from Bisnode to give insight on records fetched.
   * @author Malin Nilsson (Stretch Customer AB) | 2024-01-09
   * @param accList
   * @param cursorNext
   * @param hasMoreEntities
   **/
  private void infoLogger(
    List<Account> accList,
    String cursorNext,
    Boolean hasMoreEntities
  ) {
    Integer protectedIdCount = 0;
    Integer deregisteredNoUpdateCount = 0;
    Integer deregisteredCount = 0;
    Integer normalUpdateCount = 0;
    Integer errorCount = 0;
    String protectedId = 'Protected Identity';
    String deregisteredNoUpdate = 'deregistered - No Update!';
    String deregistered = 'deregistered';
    String error = 'Message: ';

    // Count the occurences of certain Bidnode messages to get insight of the collected data set. Info is later on logged to Debug Log record.
    for (Account a : accList) {
      String bisnodeMessage = a.BisnodeMessage__c;

      if (bisnodeMessage.equals(protectedId)) {
        protectedIdCount++;
      } else if (bisnodeMessage.equals(deregisteredNoUpdate)) {
        deregisteredNoUpdateCount++;
      } else if (bisnodeMessage.equals(deregistered)) {
        deregisteredCount++;
      } else if (bisnodeMessage.startsWith(error)) {
        errorCount++;
      } else {
        normalUpdateCount++;
      }
    }

    String infoMessage =
      'Results from sparCallout.getChangesPersonInfos. <br> ' +
      'Total count: ' +
      accList.size() +
      ' <br>' +
      'Normal Account Update Count: ' +
      normalUpdateCount +
      ' <br>' +
      'Protected Identity Count: ' +
      protectedIdCount +
      ' <br>' +
      'Deregistered - No Update! Count : ' +
      deregisteredNoUpdateCount +
      ' <br>' +
      'Deregistered Count: ' +
      deregisteredCount +
      ' <br>' +
      'Errors Count: ' +
      errorCount +
      ' <br>' +
      'Cursor Next: ' +
      cursorNext +
      ' <br>' +
      'Has More Entitites: ' +
      hasMoreEntities;

    ApexLog.Information summaryLog = new ApexLog.Information(
      'SchedulableDailyPersonBCI',
      'getPersonsChanges',
      false,
      infoMessage
    );
    ApexLog.createLogDebug(summaryLog);
  }
}