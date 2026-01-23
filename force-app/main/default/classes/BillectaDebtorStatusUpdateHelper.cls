/**
 * @description       :
 * @author            : Malin Nilsson (Stretch Customer AB)
 * @group             :
 * @last modified on  : 2025-07-02
 * @last modified by  : Malin Nilsson (Stretch Customer AB)
 **/
public class BillectaDebtorStatusUpdateHelper {
  @AuraEnabled
  public String Status { get; set; }
  @AuraEnabled
  public String ErrorMessage { get; set; }
  @AuraEnabled
  public String lastUpdated { get; set; }
  @AuraEnabled
  public String icon { get; set; }
  @AuraEnabled
  public Boolean IDExists { get; set; }

  @AuraEnabled
  public static BillectaDebtorStatusUpdateHelper getLastUpdated(
    String recordId
  ) {
    BillectaDebtorStatusUpdateHelper obj = new BillectaDebtorStatusUpdateHelper();
    Account Acc = [
      SELECT Id, PaymentStatusUpdated__c, BillectaID__c
      FROM Account
      WHERE Id = :recordId
    ];

    obj.lastUpdated = String.ValueOf(Acc.PaymentStatusUpdated__c);
    obj.IDExists = Acc.BillectaID__c != null ? true : false;
    if (Acc.PaymentStatusUpdated__c != null) {
      if (DateTime.now().isSameDay(Acc.PaymentStatusUpdated__c)) {
        if (Acc.PaymentStatusUpdated__c.addMinutes(60) > DateTime.now()) {
          obj.icon = 'success';
        } else {
          obj.icon = 'warning';
        }
      } else {
        obj.icon = 'warning';
      }
    } else {
      obj.icon = 'warning';
    }
    return obj;
  }

  @AuraEnabled
  public static BillectaDebtorStatusUpdateHelper getUpdatedInfo(
    String recordId
  ) {
    System.debug('WE ARE LIVE WITH ACCOUNTID : ' + recordId);
    BillectaDebtorStatusUpdateHelper obj = new BillectaDebtorStatusUpdateHelper();

    Account Acc = [
      SELECT
        Id,
        BillectaID__c,
        Balance__c,
        OverdueAmount__c,
        ReminderStatus__c,
        LatestPaymentDate__c,
        PaymentMethod__c,
        DistributionMethod__c,
        AutogiroApprovalStatus__c,
        PaymentStatusUpdated__c
      FROM Account
      WHERE Id = :recordId
    ]; 

    Http http = new Http();
    HttpRequest request = new HttpRequest();
    HttpResponse response = new HttpResponse();

    request = BillectaUtils.initBillectaRequest(request);
    system.debug('REQUEST : ' + request);
    request = BillectaUtils.DebtorPaymentStatus(acc.BillectaId__c, request);
    system.debug('REQUEST : ' + request);

    try {
      system.debug('REQUEST : ' + request);
      response = http.send(request);
    
      if (response.getStatusCode() == 200 || response.getStatusCode() == 201) {
        obj.Status = 'OK';
        BillectaGetDebtorPaymentStatusesParse.DebtorPaymentStatusView jsonResponse = BillectaGetDebtorPaymentStatusesParse.parse(
          response.getBody()
        );

        Acc.Balance__c = jsonResponse.Balance_c;
        Acc.OverdueAmount__c = jsonResponse.OverdueAmount_c;
        if (jsonResponse.ReminderStatus_c != null) {
          Acc.ReminderStatus__c = String.valueOf(jsonResponse.ReminderStatus_c);
        }
        if (
          jsonResponse.LatestPaymentDate_c != null &&
          jsonResponse.LatestPaymentDate_c != ''
        ) {
          system.debug(jsonResponse.LatestPaymentDate_c);
          Acc.LatestPaymentDate__c = Date.valueOf(
            jsonResponse.LatestPaymentDate_c.left(10)
          );
        }
        Acc.PaymentMethod__c = jsonResponse.PaymentMethod_c;
        Acc.DistributionMethod__c = jsonResponse.DistributionMethod_c;
        Acc.AutogiroApprovalStatus__c = jsonResponse.AutogiroApprovalStatus_c;
        Acc.PaymentStatusUpdated__c = System.now();

        try {
          update Acc;
        } catch (Exception e) {
          obj.Status = 'Failed';
          obj.ErrorMessage = e.getMessage();
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
      
        throw new CalloutException(obj.ErrorMessage);
       
      }
     } catch (Exception e) {
      obj.Status = 'Failed';
      obj.ErrorMessage = e.getMessage();

       ApexLog.Error logError = new ApexLog.Error(
          'BillectaDebtorStatusUpdateHelper',
          'getUpdatedInfo',
          true,
          e
        );
        ApexLog.createLogDebug(logError);
    }


    return obj;
  }

  @AuraEnabled
  public static String sendInvoice(Id recordId) {
    List<Callout__c> calloutsScheduled = new List<Callout__c>();
    Account acc = [
      SELECT
        Id,
        BillectaID__c,
        SocialSecurityNumber__c,
        MemberNumber__c,
        MembershipCategory__c,
        FeeCategory__c,
        UnemploymentFundThroughAkavia__c,
        (
          SELECT Id
          FROM MembershipBenefits__r
          WHERE Status__c = 'Aktiv' AND BenefitName__c = 'Inkomstförsäkring'
        )
      FROM Account
      WHERE Id = :recordId
    ];

    Id jobId = System.enqueueJob(new BillectaSendInvoiceAsync(acc));
    System.debug('-----------JOB ID-------------' + jobId);
    calloutsScheduled.add(
      new Callout__c(
        jobId__c = jobId,
        Type__c = 'Billecta - Create Invoice',
        Account__c = acc.ID,
        Status__c = 'Queued'
      )
    );

    //Insert Callout__c records
    if (calloutsScheduled.size() > 0) {
      System.debug('--- Create Callouts ---');
      try {
        insert calloutsScheduled;
      } catch (exception e) {
        System.debug('--- Error inserting Callouts --- ' + calloutsScheduled);
        ApexLog.Error logError = new ApexLog.Error(
          'BillectaInitiateSendDebtor',
          'sendInvoice',
          true,
          e
        );
        ApexLog.createLogDebug(logError);
      }
      System.debug('--- Created Callouts ---' + calloutsScheduled);
      return 'OK';
    } else {
      return 'Failed';
    }
  }

  public static String sendRetroactiveInvoice(
    Id recordId,
    BillectaCreateInvoice retroactiveInvInfo
  ) {
    List<Callout__c> calloutsScheduled = new List<Callout__c>();
    Account acc = [
      SELECT Id, BillectaID__c, SocialSecurityNumber__c, MemberNumber__c
      FROM Account
      WHERE Id = :recordId
    ];

    Id jobId = System.enqueueJob(
      new BillectaSendInvoiceAsync(acc, retroactiveInvInfo)
    );
    System.debug('-----------JOB ID-------------' + jobId);
    calloutsScheduled.add(
      new Callout__c(
        jobId__c = jobId,
        Type__c = '	Billecta - Create Retroactive Invoice',
        Account__c = acc.ID,
        Status__c = 'Queued'
      )
    );

    //Insert Callout__c records
    if (calloutsScheduled.size() > 0) {
      System.debug('--- Create Callouts ---');
      try {
        insert calloutsScheduled;
      } catch (exception e) {
        System.debug('--- Error inserting Callouts --- ' + calloutsScheduled);
        ApexLog.Error logError = new ApexLog.Error(
          'BillectaDebtorStatusUpdateHelper',
          'sendRetroactiveInvoice',
          true,
          e
        );
        ApexLog.createLogDebug(logError);
      }
      System.debug('--- Created Callouts ---' + calloutsScheduled);
      return 'OK';
    } else {
      return 'Failed';
    }
  }

  @AuraEnabled
  public static String SendSMS(Id recordId) {
    String integrationError;
    String returnMsg;

    Account acc = [
      SELECT Id, PersonMobilePhone
      FROM Account
      WHERE Id = :recordId
    ];

    Billecta__c credentials = [
      SELECT Id, Creditor__c
      FROM Billecta__c
    ];

    Http http = new Http();
    HttpRequest request = new HttpRequest();
    HttpResponse response = new HttpResponse();

    Blob body = BillectaEncodeJSON.encodeSMS(acc, credentials.Creditor__c);

    request = BillectaUtils.initBillectaRequest(request);
    request = BillectaUtils.SendSMS(request, body);
    system.debug('REQUEST : ' + request);
    system.debug('REQUEST BODY : ' + body);


    try {
      response = http.send(request);

      if (response.getStatusCode() == 200 || response.getStatusCode() == 201) {
        returnMsg = 'OK';
      } else if (
        response.getStatusCode() != 200 &&
        response.getStatusCode() != 201
      ) {
          throw new CalloutException(response.getBody());
      } 
     } catch (Exception e) {
      ApexLog.Error logError = new ApexLog.Error(
        'BillectaDebtorStatusUpdateHelper',
        'sendSMS',
        true,
        e
      );
      ApexLog.createLogDebug(logError);
      returnMsg = 'Failed';
    }
    return returnMsg;
  }
}