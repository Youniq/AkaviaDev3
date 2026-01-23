/*
 * CreditorPublicID Multisoft : 4d9023ee-8d43-4e61-a6fc-96cce27cbefe
 * CreditorPublicID (Jennys låda) Akavia Test : 0bf190a5-eb29-4abc-b4ae-e7af3336f8dc
 *
 */

public class BillectaUtils {


    public static String getBillectaNamedCredential() {
      String namedCredential;
      String environment = GenericUtils.getCurrEnvironment();

      switch on environment.toUpperCase() {
        when 'DEV'  {
          namedCredential = 'callout:Billecta_Dev';
        }
        when 'UAT'  {
          namedCredential = 'callout:Billecta_UAT';
        }
        when 'PROD' {
            namedCredential = 'callout:Billecta_Prod';
        }
        when else {
          throw new AuraHandledException('Unknown environment');
        }
      }
      System.debug(LoggingLevel.DEBUG, 'Billecta named credential to use: ' + namedCredential);
      return namedCredential;
    }

  public static httpRequest initBillectaRequest(
    httpRequest request
  ) {
    request.setHeader(
      GlobalConstants.HTTP_HEADER_FIELD_NAME_CONTENT_TYPE,
      GlobalConstants.AUTH_HEADER_JSON_AND_UTF8
    );

    request.setHeader(
      GlobalConstants.HTTP_HEADER_FIELD_NAME_ACCEPT,
      GlobalConstants.AUTH_HEADER_JSON_AND_UTF8
    );
    request.setEndpoint(getBillectaNamedCredential());
    request.setTimeout(120000);

    return request;
  }

  //******SINGEL INVOICE ACTIONS *******/

  public static httpRequest CreateInvoice(httpRequest req, Blob body) {
    req.setEndpoint(req.getEndpoint() + '/v1/akavia/createinvoice');
    req.setMethod(GlobalConstants.HTTP_METHOD_POST);
    req.setBodyAsBlob(body);

    return req;
  }

  public static httpRequest InvoiceInformation(String guId, httpRequest req) {
    req.setEndpoint(
      req.getEndpoint() +
      '/v1/akavia/InvoiceActionStatus?id=' +
      guId
    );
    req.setMethod(GlobalConstants.HTTP_METHOD_GET);

    return req;
  }

  public static httpRequest CancelInvoice(String guId, httpRequest req) {
    req.setEndpoint(req.getEndpoint() + '/v1/akavia/CancelInvoice?id=' + guId);
    req.setMethod(GlobalConstants.HTTP_METHOD_POST);
    req.setHeader('Content-length', '0');

    return req;
  }

  public static httpRequest PauseInvoice(httpRequest req, String guId) {
    req.setEndpoint(req.getEndpoint() + '/v1/invoice/pause/' + guId);
    req.setMethod(GlobalConstants.HTTP_METHOD_PUT);
    req.setHeader('Content-length', '0');

    return req;
  }

  public static httpRequest ResumeInvoice(httpRequest req, String guId) {
    req.setEndpoint(req.getEndpoint() + '/v1/invoice/resume/' + guId);
    req.setMethod(GlobalConstants.HTTP_METHOD_PUT);
    req.setHeader('Content-length', '0');

    return req;
  }

  public static httpRequest SwishPaymentRequest(
    httpRequest req,
    String invId,
    String phoneNo
  ) {
    req.setEndpoint(
      req.getEndpoint() +
      '/v1/payments/swish/' +
      invId +
      '?phone=' +
      phoneNo
    );
    req.setMethod(GlobalConstants.HTTP_METHOD_POST);
    req.setHeader('Content-length', '0');

    return req;
  }

  public static httpRequest SwishPaymentStatus(httpRequest req, String invId) {
    req.setEndpoint(req.getEndpoint() + '/v1/payments/swish/' + invId);
    req.setMethod(GlobalConstants.HTTP_METHOD_GET);
    req.setHeader('Content-length', '0');

    return req;
  }

  //******MASS INVOICE ACTIONS *******/

  public static httpRequest CreateMultipleInvoices(
    httpRequest req,
    Blob body,
    String guId
  ) {
    req.setEndpoint(req.getEndpoint() + '/v1/akavia/createinvoices/' + guId);
    req.setMethod(GlobalConstants.HTTP_METHOD_POST);
    req.setBodyAsBlob(body);

    return req;
  }
  public static httpRequest CancelMultipleInvoices(httpRequest req, Blob body) {
    req.setEndpoint(req.getEndpoint() + '/v1/akavia/CancelInvoices');
    req.setMethod(GlobalConstants.HTTP_METHOD_POST);
    req.setBodyAsBlob(body);

    return req;
  }

  //******SINGEL DEBTOR ACTIONS *******/

  public static httpRequest CreateDebtor(httpRequest req, Blob body) {
    req.setEndpoint(req.getEndpoint() + '/v1/debtors/debtor');
    req.setMethod(GlobalConstants.HTTP_METHOD_POST);
    req.setBodyAsBlob(body);

    return req;
  }

  public static httpRequest UpdateDebtor(httpRequest req, Blob body) {
    req.setEndpoint(req.getEndpoint() + '/v1/debtors/debtor');
    req.setMethod(GlobalConstants.HTTP_METHOD_PUT);
    req.setBodyAsBlob(body);

    return req;
  }

    public static httpRequest DeleteDebtor(httpRequest req, String debtorId) {
    req.setEndpoint(req.getEndpoint() + '/v1/debtors/debtor/' + debtorId);
    req.setMethod(GlobalConstants.HTTP_METHOD_DELETE);

    return req;
  }

  public static httpRequest GetDebtor(httpRequest req, String debtorId) {
    req.setEndpoint(req.getEndpoint() + '/v1/debtors/debtor/' + debtorId);
    req.setMethod(GlobalConstants.HTTP_METHOD_GET);

    return req;
  }

  public static httpRequest DebtorPaymentStatus(String guId, httpRequest req) {
    String encodedGuid = EncodingUtil.urlEncode('{' + guId +'}', 'UTF-8');

    req.setEndpoint(
      req.getEndpoint() +
      '/v1/akavia/DebtorPaymentStatus?id=' + encodedGuid);
    req.setMethod(GlobalConstants.HTTP_METHOD_GET);
    return req;
  }

  public static httpRequest SendSMS(httpRequest req, Blob body) {
    req.setEndpoint(req.getEndpoint() + '/v1/delivery/sms');
    req.setMethod(GlobalConstants.HTTP_METHOD_POST);
    req.setBodyAsBlob(body);

    return req;
  }

  public static httpRequest initGetBankAccounts(
    httpRequest req,
    String bank,
    String SSN,
    Billecta__c cred,
    Boolean otherDevice
  ) {
    req.setEndpoint(
      req.getEndpoint() +
      '/v1/bank/accounts/' +
      cred.Creditor__c +
      '?bank=' +
      bank +
      '&ssn=' +
      SSN +
      '&other_device=' +
      otherDevice
    );

    req.setMethod(GlobalConstants.HTTP_METHOD_POST);
    req.setHeader('Content-length', '0'); // must define this header, else getting error from Billecta

    return req;
  }

  public static httpRequest getBankAccountsStatus(
    httpRequest req,
    String publicId
  ) {
    req.setEndpoint(req.getEndpoint() + '/v1/bank/accounts/' + publicId);
    req.setMethod(GlobalConstants.HTTP_METHOD_GET);
    return req;
  }

  public static httpRequest initBankIdSign(
    httpRequest req,
    blob body
  ) {
    req.setEndpoint(req.getEndpoint() + '/v1/bankid/sign');
    req.setMethod(GlobalConstants.HTTP_METHOD_PUT);
    req.setBodyAsBlob(body);
    //req.setHeader('Content-length', '0'); - Should not be set, causing Script-thrown exception 

    return req;
  }

  public static httpRequest getBankIDSignStatus(
    httpRequest req,
    String publicId
  ) {
    req.setEndpoint(req.getEndpoint() + '/v1/bankid/sign/' + publicId);
    req.setMethod(GlobalConstants.HTTP_METHOD_GET);

    return req;
  }

  public static httpRequest initBankIdAuthentication(
    httpRequest req,
    blob body
  ) {
    req.setEndpoint(req.getEndpoint() + '/v1/bankid/authentication');
    req.setMethod(GlobalConstants.HTTP_METHOD_PUT);
    req.setBodyAsBlob(body);
    //req.setHeader('Content-length', '0');

    return req;
  }

  public static httpRequest getBankIDAuthenticationStatus(
    httpRequest req,
    String referenceToken
  ) {
    req.setEndpoint(
      req.getEndpoint() +
      '/v1/bankid/authentication/' +
      referenceToken
    );
    req.setMethod(GlobalConstants.HTTP_METHOD_GET);

    return req;
  }

  //******MASS DEBTOR ACTIONS *******/

  public static httpRequest DebtorPaymentStatuses(
    String guId,
    String fromDateTime,
    httpRequest req
  ) {
    req.setEndpoint(
      req.getEndpoint() +
      '/v1/akavia/DebtorPaymentStatuses?id=' +
      guId +
      '&from=' +
      fromDateTime
    );
    req.setMethod(GlobalConstants.HTTP_METHOD_GET);

    return req;
  }

  
  /**
  * @description Check if we should send default delivery method Kivra
  * @author Malin Nilsson (Stretch Customer AB) | 2025-06-17 
  * @param acc - Account
  * @return boolean - true if we should send default delivery method Kivra, false otherwise
  **/
  public static boolean isDefaultDeliveryMethodKivra(Account acc) {
    if(acc.DistributionMethod__c == 'Post' && !acc.IsDistributionPostalPaperOnly__c && acc.PaymentMethod__c == 'BG') {
      return true;
    }
    return false;
  }


}