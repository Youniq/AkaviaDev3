/**
 * @description       :
 * @author            : Malin Nilsson (Stretch Customer AB)
 * @group             :
 * @last modified on  : 2024-12-16
 * @last modified by  : Malin Nilsson (Stretch Customer AB)
 **/
public class BillectaMultipleInvoicesActions {
  ApexPages.StandardSetController setCon;

  public BillectaMultipleInvoicesActions(
    ApexPages.StandardSetController controller
  ) {
    setCon = controller;
  }

  public pageReference CancelInvoices() {
    Billecta__c credentials = [
      SELECT Id, Creditor__c
      FROM Billecta__c
    ];
    List<Account> selectedAccs = (Account[]) setCon.getSelected();
    Map<Id, Account> idToAccMap = new Map<Id, Account>(selectedAccs);
    List<Invoice__c> invoicesToCancel = [
      SELECT Id, BillectaID__c
      FROM Invoice__c
      WHERE
        BillectaID__c != NULL
        AND PaymentStatus__c != 'Makulerad'
        AND PaymentStatus__c != 'Betald'
        AND Person__c IN :idToAccMap.keySet()
    ];
    String jsonString =
      '{"CreditorPublicId": "' +
      credentials.Creditor__c +
      '", "ActionPublicIds": [';
    Integer size = invoicesToCancel.size();
    Integer count = 1;
    for (Invoice__c inv : invoicesToCancel) {
      String partialJsonString = '"' + inv.BillectaID__c + '"';
      if (count == size) {
        jsonString = jsonString + partialJsonString + ']}';
      } else {
        jsonString = jsonString + partialJsonString + ',';
      }

      // This will be updated if cancellation is succesful in Billecta
      inv.PaymentStatus__c = 'Makulerad';

      count++;
    }
    System.debug('json= ' + jsonString);

    Http http = new Http();
    HttpRequest request = new HttpRequest();
    HttpResponse response = new HttpResponse();

    Blob body = Blob.valueOf(jsonString);

    request = BillectaUtils.initBillectaRequest(request);
    system.debug('REQUEST : ' + request);
    request = BillectaUtils.CancelMultipleInvoices(request, body);
    system.debug('REQUEST : ' + request);

    try {
      system.debug('REQUEST : ' + request);
      response = http.send(request);
    } catch (Exception e) {
      system.debug('ERROR Sendin request : ' + e.getMessage());
      ApexLog.Error logError = new ApexLog.Error(
        'BillectaMultipleInvoicesActions',
        'CancelInvoices',
        true,
        e
      );
      ApexLog.createLogDebug(logError);
      ApexPages.addmessage(
        new ApexPages.message(ApexPages.severity.ERROR, e.getMessage())
      );
      return null;
    }

    String status;
    String integrationError;
    if (response.getStatusCode() == 200 || response.getStatusCode() == 201) {
      system.debug('Everything is FINE : ' + response.getBody());
      status = 'OK';
      ApexPages.addmessage(
        new ApexPages.message(ApexPages.severity.CONFIRM, 'OK')
      );

      // Save new PaymentStatus__c value to db.
      update invoicesToCancel;
    } else if (
      response.getStatusCode() != 200 &&
      response.getStatusCode() != 201
    ) {
      status = 'Failed';
      integrationError = 'Billecta' + '-->' + response.getBody();
      system.debug('ERROR Sendin request : ' + integrationError);
      ApexLog.Information logError = new ApexLog.Information(
        'BillectaMultipleInvoicesActions',
        'CancelInvoices',
        true,
        integrationError
      );
      ApexLog.createLogDebug(logError);
      ApexPages.addmessage(
        new ApexPages.message(ApexPages.severity.ERROR, integrationError)
      );
    }

    Id accId;
    if (idToAccMap.size() == 1) {
      accId = new List<Id>(idToAccMap.keySet())[0];
    }
    // Create callout log for the request
    Callout__c currCallout = new Callout__c(
      Type__c = 'Billecta - Cancel Invoices',
      Account__c = accId, // will contain value in case only one account is processed.
      Status__c = status,
      Code__c = String.valueOf(response.getStatusCode()),
      Path__c = request.getEndpoint(),
      Request__c = request.getBody(),
      Response__c = response.getBody(),
      ErrorLog__c = integrationError
    );

    try {
      insert currCallout;
    } catch (Exception e) {
      System.debug(LoggingLevel.ERROR, e.getMessage());
    }

    return null;
  }

  public pageReference CreateInvoices() {
    Billecta__c credentials = [
      SELECT Id, Creditor__c
      FROM Billecta__c
    ];
    List<Account> selectedAccs = (Account[]) setCon.getSelected();

    Map<Id, Account> incomeInsurance = new Map<Id, Account>(
      [
        SELECT
          Id,
          (
            SELECT Id
            FROM MembershipBenefits__r
            WHERE Status__c = 'Aktiv' AND BenefitName__c = 'Inkomstförsäkring'
          )
        FROM Account
        WHERE Id IN :selectedAccs
      ]
    );

    String json = '[';
    Integer size = selectedAccs.size();
    Integer count = 1;
    for (Account acc : selectedAccs) {
      Boolean hasActiveIncomeInsurance = false;
      if (incomeInsurance.get(acc.Id).MembershipBenefits__r.size() > 0) {
        hasActiveIncomeInsurance = true;
      }
      blob partialJson = BillectaEncodeJSON.encodeAkaviaInvoiceActionView(
        acc,
        hasActiveIncomeInsurance,
        credentials.Creditor__c
      );
      if (count == size) {
        json = json + partialJson.toString() + ']';
      } else {
        json = json + partialJson.toString() + ',';
      }

      count++;
    }
    System.debug('json= ' + json);

    Http http = new Http();
    HttpRequest request = new HttpRequest();
    HttpResponse response = new HttpResponse();

    Blob body = Blob.valueOf(json);

    request = BillectaUtils.initBillectaRequest(request);
    system.debug('REQUEST : ' + request);
    request = BillectaUtils.CreateMultipleInvoices(
      request,
      body,
      credentials.Creditor__c
    );
    system.debug('REQUEST : ' + request);

    try {
      system.debug('REQUEST : ' + request);
      response = http.send(request);
    } catch (Exception e) {
      system.debug('ERROR Sendin request : ' + e.getMessage());
      ApexLog.Error logError = new ApexLog.Error(
        'BillectaMultipleInvoicesActions',
        'CreateInvoices',
        true,
        e
      );
      ApexLog.createLogDebug(logError);
      ApexPages.addmessage(
        new ApexPages.message(ApexPages.severity.ERROR, e.getMessage())
      );
      return null;
    }

    String status;
    String integrationError;

    if (response.getStatusCode() == 200 || response.getStatusCode() == 201) {
      system.debug('Everything is FINE : ' + response.getBody());
      status = 'OK';
      ApexPages.addmessage(
        new ApexPages.message(ApexPages.severity.CONFIRM, 'OK')
      );
    } else if (
      response.getStatusCode() != 200 &&
      response.getStatusCode() != 201
    ) {
      status = 'Failed';
      integrationError = 'Billecta' + '-->' + response.getBody();
      system.debug('ERROR Sendin request : ' + integrationError);
      ApexLog.Information logError = new ApexLog.Information(
        'BillectaMultipleInvoicesActions',
        'CreateInvoices',
        true,
        integrationError
      );
      ApexLog.createLogDebug(logError);
      ApexPages.addmessage(
        new ApexPages.message(ApexPages.severity.ERROR, integrationError)
      );
    }

    Id accId;
    if (selectedAccs.size() == 1) {
      accId = selectedAccs[0].Id;
    }

    // Create callout log for the request
    Callout__c currCallout = new Callout__c(
      Type__c = 'Billecta - Create Invoice',
      Account__c = accId, // will contain value in case only one account is processed.
      Status__c = status,
      Code__c = String.valueOf(response.getStatusCode()),
      Path__c = request.getEndpoint(),
      Request__c = request.getBody(),
      Response__c = response.getBody(),
      ErrorLog__c = integrationError
    );

    try {
      insert currCallout;
    } catch (Exception e) {
      System.debug(LoggingLevel.ERROR, e.getMessage());
    }

    return null;
  }

  public pageReference ReturnToAccounts() {
    PageReference pageref = new PageReference(
      '/lightning/o/Account/list?filterName=Recent'
    );

    return pageRef;
  }
}