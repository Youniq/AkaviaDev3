/**
 * @author Ahmad Amiri
 * Description: Class to handle all callouts to SPAR (BCI) This is used to
 * monitor members personal information such as name and address.
 */
public class SparCallout {


  
  /**
   * Future Method to add a member to our monitoring portfolio with BCI. When the member is added
   * we will subscribe to changes on that members personal information.
   * Performs an update on Single Account record.
   * @param acctJson this is the representation of the member (PersonAccount) as a json
   * @param portId this is the id of our portfolio (it is possible to have several different portfolios but we only have one)
   */
  @future(callout=true)
  public static void addRecordToPortfolio(String acctJson, String portId) {
    system.debug('acctJson' + acctJson);
    Account acct = (Account) JSON.deserialize(acctJson, Account.class);
    String portfolioId = portId;
    String errorMessage = null;
    Boolean doUpdate = false;
    ResponseWrapper personRespWrapper;
    List<Callout__c> calloutLogs = new List<Callout__c>();

    // Using Membernumber as clientReferenceId (prev it was SocialSecurityNumber__c)
    // SSN is the key needed to add a person to the portfolio (mapped to legalId)
    if (acct.SocialSecurityNumber__c != null && acct.MemberNumber__c != null) {
      String token;
      Http http = new Http();
      HttpRequest req = new HttpRequest();
      req = initGenericRequest(req);
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

      ContactWrapper contWrapper = new ContactWrapper();
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

      GenericUtils.debugHttpRequest(req);
      HTTPResponse res = http.send(req);
      Integer code = res.getStatusCode();
      GenericUtils.debugHttpResponse(res);

      if (code == 200 || code == 409) {
        GenericUtils.setResponseValsOnCalloutLog(
          calloutLog,
          res,
          GlobalConstants.OK
        );
        ResponseWrapper respWrapper = getRecordFromPortfolio(
          acct,
          portfolioId,
          calloutLogs
        );
        if (respWrapper.status) {
          personRespWrapper = downloadPersonInfo(
            respWrapper.bisnodeId,
            acct,
            calloutLogs
          );
          System.debug('respWrapper-->  ' + personRespWrapper.status);
          if (personRespWrapper.status) {
            doUpdate = true;
            updateList(
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

    Account accountToUpdate = new Account(Id = acct.Id);
    if (doUpdate) {
      //PersonData personInfo = new PersonData();
      PersonData personInfo = PersonData.parse(personRespWrapper.statusMessage);
      accountToUpdate = MapPersonAccount(accountToUpdate, personInfo);
      System.debug('accountToUpdate-->  ' + accountToUpdate.FirstName);
      accountToUpdate.ExcludeFromUpdate__c = false;
      update accountToUpdate;
    } else {
      if (errorMessage != null) {
        accountToUpdate.BisnodeMessage__c = errorMessage;
        accountToUpdate.LastUpdateFromSPAR__c = System.now();
        update accountToUpdate;
      }
    }

    insert GenericUtils.getListUpsideDown(calloutLogs);
  }

  public static ResponseWrapper getRecordFromPortfolio(
    Account acctRecord,
    String portfolioId,
    List<Callout__c> calloutLogs
  ) {
    String gedi = null;
    HttpRequest req = new HttpRequest();
    req = initGenericRequest(req);
    req.setEndpoint(
      req.getEndpoint() +
      '/portfolio/' +
      portfolioId +
      '/record/' +
      acctRecord.MemberNumber__c
    );
    req.setMethod(GlobalConstants.HTTP_METHOD_GET);

    System.debug(
      'Making callout: Get record from portfolio (' +
      req.getEndpoint() +
      ')'
    );
    Callout__c calloutLog = GenericUtils.setCalloutLog(
      calloutLogs,
      null,
      GlobalConstants.DB_GET_FROM_PORTFOLIO,
      GlobalConstants.QUEUED,
      req,
      null,
      acctRecord
    );

    Http http = new Http();
    HTTPResponse res = http.send(req);
    GenericUtils.debugHttpResponse(res);

    ResponseWrapper respWrapper = new ResponseWrapper();
    respWrapper.status = false;
    if (res.getStatusCode() == 200) {
      Map<String, Object> respMap = (Map<String, Object>) JSON.deserializeUntyped(
        res.getBody()
      );

      String statusMessage = (String) respMap.get('status');
      if (statusMessage == 'single_hit') {
        GenericUtils.setResponseValsOnCalloutLog(
          calloutLog,
          res,
          GlobalConstants.OK
        );
        respWrapper.bisnodeId = (String) respMap.get('gedi');
        respWrapper.status = true;
      } else {
        // no_hits, too_many_hits and pending
        GenericUtils.setResponseValsOnCalloutLog(
          calloutLog,
          res,
          GlobalConstants.FAILED
        );
      }

      respWrapper.statusMessage = statusMessage;
    } else {
      respWrapper.statusMessage = res.getBody();
      GenericUtils.setResponseValsOnCalloutLog(
        calloutLog,
        res,
        GlobalConstants.FAILED
      );
    }

    return respWrapper;
  }

  public static ResponseWrapper downloadPersonInfo(
    String bciId,
    Account acctRecord,
    List<Callout__c> calloutLogs
  ) {
    String GEDI = bciId;
    HttpRequest req = new HttpRequest();

    req = initGenericRequest(req);
    req.setEndpoint(req.getEndpoint() + '/person/gedi/' + GEDI);
    req.setMethod(GlobalConstants.HTTP_METHOD_GET);

    System.debug(
      'Making callout: Download person info (' +
      req.getEndpoint() +
      ')'
    );
    Callout__c calloutLog = GenericUtils.setCalloutLog(
      calloutLogs,
      null,
      GlobalConstants.DB_DOWNLOAD_PERSON,
      GlobalConstants.QUEUED,
      req,
      null,
      acctRecord
    );

    Http http = new Http();
    HTTPResponse res = http.send(req);
    ResponseWrapper respWrapper = new ResponseWrapper();
    respWrapper.statusMessage = res.getBody();

    GenericUtils.debugHttpResponse(res);
    if (res.getStatusCode() == 200) {
      respWrapper.status = true;
      GenericUtils.setResponseValsOnCalloutLog(
        calloutLog,
        res,
        GlobalConstants.OK
      );
    } else {
      respWrapper.status = false;
      GenericUtils.setResponseValsOnCalloutLog(
        calloutLog,
        res,
        GlobalConstants.FAILED
      );
    }
    return respWrapper;
  }

  public static ResponseWrapper getChangesPersonInfo(
    String listId,
    String cursor,
    List<Callout__c> calloutLogs
  ) {
    Callout__c calloutLog;
    Datetime since;
    String sinceEndpoint = '';

    if (String.isBlank(cursor)) {
      since = System.now().addDays(-1);

      // Få instansen av hierarki Custom Setting
      bisnode__c bisnodeSetting = bisnode__c.getOrgDefaults();

      if (bisnodeSetting != null && bisnodeSetting.since__c != null) {
        // get since value from custom setting
        since = bisnodeSetting.since__c;
      }

      String sinceString = since.format('yyyy-MM-dd\'T\'HH:mm:ss.SSS\'Z\'');
      sinceEndpoint = 'since=' + sinceString;
    }
    System.debug('SinceEndpoint--> ' + sinceEndpoint);

    String cursorEndpoint = '&limit=100';
    if (cursor != null && cursor != '') {
      cursorEndpoint = '&next=' + cursor + '&limit=100';
    }
    System.debug('cursorEndpoint --> ' + cursorEndpoint);

    HttpRequest req = new HttpRequest();
    req = initGenericRequest(req);
    req.setEndpoint(
      req.getEndpoint() +
      '/list/' +
      listId +
      '/changes?' +
      sinceEndpoint +
      cursorEndpoint
    );

    System.debug('req.getEndpoint()--> ' + req.getEndpoint());
    req.setMethod(GlobalConstants.HTTP_METHOD_GET);
    calloutLog = GenericUtils.setCalloutLog(
      calloutLogs,
      null,
      GlobalConstants.DB_GET_PERSON_CHANGES,
      GlobalConstants.QUEUED,
      req,
      null,
      null
    );

    ResponseWrapper respWrapper = new ResponseWrapper();

    try {
      Http http = new Http();
      HTTPResponse res = http.send(req);
      respWrapper.statusMessage = res.getBody();

      if (res.getStatusCode() == 200) {
        GenericUtils.setResponseValsOnCalloutLog(
          calloutLog,
          res,
          GlobalConstants.OK
        );
        respWrapper.status = true;
      } else {
        respWrapper.status = false;
        GenericUtils.setResponseValsOnCalloutLog(
          calloutLog,
          res,
          GlobalConstants.FAILED
        );
      }
    } catch (System.CalloutException ex) {
      logError('getChangesPersonInfo()', ex);
      respWrapper.status = false;
      respWrapper.statusMessage =
        'Message: ' +
        ex.getMessage() +
        ' Cause: ' +
        ex.getCause() +
        ' Line number: ' +
        ex.getLineNumber();
      GenericUtils.setFailedOnCalloutLog(calloutLog);
    }

    return respWrapper;
  }

  public static boolean updateList(
    String listId,
    String bciId,
    String action,
    Account acc,
    List<Callout__c> calloutLogs
  ) {
    String GEDI = bciId;
    boolean respStatus = false;
    HttpRequest req = new HttpRequest();
    Callout__c calloutLog;
    req = initGenericRequest(req);
    req.setEndpoint(req.getEndpoint() + '/list/' + listId);
    req.setMethod(GlobalConstants.HTTP_METHOD_POST);

    System.debug('Making callout: Update list (' + req.getEndpoint() + ')');

    String jsons =
      '{\"entities\": {\"' +
      GEDI +
      '\":{\"action\": \"' +
      action +
      '\"}}}';

    req.setBody(jsons);
    calloutLog = GenericUtils.setCalloutLog(
      calloutLogs,
      null,
      GlobalConstants.DB_UPDATE_PERSON_LIST,
      GlobalConstants.QUEUED,
      req,
      null,
      acc
    );
    try {
      Http http = new Http();
      HTTPResponse res = http.send(req);

      GenericUtils.debugHttpResponse(res);
      Integer statusCode = res.getStatusCode();
      if (statusCode == 200) {
        System.debug('Body-->  ' + res.getBody());
        GenericUtils.setResponseValsOnCalloutLog(
          calloutLog,
          res,
          GlobalConstants.OK
        );
        Map<String, Object> resp = (Map<String, Object>) JSON.deserializeUntyped(
          res.getBody()
        );
        String status = (String) resp.get('operationStatus');
        if (status == 'OK') {
          respStatus = true;
        }
      }

      if (statusCode != 200 || !respStatus) {
        GenericUtils.setResponseValsOnCalloutLog(
          calloutLog,
          res,
          GlobalConstants.FAILED
        );
      }
    } catch (System.CalloutException ex) {
      logError('updateList()', ex);
      GenericUtils.setFailedOnCalloutLog(calloutLog);
    }
    return respStatus;
  }

  /**
   * Method to map a PersonData response from BCI to a member (PersonAccount) in salesforce
   * @param acct member to get the new information
   * @param personInfo PersonData response from BCI holding the new information
   * @return  `Account` member with new information
   */
  public static Account MapPersonAccount(Account acct, PersonData personInfo) {
    try {
      System.debug('Person --> ' + personInfo);
      System.debug('Person lastname--> ' + personInfo.person?.familyName);
      System.debug(
        'personInfo.person.protectedIdentity--> ' +
        personInfo.person?.protectedIdentity
      );
      System.debug(
        'personInfo.person.deregistered--> ' + personInfo.person?.deregistered
      );
      System.debug('lastModified--> ' + personInfo.lastModified);
      System.debug('BCI ID--> ' + personInfo.person?.gedi);
      System.debug(
        'SSN--> ' + personInfo.person?.legalId?.socialSecurityNumber
      );
      System.debug('LegalId--> ' + personInfo.person?.legalId);
      acct.BCIID__c = personInfo.person?.gedi;
      acct.BciLastModified__c = (DateTime) JSON.deserialize(
        '"' +
        personInfo.lastModified +
        '"',
        DateTime.class
      );

      acct.ProtectedIdentity__c = personInfo.person?.protectedIdentity;
      if (acct.ProtectedIdentity__c) {
        acct.BisnodeMessage__c = 'Protected Identity';
      } else {
        if (
          personInfo.person?.deregistered &&
          personInfo.person?.firstNames == null
        ) {
          acct.BisnodeMessage__c = 'deregistered - No Update!';
        } else {
          Integer maxSize = 40;
          if (personInfo.person?.firstNames != null) {
            acct.FirstName = string.join(personInfo.person.firstNames, ' ');
            if (acct.FirstName.length() > maxSize)
              acct.FirstName = acct.FirstName.substring(0, maxSize);
          }

          if (personInfo.person?.familyName != '')
            acct.LastName = personInfo.person?.familyName;

          if (
            personInfo.person?.legalId?.socialSecurityNumber != '' &&
            personInfo.person?.legalId?.socialSecurityNumber != null
          )
            acct.SocialSecurityNumber__c = personInfo.person
              ?.legalId
              ?.socialSecurityNumber;

          if (personInfo.person?.gender != '')
            acct.Sex__c = personInfo.person?.gender;

          if (personInfo.person?.preferredFirstName != '')
            acct.PreferredFirstName__c = personInfo.person?.preferredFirstName;

          if (personInfo.person.dateOfBirth != null)
            acct.DateOfBirth__c = Date.valueOf(personInfo.person?.dateOfBirth);

          if (personInfo.person?.dateOfDeath != null) {
            acct.Deceased__c = personInfo.person?.deceased;
            acct.DeceasedDate__c = Date.valueOf(personInfo.person?.dateOfDeath);
          }

          if (personInfo.person?.deregistered) {
            acct.BisnodeMessage__c = 'deregistered';
          } else {
            acct.BisnodeMessage__c = '';
          }

          PersonData.cls_addressList[] adressList = personInfo.person
            ?.addressList;
          acct = mapAddressInformation(acct, adressList);
        }
      }
      acct.LastUpdateFromSPAR__c = System.now();
    } catch (Exception ex) {
      logError('MapPersonAccount()', ex);

      acct.BisnodeMessage__c =
        'Message: ' +
        ex.getMessage() +
        ' Cause: ' +
        ex.getCause() +
        ' Line number: ' +
        ex.getLineNumber();
      Integer maxSize = 255;
      if (acct.BisnodeMessage__c.length() > maxSize)
        acct.BisnodeMessage__c = acct.BisnodeMessage__c.substring(0, maxSize);
    }
    return acct;
  }

  public static Account mapAddressInformation(
    Account acct,
    List<PersonData.cls_addressList> adressList
  ) {
    PersonData.cls_addressList chosenAddress = new PersonData.cls_addressList();
    Boolean addressType = false;

    for (PersonData.cls_addressList addr : adressList) {
      System.debug('addr--> ' + addr);
      if (addr.type == 'Postal') {
        chosenAddress = addr;
        addressType = true;
      }
    }

    if (!addressType && adressList.size() > 0) {
      chosenAddress = adressList[0];
      addressType = true;
    }

    if (addressType) {
      String streetName = '';
      streetName =
        chosenAddress.streetName +
        ' ' +
        chosenAddress.streetNumber +
        ' ' +
        chosenAddress.entrance;
      streetName += ((chosenAddress.apartment == '')
        ? ''
        : ' lgh ' + chosenAddress.apartment);
      streetName += ((chosenAddress.postOfficeBox == '')
        ? ''
        : ' BOX ' + chosenAddress.postOfficeBox);

      acct.PersonMailingStreet = streetName;
      acct.COMailingAddress__c = chosenAddress.careOf;
      acct.PersonMailingCity = chosenAddress.city;
      acct.County__c = chosenAddress.municipality;
      acct.CountyCode__c = chosenAddress.municipalityCode;
      acct.PersonMailingPostalCode = chosenAddress.postalCode;
      acct.PersonMailingCountry = chosenAddress.country;
      acct.PersonMailingState = chosenAddress.region;
    }

    return acct;
  }

  /**
   * Method to remove a member from our monitoring portfolio with BCI. When the member is removed
   * we will no longer subscribe to changes on that members personal information.
   * @param acctJson this is the representation of the member (PersonAccount) as a json
   * @param portfolioId this is the id of our portfolio (it is possible to have several different portfolios but we only have one)
   */
  @future(callout=true)
  public static void deletePersonFromProtfolio(
    String acctJson,
    String portfolioId
  ) {
    system.debug('acctJson ' + acctJson);
    Account acct = (Account) JSON.deserialize(acctJson, Account.class);
    system.debug('acctJson ' + acct.BCIID__c);
    List<Callout__c> calloutLogs = new List<Callout__c>();
    Callout__c calloutLog;

    if (acct.BCIID__c != null) {
      system.debug('acctJson2' + acct.BCIID__c);
 
      HttpRequest req = new HttpRequest();
      req = initGenericRequest(req);
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
        GenericUtils.debugHttpRequest(req);
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
            Account accToUpdate = new Account();
            accToUpdate.Id = acct.Id;
            accToUpdate.BisnodeMessage__c = 'Remove from Bisnode';
            accToUpdate.BCIID__c = '';
            accToUpdate.LastUpdateFromSPAR__c = System.now();
            accToUpdate.ExcludeFromUpdate__c = true;
            update accToUpdate;
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
    }
    insert GenericUtils.getListUpsideDown(calloutLogs);
  }

  /**
   * Method to initiate a generic httpRequest with default headers
   * @param req
   * @param portfolioId Id of the BCI monitoring portfolio we want to use
   * @param recordKey Key for adding/removing person from portfolio. (SSN / BCIID)
   * @return  `HttpRequest`
   */
  public static HttpRequest initGenericRequest(HttpRequest req) {

     String environment = GenericUtils.getCurrEnvironment();
      String namedCredential;

      switch on environment.toUpperCase() {
          when 'DEV', 'UAT'{
          namedCredential = 'callout:BisnodeBCI_Test';
          }
          when 'PROD' {
              namedCredential = 'callout:BisnodeBCI_Prod';
          }
          when else {
            throw new AuraHandledException('Unknown environment');
          }
      }
      System.debug(LoggingLevel.DEBUG, 'BCI/SPAR named credential to use: ' + namedCredential);
      req.setEndpoint(namedCredential);        
      return req;
  }

  private static void logError(String method, Exception ex) {
    ApexLog.Error errorLog = new ApexLog.Error('SparCallout', method, true, ex);
    ApexLog.createLogDebug(errorLog);

    System.debug('Exception--> Message: ' + ex.getMessage());
    System.debug('Cause: ' + ex.getCause());
    System.debug('Line number: ' + ex.getLineNumber());
    System.debug('StackTrace: ' + ex.getStackTraceString());
  }

  public class LoginResponseWrapperClass {
    public String access_token;
    public String token_type;
    public Integer expires_in;
    public String error;
    public String error_description;
  }

  public class ContactWrapper {
    public String legalId;
    public String sourceCountry;
  }

  public class ResponseWrapper {
    public String bisnodeId;
    public String statusMessage;
    public Boolean status;
  }
}