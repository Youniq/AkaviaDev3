/**
 * Helpclass to build and handle logic for callouts to BASUN
 * BASUN data is used for updating Workplace and Employer data
 * @author Ahmad Amiri
 * @since 2021-01-01
 */
public class BasunCallout {
  /**
   * Method to fetch access token from Basun to be used as authentication in next callout. 
   * @return  `String` access_token
   */
  public static String getAccessToken() {
    
    HttpRequest req = new HttpRequest();
    req.setEndpoint('callout:BisnodeLoginTest');
    req.setMethod(GlobalConstants.HTTP_METHOD_POST);
    req.setHeader(
      GlobalConstants.HTTP_HEADER_FIELD_NAME_CONTENT_TYPE,
      GlobalConstants.HTTP_HEADER_FIELD_CONTENT_TYPE_VALUE_APPLICATION_URLENCODED
    );
    req.setBody(GlobalConstants.BISNODE_GRANDTYPE_BBC);

    Http http = new Http();
    HTTPResponse res = http.send(req);
    System.debug('  Token: getBody()-->' + res.getBody());
    LoginResponseWrapperClass resp = (LoginResponseWrapperClass) System.JSON.deserialize(
      res.getBody(),
      LoginResponseWrapperClass.class
    );

    System.debug('Error-->' + resp.error);
    System.debug('Error Description-->' + resp.error_description);
    System.debug('Token-->' + resp.access_token);
    return resp.access_token;
  }

  /**
   * Perfroms Callout to BASUN to update companies (employer) in salesforce 
   * with latest information from BASUN
   * @param listParam 
   * @param jobId 
   * @return  `CompanyChangesResponse`
   */
  public static CompanyChangesResponse subscribeCompanies(List<CompnayChangesJSON> listParam,Id jobId) {
    String token;
    token = getAccessToken();

    HttpRequest req = new HttpRequest();
    req = initGenericRequest(req, token);
    req.setEndpoint(req.getEndpoint() + '/companies/changes');
    req.setMethod(GlobalConstants.HTTP_METHOD_POST);
   
    req.setBody(System.json.serialize(listParam));
    System.debug('Body-->  ' + System.json.serialize(listParam));
    Datetime startTime = System.now();
    Http http = new Http();
    HTTPResponse res = http.send(req);
    Decimal duration = System.now().getTime() - startTime.getTime();
    System.debug('Code-->  ' + res.getStatusCode());
    System.debug('Body-->  ' + res.getBody());

    Callout__c calloutLog = new Callout__c(
      jobId__c = jobId != null ? jobId : null,
      Type__c = 'DailyEmployerUpdateBasun',
      Status__c = 'OK',
      request__c = System.json.serialize(listParam),
      path__c = req.getEndpoint(),
      sentOn__c = startTime,
      Duration__c = duration
    );

    CompanyChangesResponse compResponse = new CompanyChangesResponse();
    if (res.getStatusCode() == 200) {
      calloutLog.Status__c = 'OK';
      calloutLog.Response__c = res.getBody();

      compResponse = CompanyChangesResponse.parse(res.getBody());
      System.debug('changes : ' + compResponse.changes);
    } else {
      calloutLog.Status__c = 'Failed';
      calloutLog.errorLog__c = res.getBody();
    }
    try {
      // Only add callout log if there's an update in the response or if the callout didn't go well.
      if (compResponse.hasAnyUpdates() || res.getStatusCode() != 200) {
        insert calloutLog;
      }
    } catch (Exception e) {
      system.debug('Error while insert calloutlog. ' + e.getMessage());
      // do nothing - just continue.
    }

    return compResponse != null ? compResponse : null;
  }

  /**
   * 
   * @param listParam 
   * @param jobId 
   * @return  `WorksiteChangesResponse`
   */
  public static WorksiteChangesResponse subscribeWorksites(List<WorksiteChangesJSON> listParam,Id jobId) {
    String token;
    token = getAccessToken();
   
    //Create Request with headers
    Http http = new Http();
    HttpRequest req = new HttpRequest();
    req = initGenericRequest(req, token);
    req.setEndpoint(req.getEndpoint()+'/worksites/changes');
    req.setMethod(GlobalConstants.HTTP_METHOD_POST);
    
    //Set body
    req.setBody(System.json.serialize(listParam));
    System.debug('Body-->  ' + System.json.serialize(listParam));
    Datetime startTime = System.now();

    //Send request
    HTTPResponse res = http.send(req);
    Decimal duration = System.now().getTime() - startTime.getTime();
    System.debug('Code-->  ' + res.getStatusCode());
    System.debug('Body-->  ' + res.getBody());

    Callout__c calloutLog = new Callout__c(
      jobId__c = jobId != null ? jobId : null,
      Type__c = 'DailyWorkplaceUpdateBasun',
      Status__c = 'OK',
      request__c = System.json.serialize(listParam),
      path__c = req.getEndpoint(),
      sentOn__c = startTime,
      Duration__c = duration
    );

    WorksiteChangesResponse wResponse = new WorksiteChangesResponse();

    if (res.getStatusCode() == 200) {
      calloutLog.Status__c = 'OK';
      calloutLog.Response__c = res.getBody();

      wResponse = WorksiteChangesResponse.parse(res.getBody());
      System.debug('changes : ' + wResponse.changes);
    } else {
      calloutLog.Status__c = 'Failed';
      calloutLog.errorLog__c = res.getBody();
    }
    try {
      //Only add callout log if there's an update in the response or if the callout didn't go well.
      if (wResponse.hasAnyUpdates() || res.getStatusCode() != 200) {
        insert calloutLog;
      }
    } catch (Exception e) {
      system.debug('Error while insert calloutlog. ' + e.getMessage());
      //do nothing - just continue.
    }

    return wResponse != null ? wResponse : null;
  }

   /**
   * Method to initiate a generic httpRequest to BBC (Basun) with default headers
   * @param req 
   * @param token 
   * @return  `HttpRequest`
   */
  private static HttpRequest initGenericRequest(HttpRequest req, String token){
    
    req.setEndpoint(
        'callout:BisnodeBBC'
    );
    req.setHeader(
      GlobalConstants.HTTP_HEADER_FIELD_NAME_CONTENT_TYPE,
      GlobalConstants.HTTP_HEADER_VALUE_APPLICATION_HAL_JSON
    );
    req.setHeader(
      GlobalConstants.HTTP_HEADER_FIELD_NAME_ACCEPT,
      GlobalConstants.HTTP_HEADER_VALUE_APPLICATION_HAL_JSON
    );
    req.setHeader(
      GlobalConstants.HTTP_HEADER_FIELD_NAME_AUTHORIZATION,
      GlobalConstants.HTTP_HEADER_FIELD_AUTHORIZATION_VALUE_BEARER + token
    );

    return req;
  }

  /****************************************************************
   * @author: Ahmad Amiri
   * @date: 2020-09-08
   * @param: TODO
   * @return: TODO
   * @description: This method invokes the callout and get companies info from Bisnode
   *****************************************************************/
  public static CompanySearchResponse getCompanies(
    String companyNumber,
    String companyCity,
    String companyLegalName,
    String companyPostalAddress,
    String companyStatus,
    String companyType
  ) {
    String token;
    token = getAccessToken();

    if (token != null) {
      GenericRestClient restClient = new GenericRestClient();

      restClient.setHeader(
        GlobalConstants.HTTP_HEADER_FIELD_NAME_CONTENT_TYPE,
        GlobalConstants.HTTP_HEADER_FIELD_CONTENT_TYPE_VALUE_APPLICATION_JSON
      );
      restClient.setHeader(
        GlobalConstants.HTTP_HEADER_FIELD_NAME_ACCEPT,
        GlobalConstants.HTTP_HEADER_VALUE_APPLICATION_HAL_JSON
      );
      restClient.setHeader(
        GlobalConstants.HTTP_HEADER_FIELD_NAME_AUTHORIZATION,
        GlobalConstants.HTTP_HEADER_FIELD_AUTHORIZATION_VALUE_BEARER + token
      );
      restClient.setMethod(GlobalConstants.HTTP_METHOD_GET);
      restClient.startNewRequest('companies');
      if (
        companyNumber == null ||
        String.isNotBlank(companyNumber) ||
        String.isNotEmpty(companyNumber)
      )
        restClient.addParam('companyNumber', companyNumber);
      if (
        companyCity == null ||
        String.isNotBlank(companyCity) ||
        String.isNotEmpty(companyCity)
      )
        restClient.addParam('companyCity', companyCity);

      if (
        companyLegalName == null ||
        String.isNotBlank(companyLegalName) ||
        String.isNotEmpty(companyLegalName)
      )
        restClient.addParam('companyLegalName', companyLegalName);

      if (
        companyPostalAddress == null ||
        String.isNotBlank(companyPostalAddress) ||
        String.isNotEmpty(companyPostalAddress)
      )
        restClient.addParam('companyAddress', companyPostalAddress);

      if (
        companyStatus == null ||
        String.isNotBlank(companyStatus) ||
        String.isNotEmpty(companyStatus)
      ) {
        if (companyStatus != 'none') {
          restClient.addParam('companyStatus', companyStatus);
        }
      }

      if (
        companyType == null ||
        String.isNotBlank(companyType) ||
        String.isNotEmpty(companyType)
      ) {
        if (companyType != 'none') {
          restClient.addParam('companyType', companyType);
        }
      }

      restClient.addParam('language', 'sv');

      HttpRequest req = restClient.createReqWithNamedCredGet(
        'callout:BisnodeBBC/'
      );
      Http http = new Http();

      HttpResponse res = new HttpResponse();
      res = http.send(req);
      CompanySearchResponse companyInfo;
      System.debug('res.getBody() : ' + res.getStatusCode());

      if (res.getStatusCode() == 200) {
        companyInfo = CompanySearchResponse.parse(res.getBody());
        System.debug('res.getBody() : ' + companyInfo.hitsReturned);
        System.debug('res.getBody() : ' + companyInfo.links.first);
        return companyInfo;
      }
    }
    return null;
  }

  /****************************************************************
   * @author: Jenny Blomberg
   * @date: 2022-12-05
   * @param: TODO
   * @return: TODO
   * @description: This method invokes the callout and get CodeTypes to be filtered on from Bisnode
   *****************************************************************/

  public static CodeTypesResponse getCodeTypes(String codeTypePrefix) {
    String token;
    token = getAccessToken();

    if (token != null) {
      GenericRestClient restClient = new GenericRestClient();

      restClient.setHeader(
        GlobalConstants.HTTP_HEADER_FIELD_NAME_CONTENT_TYPE,
        GlobalConstants.HTTP_HEADER_FIELD_CONTENT_TYPE_VALUE_APPLICATION_JSON
      );
      restClient.setHeader(
        GlobalConstants.HTTP_HEADER_FIELD_NAME_ACCEPT,
        GlobalConstants.HTTP_HEADER_VALUE_APPLICATION_HAL_JSON
      );
      restClient.setHeader(
        GlobalConstants.HTTP_HEADER_FIELD_NAME_AUTHORIZATION,
        GlobalConstants.HTTP_HEADER_FIELD_AUTHORIZATION_VALUE_BEARER + token
      );
      restClient.setMethod(GlobalConstants.HTTP_METHOD_GET);
      restClient.startNewRequest('codetypes/' + codeTypePrefix);

      HttpRequest req = restClient.createReqWithNamedCredGet(
        'callout:BisnodeBBC/'
      );
      Http http = new Http();

      HttpResponse res = new HttpResponse();
      res = http.send(req);
      CodeTypesResponse codeTypes;
      System.debug('res.getBody() : ' + res.getStatusCode());

      if (res.getStatusCode() == 200) {
        codeTypes = CodeTypesResponse.parse(res.getBody());
        system.debug(
          'No of CodeTypeCountries returned: ' + codeTypes.countries.size()
        );
        return codeTypes;
      }
    }
    return null;
  }

  public static CompanySearchResponse getCompaniesByLink(String urlString) {
    System.debug('urlString : ' + urlString);
    String token;
    token = getAccessToken();

    if (token != null) {
      HttpRequest restClient = new HttpRequest();
      restClient = initGenericRequest(restClient, token);
      restClient.setEndpoint(urlString); 
      restClient.setMethod(GlobalConstants.HTTP_METHOD_GET);

      Http http = new Http();

      HttpResponse res = new HttpResponse();
      res = http.send(restClient);
      CompanySearchResponse companyInfo;
      System.debug('res.getBody() : ' + res.getStatusCode());

      if (res.getStatusCode() == 200) {
        companyInfo = CompanySearchResponse.parse(res.getBody());
        System.debug('res.getBody() : ' + companyInfo.hitsReturned);
        System.debug('res.getBody() : ' + companyInfo.links.first);
        return companyInfo;
      }
    }
    return null;
  }

  public static CompanyDetails getCompanyInfo(String Id, String lang) {
    String token;
    token = getAccessToken();

    if (token != null) {
      GenericRestClient restClient = new GenericRestClient();

      restClient.setHeader(
        GlobalConstants.HTTP_HEADER_FIELD_NAME_CONTENT_TYPE,
        GlobalConstants.HTTP_HEADER_FIELD_CONTENT_TYPE_VALUE_APPLICATION_JSON
      );
      restClient.setHeader(
        GlobalConstants.HTTP_HEADER_FIELD_NAME_ACCEPT,
        GlobalConstants.HTTP_HEADER_VALUE_APPLICATION_HAL_JSON
      );
      restClient.setHeader(
        GlobalConstants.HTTP_HEADER_FIELD_NAME_AUTHORIZATION,
        GlobalConstants.HTTP_HEADER_FIELD_AUTHORIZATION_VALUE_BEARER + token
      );
      restClient.setMethod(GlobalConstants.HTTP_METHOD_GET);

      String companyId = Encodingutil.urlEncode(
          Id,
          GlobalConstants.URL_ENCODING_SCHEME_DEFAULT
        )
        .replaceAll('\\:', '%3A');

      restClient.startNewRequest('companies/' + companyId);

      restClient.addParam('language', 'sv');
      HttpRequest req = restClient.createReqWithNamedCredGet(
        'callout:BisnodeBBC/'
      );
      Http h = new Http();

      HttpResponse res = new HttpResponse();
      res = h.send(req);
      CompanyDetails companyInfo;
      System.debug('res.getBody() : ' + res.getStatusCode());

      if (res.getStatusCode() == 200) {
        System.debug('res.getBody() : ' + res.getBody());
        companyInfo = CompanyDetails.parse(res.getBody());
        System.debug('companyInfo--> : ' + companyInfo);
        System.debug('lastModified : ' + companyInfo.lastModified);
        System.debug('name : ' + companyInfo.name);
        return companyInfo;
      }
    }
    return null;
  }

  public static WorksiteDetails getWorksiteInfo(String Id, String lang) {
    String token;
    token = getAccessToken();
    
    if (token != null) {
      GenericRestClient restClient = new GenericRestClient();

      restClient.setHeader(
        GlobalConstants.HTTP_HEADER_FIELD_NAME_CONTENT_TYPE,
        GlobalConstants.HTTP_HEADER_FIELD_CONTENT_TYPE_VALUE_APPLICATION_JSON
      );
      restClient.setHeader(
        GlobalConstants.HTTP_HEADER_FIELD_NAME_ACCEPT,
        GlobalConstants.HTTP_HEADER_VALUE_APPLICATION_HAL_JSON
      );
      restClient.setHeader(
        GlobalConstants.HTTP_HEADER_FIELD_NAME_AUTHORIZATION,
        GlobalConstants.HTTP_HEADER_FIELD_AUTHORIZATION_VALUE_BEARER + token
      );
      restClient.setMethod(GlobalConstants.HTTP_METHOD_GET);

      String worksiteId = Encodingutil.urlEncode(
          Id,
          GlobalConstants.URL_ENCODING_SCHEME_DEFAULT
        )
        .replaceAll('\\:', '%3A');

      restClient.startNewRequest('worksites/' + worksiteId);

      restClient.addParam('language', 'sv');
      HttpRequest req = restClient.createReqWithNamedCredGet(
        'callout:BisnodeBBC/'
      );
      Http http = new Http();

      HttpResponse res = new HttpResponse();
      res = http.send(req);
      WorksiteDetails info;
      System.debug('res.getBody() : ' + res.getStatusCode());

      if (res.getStatusCode() == 200) {
        System.debug('res.getBody() : ' + res.getBody());
        info = WorksiteDetails.parse(res.getBody());
        System.debug('companyInfo--> : ' + info);
        System.debug('lastModified : ' + info.lastModified);
        System.debug('name : ' + info.name);
        return info;
      }
    }
    return null;
  }

  /****************************************************************
   * @author: Ahmad Amiri
   * @date: 2020-09-08
   * @param: TODO
   * @return: TODO
   * @description: This method invokes the callout and get companies info from Bisnode
   *****************************************************************/

  public static WorksiteSearchResponse getWorksites(
    String companyNumber,
    String worksiteNumber,
    String companyLegalNameWorksite,
    String worksiteAddress,
    String worksiteCity,
    String worksiteStatus,
    String worksiteType
  ) {
    String token;
    token = getAccessToken();
    if (token != null) {
      GenericRestClient restClient = new GenericRestClient();

      restClient.setHeader(
        GlobalConstants.HTTP_HEADER_FIELD_NAME_CONTENT_TYPE,
        GlobalConstants.HTTP_HEADER_FIELD_CONTENT_TYPE_VALUE_APPLICATION_JSON
      );
      restClient.setHeader(
        GlobalConstants.HTTP_HEADER_FIELD_NAME_ACCEPT,
        GlobalConstants.HTTP_HEADER_VALUE_APPLICATION_HAL_JSON
      );
      restClient.setHeader(
        GlobalConstants.HTTP_HEADER_FIELD_NAME_AUTHORIZATION,
        GlobalConstants.HTTP_HEADER_FIELD_AUTHORIZATION_VALUE_BEARER + token
      );
      restClient.setMethod(GlobalConstants.HTTP_METHOD_GET);
      restClient.startNewRequest('worksites');

      if (
        companyNumber == null ||
        String.isNotBlank(companyNumber) ||
        String.isNotEmpty(companyNumber)
      )
        restClient.addParam('companyNumber', companyNumber);

      if (
        worksiteNumber == null ||
        String.isNotBlank(worksiteNumber) ||
        String.isNotEmpty(worksiteNumber)
      )
        restClient.addParam('worksiteNumber', worksiteNumber);

      if (
        companyLegalNameWorksite == null ||
        String.isNotBlank(companyLegalNameWorksite) ||
        String.isNotEmpty(companyLegalNameWorksite)
      )
        restClient.addParam('companyLegalName', companyLegalNameWorksite);

      if (
        worksiteAddress == null ||
        String.isNotBlank(worksiteAddress) ||
        String.isNotEmpty(worksiteAddress)
      )
        restClient.addParam('worksiteGeneralAddress', worksiteAddress);

      if (
        worksiteCity == null ||
        String.isNotBlank(worksiteCity) ||
        String.isNotEmpty(worksiteCity)
      )
        restClient.addParam('worksiteGeneralCity', worksiteCity);

      if (
        worksiteStatus == null ||
        String.isNotBlank(worksiteStatus) ||
        String.isNotEmpty(worksiteStatus)
      ) {
        if (worksiteStatus != 'none') {
          restClient.addParam('worksiteStatus', worksiteStatus);
        }
      }

      if (
        worksiteType == null ||
        String.isNotBlank(worksiteType) ||
        String.isNotEmpty(worksiteStatus)
      ) {
        if (worksiteType != 'none') {
          restClient.addParam('worksiteType', worksiteType);
        }
      }

      restClient.addParam('language', 'sv');

      HttpRequest req = restClient.createReqWithNamedCredGet(
        'callout:BisnodeBBC/'
      );
      Http h = new Http();

      HttpResponse res = new HttpResponse();
      res = h.send(req);
      WorksiteSearchResponse worksiteInfo;
      System.debug('res.getBody() : ' + res.getBody());
      if (res.getStatusCode() == 200) {
        worksiteInfo = WorksiteSearchResponse.parse(res.getBody());
        System.debug('worksiteInfo : ' + worksiteInfo.worksites);
        return worksiteInfo;
      }
    }
    return null;
  }

  public static WorksiteSearchResponse getWorksitesByLink(String urlString) {
    System.debug('urlString : ' + urlString);
    String token;
    token = getAccessToken();

    if (token != null) {
      HttpRequest restClient = new HttpRequest();
      restClient.setEndpoint(urlString);

      restClient.setHeader(
        GlobalConstants.HTTP_HEADER_FIELD_NAME_CONTENT_TYPE,
        GlobalConstants.HTTP_HEADER_FIELD_CONTENT_TYPE_VALUE_APPLICATION_JSON
      );
      restClient.setHeader(
        GlobalConstants.HTTP_HEADER_FIELD_NAME_ACCEPT,
        GlobalConstants.HTTP_HEADER_VALUE_APPLICATION_HAL_JSON
      );
      restClient.setHeader(
        GlobalConstants.HTTP_HEADER_FIELD_NAME_AUTHORIZATION,
        GlobalConstants.HTTP_HEADER_FIELD_AUTHORIZATION_VALUE_BEARER + token
      );
      restClient.setMethod(GlobalConstants.HTTP_METHOD_GET);

      Http h = new Http();

      HttpResponse res = new HttpResponse();
      res = h.send(restClient);

      WorksiteSearchResponse info;
      System.debug('res.getBody() : ' + res.getStatusCode());

      if (res.getStatusCode() == 200) {
        info = WorksiteSearchResponse.parse(res.getBody());
        return info;
      }
    }
    return null;
  }

  class LoginResponseWrapperClass {
    public String access_token;
    public String token_type;
    public Integer expires_in;
    public String error;
    public String error_description;
  }

  public class CompnayChangesJSON {
    public String companyId; //string
    public String since; //2015-01-01T00:00:00.000Z
  }

  public class WorksiteChangesJSON {
    public String worksiteId; //string
    public String since; //2015-01-01T00:00:00.000Z
  }
}