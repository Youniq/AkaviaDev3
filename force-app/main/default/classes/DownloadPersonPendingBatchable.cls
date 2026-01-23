/**
 * @description       : Lägger in medlemmar för prenumeration på dess personuppgifter från Dun&Bradstreet (Gamla Basun och BCI)
 * @author            : Unknown
 * @group             :
 * @last modified on  : 2025-02-28
 * @last modified by  : Malin Nilsson (Stretch Customer AB)
 **/
global class DownloadPersonPendingBatchable implements Database.Batchable<sObject>, Database.AllowsCallouts {
  private String query;

  global DownloadPersonPendingBatchable() {
    this.query = getQuery();
  }

  // Added an alternative way of making query as a step when Akavia wanted to reset the whole DnB registry (list & portfolio).
  // Hence needed a way of including all relevant members, not just the ones whithout a BCIID.
  // Run using this query to include all wanted members:
  /* String soqlQuery =
      'Select id ,SocialSecurityNumber__c,MemberNumber__c, LastUpdateFromSPAR__c,BisnodeMessage__c, BCIID__c From Account where IsPersonAccount = True and MissingSocialSecurityNumber__c = false and ExcludeFromUpdate__c = false and SocialSecurityNumber__c != null and (membershipStatus__c =\'Aktiv\' or membershipStatus__c =\'Kommande\' or membershipStatus__c =\'Begärt utträde\')';
      DownloadPersonPendingBatchable batch = new DownloadPersonPendingBatchable(soqlQuery);
      Database.executeBatch(batch, 5);
    */
  global DownloadPersonPendingBatchable(String incomingQuery) {
    this.query = incomingQuery;
  }

  global Database.QueryLocator start(Database.BatchableContext bc) {
    return Database.getQueryLocator(this.query);
  }

  global void execute(Database.BatchableContext bc, List<Account> acctList) {
    List<Account> acclistToUpdate = new List<Account>();
    List<Callout__c> calloutLogs = new List<Callout__c>(); // The list will be populated with records. The records are to be inserted at the end of the job.

    Id jobId = bc.getJobId();
    Integer noOfFailures = 0;

    for (Account acct : acctList) {
      Account accToUpdate = addRecordToPortfolio(acct, 'default', calloutLogs);
      if (accToUpdate != null) {
        acclistToUpdate.add(accToUpdate);

        if (String.isBlank(accToUpdate.BCIID__c)) {
          noOfFailures++;
        }
      }
    }

    update acclistToUpdate;
    GenericUtils.setJobIdOnCalloutLogs(calloutLogs, jobId);
    insert GenericUtils.getListUpsideDown(calloutLogs); // create callout__c records for all callouts

    if (noOfFailures > 0) {
      // The constructor will create debug log with the information.
      new BCI_IntegrationException(
        'DownloadPersonPendingBatchable',
        'execute()',
        'SchedulableDownloadMemberBCI - ' +
        noOfFailures +
        ' out of ' +
        acctList.size() +
        ' accounts failed to be added for monitoring at BCI/Dun&Bradstreet in this batch. <br/> Batch job id: ' +
        jobId +
        '<br/><br/> Query to find unprocessed Accounts: <br/>' +
        getQuery()
      );
    } else {
      // If successful
      ApexLog.Information debugLog = getInfoLog(
        'execute()',
        'DownloadPersonPendingBatchable - Successfully added all ' +
        acctList.size() +
        ' accounts to monitoring at BCI/Dun&Bradstreet. <br/> Batch job id: ' +
        jobId
      );
      ApexLog.createLogDebug(debugLog);
    }
  }

  global void finish(Database.BatchableContext bc) {
    //System.debug('result--> ' + result.size());
  }

  public static Account addRecordToPortfolio(
    Account acct,
    String portId,
    List<Callout__c> calloutLogs
  ) {
    String portfolioId = portId;
    String errorMessage = null;
    Boolean doUpdate = false;
    SparCallout.ResponseWrapper personRespWrapper;

    if (acct.SocialSecurityNumber__c != null) {
      HttpRequest req = new HttpRequest();
      req = SparCallout.initGenericRequest(req);
      req.setEndpoint(
        req.getEndpoint() +
        '/portfolio/' +
        portfolioId +
        '/record/' +
        acct.MemberNumber__c
      );
      req.setMethod(GlobalConstants.HTTP_METHOD_PUT);

      System.debug(
        'Making callout: Add person to portfolio (' +
        req.getEndpoint() +
        ')'
      );

      SparCallout.ContactWrapper contWrapper = new SparCallout.ContactWrapper();
      contWrapper.legalId = acct.SocialSecurityNumber__c;
      contWrapper.sourceCountry = 'SE';

      req.setBody(System.json.serialize(contWrapper));
      Callout__c calloutLog = GenericUtils.setCalloutLog(
        calloutLogs,
        null,
        GlobalConstants.DB_ADD_TO_PORTFOLIO,
        GlobalConstants.QUEUED,
        req,
        null,
        acct
      );

      Http http = new Http();
      HTTPResponse res = http.send(req);
      Integer code = res.getStatusCode();
      GenericUtils.debugHttpResponse(res);

      if (code == 200 || code == 409) {
        GenericUtils.setResponseValsOnCalloutLog(
          calloutLog,
          res,
          GlobalConstants.OK
        );
        SparCallout.ResponseWrapper respWrapper = SparCallout.getRecordFromPortfolio(
          acct,
          portfolioId,
          calloutLogs
        );

        if (respWrapper.status) {
          personRespWrapper = SparCallout.downloadPersonInfo(
            respWrapper.bisnodeId,
            acct,
            calloutLogs
          );
          if (personRespWrapper.status) {
            doUpdate = true;
            SparCallout.updateList(
              portfolioId,
              respWrapper.bisnodeId,
              'ADD',
              acct,
              calloutLogs
            );
          } else {
            errorMessage = personRespWrapper.statusMessage;
          }
        } else {
          System.debug('Error respWrapper-->  ' + respWrapper);
          errorMessage = respWrapper.statusMessage;
        }
      } else {
        System.debug('Error Code-->  ' + code);
        errorMessage = 'Error Code:  ' + code;
        GenericUtils.setResponseValsOnCalloutLog(
          calloutLog,
          res,
          GlobalConstants.FAILED
        );
      }
    }

    if (doUpdate) {
      PersonData personInfo = PersonData.parse(personRespWrapper.statusMessage);
      Account acctToUpdate = SparCallout.MapPersonAccount(acct, personInfo);
      return acctToUpdate;
    } else {
      if (errorMessage != null) {
        acct.BisnodeMessage__c = errorMessage;
        acct.LastUpdateFromSPAR__c = System.now();
        return acct;
      }
    }
    return null;
  }

  /**
   * @description - Returns the query used for identifying members that should be added to BCI/Dun&Bradstreet for monitoring.
   * @author Malin Nilsson (Stretch Customer AB) | 2024-03-19
   * @return String
   **/
  private static String getQuery() {
    String mStatusActive = 'Aktiv';
    String mStatusUpcoming = 'Kommande';
    String mStatusRequestedExit = 'Begärt utträde';

    String soqlQuery =
      'Select id ,SocialSecurityNumber__c, MemberNumber__c, LastUpdateFromSPAR__c,BisnodeMessage__c, BCIID__c From Account ' +
      ' where IsPersonAccount = True and MissingSocialSecurityNumber__c = false and ExcludeFromUpdate__c = false and SocialSecurityNumber__c != null and BCIID__c = null ' +
      ' and (membershipStatus__c =\'' +
      mStatusActive +
      '\'' +
      ' or membershipStatus__c =\'' +
      mStatusUpcoming +
      '\'' +
      ' or membershipStatus__c =\'' +
      mStatusRequestedExit +
      '\')';

    return soqlQuery;
  }

  private static ApexLog.Information getInfoLog(String method, String message) {
    ApexLog.Information infoLog = new ApexLog.Information(
      'DownloadPersonPendingBatchable',
      method,
      false,
      message,
      null
    );
    return infoLog;
  }
}