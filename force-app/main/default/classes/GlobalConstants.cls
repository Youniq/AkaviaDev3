/**
 * @author: Ahmad Amiri
 * @date: 2020-09-08
 * <br>
 * Global Constant class.<br>
 * Use this class to avoid hard-coding
 */

public class GlobalConstants {
  // HTTP specific
  public static final String URL_ENCODING_SCHEME_DEFAULT = 'UTF-8';
  public static final String HTTP_METHOD_POST = 'POST';
  public static final String HTTP_METHOD_PUT = 'PUT';
  public static final String HTTP_METHOD_GET = 'GET';
  public static final String HTTP_METHOD_DELETE = 'DELETE';
  public static final String HTTP_HEADER_FIELD_NAME_AUTHORIZATION = 'Authorization';
  public static final String HTTP_HEADER_FIELD_AUTHORIZATION_VALUE_OAUTH = 'OAuth ';
  public static final String HTTP_HEADER_FIELD_AUTHORIZATION_VALUE_BEARER = 'Bearer ';
  public static final String HTTP_HEADER_FIELD_AUTHORIZATION_VALUE_BASIC = 'Basic ';
  public static final String HTTP_HEADER_FIELD_NAME_CONTENT_TYPE = 'Content-Type';
  public static final String HTTP_HEADER_FIELD_NAME_ACCEPT = 'Accept';
  public static final String HTTP_HEADER_FIELD_CONTENT_TYPE_VALUE_APPLICATION_URLENCODED = 'application/x-www-form-urlencoded';
  public static final String HTTP_HEADER_FIELD_CONTENT_TYPE_VALUE_APPLICATION_JSON = 'application/json';
  public static final String HTTP_HEADER_VALUE_APPLICATION_HAL_JSON = 'application/hal+json';
  public static String AUTH_HEADER_JSON_AND_UTF8 = 'application/json;charset=UTF-8';
  public static Integer HTTP_RESPONSE_CODE_SUCCESS = 200;
  public static Integer HTTP_RESPONSE_CODE_ERROR_BAD_REQUEST = 400;
  public static Integer HTTP_RESPONSE_CODE_ERROR = 401;
  public static Integer HTTP_RESPONSE_CODE_ERROR_NOT_FOUND = 404;
  public static Integer HTTP_RESPONSE_CODE_INTERNAL_SERVER_ERROR = 500;

  // Bisnode grandtype
  public static String BISNODE_GRANDTYPE_BBC = 'grant_type=client_credentials&scope=bbc';
  public static String BISNODE_GRANDTYPE_BCI_TEST = 'grant_type=client_credentials&scope=bci-test';
  public static String BISNODE_GRANDTYPE_BCI = 'grant_type=client_credentials&scope=bci';

  //RecordType
  public static String RECORDTYPE_EMPLOYER = 'Employer';
  public static String RECORDTYPE_WORKPLACE = 'Workplace';

  //MembershipCategories
  public static final string STUDERANDE = 'Studerande';
  public static final string YRKESVERKSAM = 'Yrkesverksam';

  // Callout Log (Callout__c) Statuses
  public static final string QUEUED = 'Queued';
  public static final string FAILED = 'Failed';
  public static final string OK = 'OK';

  // CalloutLog Types
  public static final String DB_ADD_TO_PORTFOLIO = 'D&B - Add person to portfolio';
  public static final String DB_GET_FROM_PORTFOLIO = 'D&B - Get person from portfolio';
  public static final String DB_DELETE_FROM_PORTFOLIO = 'D&B - Delete person from portfolio';
  public static final String DB_DOWNLOAD_PERSON = 'D&B - Get person info';
  public static final String DB_UPDATE_PERSON_LIST = 'D&B - Update person list';
  public static final String DB_GET_PERSON_CHANGES = 'D&B - Get all person changes';
}