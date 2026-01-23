/**
 * @description       : Tar bort medlemmar från prenumeration på dess personuppgifter hos Dun&Bradstreet (Gamla Basun och BCI)
 * @author            : Unknown
 * @group             :
 * @last modified on  : 2025-06-02
 * @last modified by  : Malin Nilsson (Stretch Customer AB)
 **/
global class RemovePersonFromBCIBatchable implements Database.Batchable<sObject>, Database.AllowsCallouts {
  global Database.QueryLocator start(Database.BatchableContext bc) {
    return Database.getQueryLocator(getQuery());
  }
  global void execute(Database.BatchableContext bc, List<Account> acctList) {
    List<Callout__c> calloutLogs = new List<Callout__c>();
    Id jobId = bc.getJobId();
    List<Account> acclistToUpdate = new List<Account>();
    Integer noOfFailures = 0;

    for (Account acct : acctList) {
      Account accToUpdate = deletePersonFromProtfolio(
        acct,
        'default',
        calloutLogs
      );
      if (accToUpdate.BCIID__c == '') {
        acclistToUpdate.add(accToUpdate);
      } else {
        // Meaning that the accountToUpdate were not successfully removed from BCI.
        noOfFailures++;
      }
    }

    if (noOfFailures > 0) {
      // The constructor will create debug log with the information.
      BCI_IntegrationException ex = new BCI_IntegrationException(
        'SchedulableRemoveMemberBCI - ' +
        noOfFailures +
        ' out of ' +
        acctList.size() +
        ' accounts failed to be removed from BCI/Dun&Bradstreet in this batch. <br/>' +
        'Batch job id: ' +
        jobId +
        ' <br/><br/>Query to find unprocessed Accounts: <br/> ' +
        getQuery()
      );
      logError('execute()', ex);
    } else {
      // IF successful
      DebugLog__c debugLog = logInfo(
        'execute()',
        'SchedulableRemoveMemberBCI - Successfully removed all ' +
        acctList.size() +
        ' accounts from monitoring at BCI/Dun&Bradstreet. <br/> Batch job id: ' +
        jobId
      );
    }

    update acclistToUpdate;
    GenericUtils.setJobIdOnCalloutLogs(calloutLogs, jobId);
    insert GenericUtils.getListUpsideDown(calloutLogs); // create callout__c records for all callouts
  }

  global void finish(Database.BatchableContext bc) {
  }

  public static Account deletePersonFromProtfolio(
    Account acct,
    String portfolioId,
    List<Callout__c> calloutLogs
  ) {
    Callout__c calloutLog;
    HttpRequest req = new HttpRequest();
    req = SparCallout.initGenericRequest(req);

    // endpoint becomes /portfolio/default/record/memberNumber
    // MemberNumber is used as clientReferenceId
    req.setEndpoint(
      req.getEndpoint() +
      '/portfolio/' +
      portfolioId +
      '/record/' +
      acct.MemberNumber__c
    );

    req.setMethod(GlobalConstants.HTTP_METHOD_DELETE);
    calloutLog = GenericUtils.setCalloutLog(
      calloutLogs,
      null,
      GlobalConstants.DB_DELETE_FROM_PORTFOLIO,
      GlobalConstants.QUEUED,
      req,
      null,
      acct
    );

    try {
      Http http = new Http();
      HTTPResponse res = http.send(req);
      GenericUtils.debugHttpResponse(res);
      if (res.getStatusCode() == 200) {
        GenericUtils.setResponseValsOnCalloutLog(
          calloutLog,
          res,
          GlobalConstants.OK
        );

        if (
          sparCallout.updateList(
            portfolioId,
            acct.BCIID__c,
            'REMOVE',
            acct,
            calloutLogs
          )
        ) {
          System.debug('REMOVE');
          acct.BCIID__c = '';
          acct.LastUpdateFromSPAR__c = System.now();
          acct.ExcludeFromUpdate__c = true;
        }
      } else {
        // not a 200 response
        GenericUtils.setResponseValsOnCalloutLog(
          calloutLog,
          res,
          GlobalConstants.FAILED
        );
      }
    } catch (System.CalloutException ex) {
      logError('deletePersonFromProtfolio()', ex);
      GenericUtils.setFailedOnCalloutLog(calloutLog);
    }
    return acct;
  }

  /**
   * @description - Returns the query used for identifying members that should be removed from BCI/Dun&Bradstreet tracking.
   * Deceased members are included  when 6 months passes since the deceased date.
   * @author Malin Nilsson (Stretch Customer AB) | 2024-03-14
   * @return String
   **/
  private static String getQuery() {
    String mStatusActive = 'Aktiv';
    String mStatusUpcoming = 'Kommande';
    String mStatusRequestedExit = 'Begärt utträde';

    String soqlQuery =
      'Select id ,SocialSecurityNumber__c, MemberNumber__c, LastUpdateFromSPAR__c,BCIID__c From Account where IsPersonAccount = True and SocialSecurityNumber__c != null and BCIID__c != null ' +
      ' and membershipStatus__c !=\'' +
      mStatusActive +
      '\'' +
      ' and membershipStatus__c !=\'' +
      mStatusUpcoming +
      '\'' +
      ' and membershipStatus__c !=\'' +
      mStatusRequestedExit +
      '\'' +
      ' AND (Deceased__c = false OR (Deceased__c = true AND DeceasedDate__c < N_DAYS_AGO:183))';
    return soqlQuery;
  }

  private static DebugLog__c logInfo(String method, String message) {
    ApexLog.Information infoLog = new ApexLog.Information(
      'RemovePersonFromBCIBatchable',
      method,
      false,
      message,
      null
    );
    return ApexLog.createAndReturnDebugLog(infoLog);
  }

  private static void logError(String method, Exception ex) {
    ApexLog.Error errorLog = new ApexLog.Error(
      'RemovePersonFromBCIBatchable',
      method,
      true,
      ex
    );
    ApexLog.createLogDebug(errorLog);

    System.debug('Exception--> Message: ' + ex.getMessage());
    System.debug('Cause: ' + ex.getCause());
    System.debug('Line number: ' + ex.getLineNumber());
    System.debug('StackTrace: ' + ex.getStackTraceString());
  }
}