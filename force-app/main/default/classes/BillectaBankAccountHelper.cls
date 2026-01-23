/**TODO**:
 * Lägg till möjlighet att manuellt fylla i clearing och kontonummer
 */
public without sharing class BillectaBankAccountHelper {
  @AuraEnabled
  public String Status { get; set; }
  @AuraEnabled
  public String errorMessage { get; set; }
  @AuraEnabled
  public Account theAccount { get; set; }
  @AuraEnabled
  public List<String> bankAccounts { get; set; }
  @AuraEnabled
  public List<String> paymentMethods { get; set; }
  @AuraEnabled
  public List<String> bankOptionsAG { get; set; }
  @AuraEnabled
  public List<String> bankOptionsEinv { get; set; }
  @AuraEnabled
  public List<String> distributionMethods { get; set; }
  @AuraEnabled
  public String PublicId { get; set; }
  @AuraEnabled
  public String BankIdAutostartToken { get; set; }
  @AuraEnabled
  public String QR { get; set; }

  @AuraEnabled
  public static BillectaBankAccountHelper initData(String recordId) {
    BillectaBankAccountHelper obj = new BillectaBankAccountHelper();

    obj.theAccount = [
      SELECT
        Id,
        BillectaID__c,
        PaymentMethod__c,
        AutogiroBank__c,
        EinvoiceBank__c,
        AG_BankAccountNumber__c,
        AG_BankClearingNumber__c,
        SocialSecurityNumber__c,
        DistributionMethod__c,
        AG_BankIDSignToken__c
      FROM Account
      WHERE ID = :recordId
    ];

    obj.bankOptionsAG = new List<String>();
    Schema.DescribeFieldResult fr = Account.AutogiroBank__c.getDescribe();
    obj.bankOptionsAG = returnOptionListByFieldResult(fr);

    fr = Account.PaymentMethod__c.getDescribe();
    obj.paymentMethods = returnOptionListByFieldResult(fr);

    fr = Account.DistributionMethod__c.getDescribe();
    obj.distributionMethods = returnOptionListByFieldResult(fr);
    if (obj.distributionMethods.contains('Ingen leverans')) {
      obj.distributionMethods.remove(
        obj.distributionMethods.indexOf('Ingen leverans')
      );
    }

    fr = Account.EinvoiceBank__c.getDescribe();
    obj.bankOptionsEinv = returnOptionListByFieldResult(fr);
    obj.BankIdAutostartToken = null;
    obj.Status = null;
    System.debug('*** Object: ' + obj);
    return obj;
  }
  
  @AuraEnabled
  public static BillectaBankAccountHelper savePaymentMethod(
    BillectaBankAccountHelper obj,
    String accountNo
  ) {
    Schema.DescribeFieldResult fr = Account.PaymentMethod__c.getDescribe();
    obj.theAccount.PaymentMethod__c = returnPicklistValueByLabel(
      obj.theAccount.PaymentMethod__c,
      fr
    );

    if (obj.theAccount.PaymentMethod__c == 'AG' && accountNo != null) {
      fr = Account.AutogiroBank__c.getDescribe();
      obj.theAccount.AutogiroBank__c = returnPicklistValueByLabel(
        obj.theAccount.AutogiroBank__c,
        fr
      );
      obj.theAccount.AG_BankClearingNumber__c = accountNo.substringBefore('-');
      obj.theAccount.AG_BankAccountNumber__c = accountNo.substringAfter('-');
      obj.theAccount.DistributionMethod__c = null;
    } else if (obj.theAccount.PaymentMethod__c == 'BG') {
      fr = Account.DistributionMethod__c.getDescribe();
      obj.theAccount.DistributionMethod__c = returnPicklistValueByLabel(
        obj.theAccount.DistributionMethod__c,
        fr
      );
      if (obj.theAccount.DistributionMethod__c == 'E-faktura') {
        fr = Account.EinvoiceBank__c.getDescribe();
        obj.theAccount.EinvoiceBank__c = returnPicklistValueByLabel(
          obj.theAccount.EinvoiceBank__c,
          fr
        );
      } else {
        obj.theAccount.EinvoiceBank__c = null;
      }
      //cleaning old AG details from account before save trigger flow.

    } 
    try {
      update obj.theAccount;
    } catch (Exception e) {
      obj.Status = 'Failed';
      obj.ErrorMessage = 'Something went wrong, please contact customer service.';
    }

    return obj;
  }

  @AuraEnabled
  public static BillectaBankAccountHelper initGetBankAccounts(
    BillectaBankAccountHelper currentObj,
    Boolean otherDevice
  ) {
    BillectaBankAccountHelper obj = currentObj;

    Billecta__c credentials = [
      SELECT Id, Creditor__c
      FROM Billecta__c
    ];

    String formattedSSN =
      obj.theAccount.SocialSecurityNumber__c.left(8) +
      '-' +
      obj.theAccount.SocialSecurityNumber__c.right(4);
    Schema.DescribeFieldResult fr = Account.AutogiroBank__c.getDescribe();
    if (returnPicklistValueByLabel(obj.theAccount.AutogiroBank__c, fr) != null)
      obj.theAccount.AutogiroBank__c = returnPicklistValueByLabel(
        obj.theAccount.AutogiroBank__c,
        fr
      );

    Http http = new Http();
    HttpRequest request = new HttpRequest();
    HttpResponse response = new HttpResponse();

    request = BillectaUtils.initBillectaRequest(request);

    request = BillectaUtils.initGetBankAccounts(
      request,
      obj.theAccount.AutogiroBank__c,
      obj.theAccount.SocialSecurityNumber__c,
      credentials,
      otherDevice
    );

    System.debug('*** Request: ' + request);
    System.debug('*** Bank: ' + obj.theAccount.AutogiroBank__c);
    System.debug('*** SSN: ' + obj.theAccount.SocialSecurityNumber__c);

    try {
      response = http.send(request);
      BillectaBankAccount.CreatedView jsonResponse;

      if (response.getStatusCode() == 200 || response.getStatusCode() == 201) {
        obj.Status = 'Waiting';

        jsonResponse = BillectaBankAccount.parse(response.getBody());
        if (jsonresponse.PublicId != null) {
          obj.PublicId = jsonresponse.PublicId;
          return obj;
        }
      } else if (
        response.getStatusCode() != 200 &&
        response.getStatusCode() != 201
      ) {
        obj.Status = 'Failed';
        obj.errorMessage =
          obj.errorMessage +
          '<--APEX*****' +
          'Billecta' +
          '-->' +
          response.getBody();

        throw new CalloutException(obj.errorMessage);
      }
    } catch (Exception e) {
      obj.Status = 'Failed';
      obj.ErrorMessage = e.getMessage();

      ApexLog.Error logError = new ApexLog.Error(
          'BillectaBankAccountHelper',
          'initGetBankAccounts',
          true,
          e
        );
      ApexLog.createLogDebug(logError);

      return obj;
    }

    return null;
  }
  @AuraEnabled
  public static BillectaBankAccountHelper getBankAccountsStatus(
    BillectaBankAccountHelper obj,
    String PublicId
  ) {

    Http http2 = new Http();
    HttpRequest request2 = new HttpRequest();
    HttpResponse response2 = new HttpResponse();

    request2 = BillectaUtils.initBillectaRequest(request2);

    request2 = BillectaUtils.getBankAccountsStatus(request2, PublicId);

    try {
      response2 = http2.send(request2);
    
      List<String> bankAccounts = new List<String>();
      if (response2.getStatusCode() == 200 || response2.getStatusCode() == 201) {
        BillectaBankAccount.BankAccountRequestView jsonResp = BillectaBankAccount.parseStatus(
          response2.getBody()
        );
        System.debug('**** Json response: ');
        System.debug(jsonResp);
        System.debug(
          '**** BankIdAutostartToken Token: ' + jsonResp.BankIdAutostartToken
        );

        if (jsonResp.Status == 'Failed') {
          obj.Status = jsonResp.Status;
          obj.errorMessage = jsonResp.FailureCode + ' ' + jsonResp.FailureMessage;
        } else if (jsonResp.Status == 'Success') {
          obj.Status = jsonResp.Status;
          if (
            jsonResp.AccountNumbers != null &&
            jsonResp.AccountNumbers.size() > 0
          ) {
            for (
              BillectaBankAccount.BankAccountView ba : jsonResp.AccountNumbers
            ) {
              bankAccounts.add(ba.ClearingNo + '-' + ba.AccountNo);
            }
            obj.bankAccounts = bankAccounts;
          } else {
            System.debug('No accounts were found');
            obj.errorMessage = 'No accounts were found';
          }
        } else if (jsonResp.Status == 'Waiting') {
          obj.Status = jsonResp.Status;
          obj.BankIdAutostartToken = jsonResp.BankIdAutostartToken; // AutoStartToken?
          obj.QR = jsonResp.QR;
          System.debug('QR : ' + jsonResp.QR);
        }
      } else if (
        response2.getStatusCode() != 200 &&
        response2.getStatusCode() != 201
      ) {
        obj.Status = 'Failed';
        obj.errorMessage =
          obj.errorMessage +
          '<--APEX*****' +
          'Billecta' +
          '-->' +
          response2.getBody();
        System.debug(response2.getBody());
        throw new CalloutException(obj.errorMessage);
      }
    } catch (Exception e) {
      obj.Status = 'Failed';
      obj.ErrorMessage = e.getMessage();
      ApexLog.Error logError = new ApexLog.Error(
        'BillectaBankAccountHelper',
        'getBankAccountsStatus',
        true,
        e
      );
      ApexLog.createLogDebug(logError);
    }

    return obj;
  }
  @AuraEnabled
  public static BillectaBankAccountHelper initBankIDSign(
    BillectaBankAccountHelper currentObj
  ) {
    BillectaBankAccountHelper obj = currentObj;
    obj.PublicId = null;

    Billecta__c credentials = [
      SELECT Id, Creditor__c
      FROM Billecta__c
    ];

    String formattedSSN =
      obj.theAccount.SocialSecurityNumber__c.left(8) +
      '-' +
      obj.theAccount.SocialSecurityNumber__c.right(4);

    blob jsonBody = BillectaEncodeJSON.encodeBankIDRequest(
      credentials.Creditor__c,
      formattedSSN
    );

    Http http = new Http();
    HttpRequest request = new HttpRequest();
    HttpResponse response = new HttpResponse();

    request = BillectaUtils.initBillectaRequest(request);
    request = BillectaUtils.initBankIDSign(request, jsonBody);
    

    try {
      System.debug('*** initBankIDSign');
      System.debug('*** Request: ' + request);
      System.debug('*** Request Body: ' + request.getBody());
      System.debug('*** endpoint: ' + request.getEndpoint());
      System.debug('*** method: ' + request.getMethod());

      response = http.send(request);
      BillectaBankIDSign.BankIdSignStatusView jsonResponse;

      if (response.getStatusCode() == 200 || response.getStatusCode() == 201) {
        jsonResponse = BillectaBankIDSign.parse(response.getBody());
        System.debug('*** jsonResponse: ' + jsonResponse);
      } else if (
        response.getStatusCode() != 200 &&
        response.getStatusCode() != 201
      ) {
        obj.Status = 'Failed';
        obj.errorMessage =
          obj.errorMessage +
          '<--APEX*****' +
          'Billecta' +
          '-->' +
          response.getBody();
        system.debug('initBankIDSign Response: ' + response.getBody());
        throw new CalloutException(obj.errorMessage);
      }

      if (jsonresponse?.ReferenceToken != null) {
        obj.PublicId = jsonresponse.ReferenceToken;
        obj.QR = jsonResponse.QR;
        obj.BankIdAutostartToken = jsonResponse.AutoStartToken;
        obj.Status = jsonResponse.Status;
        return obj;
      } else {
        return null;
      }
    } catch (Exception e) {
      obj.Status = 'Failed';
      obj.ErrorMessage = e.getMessage();
      ApexLog.Error logError = new ApexLog.Error(
        'BillectaBankAccountHelper',
        'initBankIDSign',
        true,
        e
      );
      ApexLog.createLogDebug(logError);
    }
    return obj;
  }
  
  @AuraEnabled
  public static BillectaBankAccountHelper getBankIDSignStatus(
    BillectaBankAccountHelper obj,
    String PublicId
  ) {

    Http http2 = new Http();
    HttpRequest request2 = new HttpRequest();
    HttpResponse response2 = new HttpResponse();

    request2 = BillectaUtils.initBillectaRequest(request2);

    request2 = BillectaUtils.getBankIDSignStatus(request2, PublicId);

    try {
      response2 = http2.send(request2);

      if (response2.getStatusCode() == 200 || response2.getStatusCode() == 201) {
        BillectaBankIDSign.BankIdSignStatusView jsonResp = BillectaBankIDSign.parse(
          response2.getBody()
        );
        System.debug('BankIdSignStatusView:  ');
        System.debug('jsonResp: ' + jsonResp);
        System.debug('jsonResp Status: ' + jsonResp.Status);

        if (jsonResp.Status == 'Error' || jsonResp.Status == 'NoClient') {
          obj.Status = 'Failed';
          obj.errorMessage = jsonResp.Status + ' ' + jsonResp.HintCode;
        } else if (jsonResp.Status == 'Complete') {
          obj.Status = jsonResp.Status;
          obj.theAccount.AG_BankIDSignToken__c = PublicId;
        } else {
          obj.Status = jsonResp.Status;
          obj.QR = jsonResp.QR;
          obj.BankIdAutostartToken = jsonResp.AutoStartToken;
        }
      } else if (
        response2.getStatusCode() != 200 &&
        response2.getStatusCode() != 201
      ) {
        obj.Status = 'Failed';
        obj.errorMessage =
          obj.errorMessage +
          '<--APEX*****' +
          'Billecta' +
          '-->' +
          response2.getBody();
       throw new CalloutException(obj.errorMessage);
      } 
    } catch (Exception e) {
      obj.Status = 'Failed';
      obj.ErrorMessage = e.getMessage();
      ApexLog.Error logError = new ApexLog.Error(
        'BillectaBankAccountHelper',
        'getBankIDSignStatus',
        true,
       e
      );
      ApexLog.createLogDebug(logError);
    }

    return obj;
  }

  public static String returnPicklistValueByLabel(
    String label,
    Schema.DescribeFieldResult fieldResult
  ) {
    List<Schema.PicklistEntry> ple = fieldResult.getPicklistValues();
    String value;

    for (Schema.PicklistEntry f : ple) {
      if (f.getLabel() == label) {
        value = f.getValue();
        break;
      }
    }
    return value;
  }
  public static List<String> returnOptionListByFieldResult(
    Schema.DescribeFieldResult fieldResult
  ) {
    List<Schema.PicklistEntry> ple = fieldResult.getPicklistValues();
    List<String> optionList = new List<String>();
    optionList.add('Välj...');

    for (Schema.PicklistEntry f : ple) {
      system.debug('f : ' + f);
      optionList.add(f.getLabel());
    }
    return optionList;
  }
}