/*******************************************************************
 * @author: Ahmad Amiri
 * @date: 2020-09-08
 * @description: Class to easily consume an external REST web service
 ********************************************************************/

public with sharing class GenericRestClient {
  // Http objects used in this class
  private HttpRequest httpRequest = new HttpRequest();
  private Http http = new Http();
  private HTTPResponse httpResponse;

  private String serviceURL; // The base URL to the web server
  private String service; // The service to use. I.e., "function" or "method"
  private String btCharset = GlobalConstants.URL_ENCODING_SCHEME_DEFAULT;
  private String request; // Request to send
  private String lastResponse; // Last response given
  private String namedCredential; //Named Credential stored in SF

  /* public GenericRestClient(String serviceURL) {
    this.serviceURL = serviceURL;
    httpRequest.setMethod(GlobalConstants.HTTP_METHOD_POST);
  }
*/
  public GenericRestClient() {
  }

  /*public String getRequest() {
    return request;
  }
  
  public String getHeader(String key) {
    return httpRequest.getHeader(key);
  }

  public void setJSONBody(String s) {
    request = s;
  }

  public String getJSONBody() {
    return request;
  }

  public void setBinaryBody(Blob body) {
    httpRequest.setBodyAsBlob(body);
  }
  */

  public void setHeader(String header, String value) {
    httpRequest.setHeader(header, value);
  }

  public void startNewRequest(String service) {
    this.service = service;
    request = '';
  }

  public void addParam(String attribute, String value) {
    request += generateKeyValuePair(request, attribute, value);
  }

  //
  public void setBody(String body) {
    httpRequest.setBody(body);
  }

  public void setResponse(HttpResponse response) {
    this.httpResponse = response;
  }
  public void setMethod(String method) {
    if (method.equals('GET') || method.equals('POST')) {
      httpRequest.setMethod(method);
    }
  }

  public void setTimeout(Integer seconds) {
    httpRequest.setTimeout(seconds * 1000);
  }

  /****************************************************************
   * @author: Ahmad Amiri
   * @date: 2020-09-08
   * @param: currentQueryStr<br>
   * @param: key<br>
   * @param: value<br>
   * @return: String Key = Value<br>
   * @description: Generates a key value pair string.If the current query string is non-empty, include separator<br>
   *****************************************************************/
  public String generateKeyValuePair(
    String currentQueryStr,
    String key,
    String value
  ) {
    system.debug('generateKeyValuePair> key=' + key + ', value=' + value);

    // Ensure that everything has content
    if (currentQueryStr == null || key == null || value == null)
      return '';

    key = Encodingutil.urlEncode(key, btCharset);
    value = Encodingutil.urlEncode(value, btCharset).replaceAll('\\+', '%20');

    System.debug(
      'generateKeyValuePair: encoded: key=' +
      key +
      ', value=' +
      value
    );

    // Create
    if (currentQueryStr.length() > 0) {
      return '&' + key + '=' + value;
    } else {
      return '?' + key + '=' + value;
    }
  }

  /****************************************************************
   * @author: Ahmad Amiri
   * @date: 2020-09-08
   * @param: namedCredential
   * @return: HttpRequest <br>
   * @description: The method creates Get httpRequest with Named Credential <br>
   *****************************************************************/
  public HttpRequest createReqWithNamedCredGet(String url) {
    httpRequest.setMethod(GlobalConstants.HTTP_METHOD_GET);
    httpRequest.setEndpoint(url + service + request);

    system.debug('url + service + request=' + url + service + request);

    return httpRequest;
  }
}