/**
 * @description       :
 * @author            : Malin Nilsson (Stretch Customer AB)
 * @group             :
 * @last modified on  : 2024-12-16
 * @last modified by  : Malin Nilsson (Stretch Customer AB)
 **/
public with sharing class GenericUtils {
  public GenericUtils() {
  }

  /**
   * @description Check if current running environment is Sandbox
   * @return  `Boolean`
   */
  public static Boolean isSandbox() {
    return [SELECT IsSandbox FROM Organization LIMIT 1].IsSandbox;
  }

  public static String getCurrEnvironment(){
      OrgSetting__mdt currOrgSetting  = [SELECT DeveloperName, Environment__c
      FROM OrgSetting__mdt
      WHERE DeveloperName = 'thisOrgSetting'
      LIMIT 1];
      String environment = currOrgSetting.Environment__c;
      System.debug(LoggingLevel.DEBUG, 'Current OrgSetting Environment: ' + environment);

      if(environment == 'PROD' && isSandbox()){
        String error = 'Invalid combination: Current org is a Sandbox and the OrgSetting Environment is PROD. Forbidden to configure a sandbox as PROD';
          System.debug(LoggingLevel.ERROR, error);
          throw new AuraHandledException(error);
      }
      return environment;
  }

  /**
   * @description Method to debug Endpoint and Body before sending request
   * @param req
   */
  public static void debugHttpRequest(HttpRequest req) {
    System.debug('Endpoint-->  ' + req.getEndpoint());
    System.debug('Body-->  ' + req.getBody());
  }

  /**
   * @description Method to debug StatusCode and Body of response
   * @param res
   */
  public static void debugHttpResponse(HttpResponse res) {
    System.debug('Code-->  ' + res.getStatusCode());
    System.debug('Body-->  ' + res.getBody());
  }

  public static List<SObject> getListUpsideDown(List<SObject> objlist) {
    List<SObject> returnList = new List<SObject>();
    for (Integer i = objlist.size() - 1; i >= 0; i--) {
      SObject o = objlist[i];
      returnList.add(o);
    }
    return returnList;
  }

  /**
   * @description - prepaews callout__c record and adds it to list. Does not perform an insert
   * @author Malin Nilsson (Stretch Customer AB) | 2024-03-19
   * @param logs - the list instance to add logs to
   * @param jobId - String
   * @param type - String matching picklist field api value on callout__c.type__c
   * @param status - String matching picklist field api value on callout__c.status__c
   * @param req - HttpRequest
   * @param resp - HttpResponse
   * @return Callout__c
   **/
  public static Callout__c setCalloutLog(
    List<Callout__c> logs,
    String jobId,
    String type,
    String status,
    HttpRequest req,
    HttpResponse resp,
    Account acc
  ) {
    Callout__c calloutLog = new Callout__c(
      jobId__c = jobId,
      Type__c = type,
      Status__c = status,
      Code__c = resp != null ? String.valueOf(resp.getStatusCode()) : null,
      request__c = req != null ? req.getBody().left(131000) : null,
      response__c = resp != null ? resp.getBody().left(131000) : null,
      path__c = req.getEndpoint(),
      account__c = acc?.Id
    );
    if (logs != null) {
      logs.add(calloutLog);
    }
    return calloutLog;
  }

  /**
   * @description - Sets the Status__c to Failed on Callout__c record.
   * @author Malin Nilsson (Stretch Customer AB) | 2024-03-19
   * @param calloutLog - Callout__c
   **/
  public static void setFailedOnCalloutLog(Callout__c calloutLog) {
    if (calloutLog != null) {
      calloutLog.Status__c = 'Failed';
    }
  }

  /**
   * @description - Sets the Response on Callout__c record.
   * @author Malin Nilsson (Stretch Customer AB) | 2024-03-19
   * @param calloutLog - Callout__c
   **/
  public static void setResponseValsOnCalloutLog(
    Callout__c calloutLog,
    HttpResponse resp,
    String status
  ) {
    if (calloutLog != null) {
      calloutLog.response__c = resp != null
        ? resp.getBody().left(131000)
        : null;
      calloutLog.Code__c = resp != null
        ? String.valueOf(resp.getStatusCode())
        : null;

      if (status != null) {
        calloutLog.Status__c = status;
      }
    }
  }

  public static void setJobIdOnCalloutLogs(
    List<Callout__c> calloutLogs,
    String jobId
  ) {
    if (calloutLogs != null) {
      for (Integer i = 0; i < calloutLogs.size(); i++) {
        Callout__c log = calloutLogs[i];
        log.jobId__c = jobId;
      }
    }
  }

  /**
   * @description  - Returns a String value representing the Object type API name
   * @author Malin Nilsson (Stretch Customer AB) | 2024-03-18
   * @param recordId - The record Id
   * @return String - The Object API Name
   **/
  public static String getObjTypeByRecorId(Id recordId) {
    String objtype;
    if (recordId != null) {
      Schema.SObjectType type = recordId.getSobjectType();
      objType = String.valueOf(type);
    }
    return objType;
  }
}