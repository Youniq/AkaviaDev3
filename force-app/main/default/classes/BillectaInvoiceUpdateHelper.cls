/*
 * Author @ Jenny Blomberg
 * Helper class used by lighnting component "BillectaInvoiceUpdate"
 */
public class BillectaInvoiceUpdateHelper {
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
  public Boolean Canceled { get; set; }

  @AuraEnabled
  public static BillectaInvoiceUpdateHelper getLastUpdated(String recordId) {
    BillectaInvoiceUpdateHelper obj = new BillectaInvoiceUpdateHelper();
    Invoice__c inv = [
      SELECT Id, UpdatedFromBillecta__c, BillectaID__c, PaymentStatus__c
      FROM Invoice__c
      WHERE Id = :recordId
    ];

    obj.lastUpdated = String.ValueOf(inv.UpdatedFromBillecta__c);
    obj.IDExists = inv.BillectaID__c != null ? true : false;
    obj.Canceled = inv.PaymentStatus__c == 'Makulerad' ? true : false;

    if (inv.UpdatedFromBillecta__c != null) {
      if (DateTime.now().isSameDay(inv.UpdatedFromBillecta__c)) {
        if (inv.UpdatedFromBillecta__c.addMinutes(60) > DateTime.now()) {
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
  public static BillectaInvoiceUpdateHelper getUpdatedInfo(String recordId) {
    System.debug('WE ARE LIVE WITH INVOICEID : ' + recordId);
    BillectaInvoiceUpdateHelper obj = new BillectaInvoiceUpdateHelper();

    Invoice__c inv = [
      SELECT
        Id,
        BillectaID__c,
        FeeCategory__c,
        Amount__c,
        PaymentStatus__c,
        DistributionMethod__c,
        PaymentMethod__c,
        InvoiceDate__c,
        InvoiceLink__c,
        Name,
        InvoiceStatus__c,
        ExpirationDate__c,
        PaymentDate__c,
        MembershipCategory__c,
        OCR__c,
        Person__c,
        Reminder1__c,
        Reminder2__c,
        Reminder3__c,
        RemainingAmount__c,
        UpdatedFromBillecta__c
      FROM Invoice__c
      WHERE Id = :recordId
    ];

    Http http = new Http();
    HttpRequest request = new HttpRequest();
    HttpResponse response = new HttpResponse();

    request = BillectaUtils.initBillectaRequest(request);
    system.debug('REQUEST : ' + request);
    request = BillectaUtils.InvoiceInformation(inv.BillectaId__c, request);
    system.debug('REQUEST : ' + request);

    try {
      system.debug('REQUEST : ' + request);
      response = http.send(request);
    

      if (response.getStatusCode() == 200 || response.getStatusCode() == 201) {
        obj.Status = 'OK';
        BillectaGetInvoiceStatusesParse.InvoiceActionStatusView jsonResponse = BillectaGetInvoiceStatusesParse.parse(
          response.getBody()
        );
        System.debug('Inv InvoiceActionStatusView:');
        System.debug(jsonResponse);

        if (jsonResponse != null) {
          system.debug(jsonResponse.PaymentStatus_c);
          // We're saving FeeCategory and MembershipCategory to the invoice earlier while sending it to Billecta, so no need to set it again.
          //inv.FeeCategory__c = jsonResponse.FeeCategory_c;
          //inv.MembershipCategory__c = jsonResponse.MembershipCategory_c;
          inv.Amount__c = jsonResponse.Amount_c;
          inv.AmountAkassa__c = jsonResponse.AmountAkassa;
          inv.DistributionMethod__c = jsonResponse.DistributionMethod_c;
          inv.PaymentMethod__c = jsonResponse.PaymentMethod_c;
          inv.PaymentStatus__c = inv.PaymentStatus__c != 'Makulerad'
            ? jsonResponse.PaymentStatus_c
            : 'Makulerad';
          inv.InvoiceDate__c = jsonResponse.InvoiceDate_c != ''
            ? Date.valueOf(jsonResponse.InvoiceDate_c)
            : null;
          inv.InvoiceLink__c = jsonResponse.InvoiceLink_c;
          inv.Name = jsonResponse.Name;
          inv.InvoiceStatus__c = jsonResponse.InvoiceStatus_c;
          inv.InvoicePeriodStart__c = String.isNotBlank(
              jsonResponse.InvoicePeriodStart_c
            )
            ? Date.valueOf(jsonResponse.InvoicePeriodStart_c)
            : null;
          inv.InvoicePeriodEnd__c = String.isNotBlank(
              jsonResponse.InvoicePeriodEnd_c
            )
            ? Date.valueOf(jsonResponse.InvoicePeriodEnd_c)
            : null;
          inv.ExpirationDate__c = jsonResponse.ExpirationDate_c != ''
            ? Date.valueOf(jsonResponse.ExpirationDate_c)
            : null;
          inv.PaymentDate__c = jsonResponse.PaymentDate_c != ''
            ? Date.valueOf(jsonResponse.PaymentDate_c)
            : null;
          inv.OCR__c = jsonResponse.OCR_c;
          inv.Reminder1__c = jsonResponse.Reminder1_c;
          inv.Reminder2__c = jsonResponse.Reminder2_c;
          inv.Reminder3__c = jsonResponse.Reminder3_c;
          inv.RemainingAmount__c = jsonResponse.RemainingAmount_c;
          inv.UpdatedFromBillecta__c = system.now();
        }

        try {
          update inv;
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
  public static BillectaInvoiceUpdateHelper cancelInvoice(String recordId) {
    System.debug('WE ARE LIVE WITH INVOICEID : ' + recordId);
    BillectaInvoiceUpdateHelper obj = new BillectaInvoiceUpdateHelper();

    Invoice__c inv = [
      SELECT Id, BillectaID__c, InvoiceStatus__c, Person__c
      FROM Invoice__c
      WHERE Id = :recordId
    ];

    Http http = new Http();
    HttpRequest request = new HttpRequest();
    HttpResponse response = new HttpResponse();

    request = BillectaUtils.initBillectaRequest(request);
    system.debug('REQUEST : ' + request);
    request = BillectaUtils.CancelInvoice(inv.BillectaId__c, request);
    system.debug('REQUEST : ' + request);

    try {
      system.debug('REQUEST : ' + request);
      response = http.send(request);
  
    if (response.getStatusCode() == 200 || response.getStatusCode() == 201) {
      obj.Status = 'OK';

      inv.PaymentStatus__c = 'Makulerad';
      inv.UpdatedFromBillecta__c = system.now();
      try {
        update inv;
      } catch (Exception e) {
        obj.Status = 'Failed';
        obj.ErrorMessage = e.getMessage();
        ApexLog.Information logError = new ApexLog.Information(
          'BillectaDebtorStatusUpdateHelper',
          'CancelInvoice',
          true,
          obj.errorMessage
        );
        ApexLog.createLogDebug(logError);
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

        system.debug(response.getBody());
      throw new CalloutException(obj.errorMessage);     
    }
    } catch (Exception e) {
      obj.Status = 'Failed';
      obj.ErrorMessage = e.getMessage();

      ApexLog.Error logError = new ApexLog.Error(
        'BillectaDebtorStatusUpdateHelper',
        'CancelInvoice',
        true,
        e
      );
      ApexLog.createLogDebug(logError);
    }

    // Create callout log for the request
    Callout__c currCallout = new Callout__c(
      Type__c = 'Billecta - Cancel Invoice',
      Account__c = inv.person__c,
      Status__c = obj.Status == 'OK' ? 'OK' : 'Failed',
      Code__c = String.valueOf(response.getStatusCode()),
      Path__c = request.getEndpoint(),
      Request__c = request.getBody(),
      Response__c = response.getBody(),
      ErrorLog__c = obj.errorMessage
    );

    try {
      insert currCallout;
    } catch (Exception e) {
      System.debug(LoggingLevel.ERROR, e.getMessage());
    }

    return obj;
  }

  @AuraEnabled
  public static BillectaInvoiceUpdateHelper initSwishPayment(String recordId) {
    System.debug('WE ARE LIVE WITH INVOICEID : ' + recordId);
    BillectaInvoiceUpdateHelper obj = new BillectaInvoiceUpdateHelper();

    Invoice__c inv = [
      SELECT Id, BillectaID__c, InvoiceStatus__c, Swish_Phone__c
      FROM Invoice__c
      WHERE Id = :recordId
    ];

    Http http = new Http();
    HttpRequest request = new HttpRequest();
    HttpResponse response = new HttpResponse();

    request = BillectaUtils.initBillectaRequest(request);
    system.debug('REQUEST : ' + request);
    request = BillectaUtils.SwishPaymentRequest(
      request,
      inv.BillectaID__c,
      inv.Swish_Phone__c
    );
    system.debug('REQUEST : ' + request);

    try {
      system.debug('SENDING REQUEST : ' + request);
      response = http.send(request);
    

      if (response.getStatusCode() == 200 || response.getStatusCode() == 201) {
        obj.Status = 'Waiting';
        BillectaSwish.CreatedView jsonResponse = BillectaSwish.parse(
          response.getBody()
        );

        if (!Test.isRunningTest() && jsonresponse.PublicId != null) {
          obj = getSwishRequestStatus(obj, jsonresponse.PublicId);
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
        system.debug(response.getBody());
        throw new CalloutException(obj.ErrorMessage);
      }
    } catch (Exception e) {
      obj.Status = 'Failed';
      obj.ErrorMessage = e.getMessage();

       ApexLog.Error logError = new ApexLog.Error(
          'BillectaInvoiceUpdateHelper',
          'initSwishPayment',
          true,
          e
        );
        ApexLog.createLogDebug(logError);
    }

    return obj;
  }

  public static BillectaInvoiceUpdateHelper getSwishRequestStatus(
    BillectaInvoiceUpdateHelper obj,
    String PublicId
  ) {
    Http http2 = new Http();
    HttpRequest request2 = new HttpRequest();
    HttpResponse response2 = new HttpResponse();

    request2 = BillectaUtils.initBillectaRequest(request2);
    system.debug('REQUEST2 : ' + request2);
    request2 = BillectaUtils.SwishPaymentStatus(request2, PublicId);
    system.debug('REQUEST2 : ' + request2);

    DateTime startTime = System.now();
    while (
      obj.Status == 'Waiting' && (System.now() < startTime.addMinutes(2))
    ) {
      Integer lastCallout = System.Now().millisecond();
      if (!Test.isRunningTest()) {
        while (System.Now().millisecond() < lastCallout + 1000) {
        }
      }

      try {
        system.debug('SENDING REQUEST2 : ' + request2);
        response2 = http2.send(request2);
       if (
          response2.getStatusCode() == 200 ||
          response2.getStatusCode() == 201
        ) {
          BillectaSwish.SwishPaymentStatusView jsonResp = BillectaSwish.parseStatus(
            response2.getBody()
          );
          if (jsonResp.Status != 'Created') {
            obj.Status = jsonResp.Status;
            if (obj.Status != 'Paid') {
              obj.Status = 'Failed';
              obj.errorMessage = jsonResp.Status;
            }
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
          system.debug(response2.getBody());
          throw new CalloutException(obj.ErrorMessage);
        }
      }
      catch (Exception e) {
        obj.Status = 'Failed';
        obj.ErrorMessage = e.getMessage();
        ApexLog.Error logError = new ApexLog.Error(
          'BillectaInvoiceUpdateHelper',
          'getSwishRequestStatus',
          true,
         e
        );
        ApexLog.createLogDebug(logError);
      }
    }
    return obj;
  }

}