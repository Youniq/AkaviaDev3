/*******************************************************************
* @author: Jenny Blomberg
* @date: 2022-05-16
* @description: This class is necessary since we want to do a callout to Billecta to Cancel Invoices 
* at the end of the transaction when expelling members from APEX class "ExpelAccountsHandler". Since we have 
* alot of DMLs happening in that transaction before performing the callout we need to handle it async. 
* 
* @Jira Tickets : ACF-204, ACF-205

********************************************************************/
public class BillectaCancelInvociesQueuable implements Queueable, Database.AllowsCallouts {
  private List<Invoice__c> invoicesToCancel { get; set; }

  public BillectaCancelInvociesQueuable(List<Invoice__c> invoices) {
    this.invoicesToCancel = invoices;
  }

  public void execute(QueueableContext context) {
    Id jobId = context.getJobId();
    Callout__c callout = [
      SELECT
        Id,
        Status__c,
        Request__c,
        Response__c,
        Path__c,
        Type__c,
        Code__c,
        Invoice__c,
        errorLog__c
      FROM Callout__c
      WHERE jobId__c = :jobId
      LIMIT 1
    ];
    cancelInvoices(this.invoicesToCancel, callout);
  }

  private void cancelInvoices(
    List<Invoice__c> invoiceList,
    Callout__c callout
  ) {
    Billecta__c credentials = [
      SELECT Id, Creditor__c
      FROM Billecta__c
    ];
    List<Invoice__c> invoicesToCancel = invoiceList;

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
    callout.request__c = jsonString;
    callout.path__c = 'POST: ' + request.getEndpoint();
    try {
      system.debug('REQUEST : ' + request);
      response = http.send(request);
      callout.response__c = response.getBody();
      callout.code__c = String.valueOf(response.getStatusCode());
    } catch (Exception e) {
      system.debug('ERROR Sending request : ' + e.getMessage());
      logError(e);
      callout.Status__c = 'Failed';
      callout.errorLog__c =
        e.getStackTraceString().replace('\n', ' / ') +
        ' - ' +
        e.getMessage();
    }

    if (response.getStatusCode() == 200 || response.getStatusCode() == 201) {
      callout.Status__c = 'OK';
      system.debug('Everything is FINE : ' + response.getBody());
      List<Invoice__c> invoicesToUpdate = new List<Invoice__c>();

      for (Invoice__c inv : invoiceList) {
        Invoice__c invToUpdate = new Invoice__c();
        invToUpdate.Id = inv.Id;
        invToUpdate.PaymentStatus__c = 'Makulerad';

        invoicesToUpdate.add(invToUpdate);
      }

      try {
        update invoicesToUpdate;
      } catch (Exception e) {
        System.debug(
          'ERROR setting paymentStatus__c = \'Makulerad\' on all cancelled invoices. ' +
          e.getMessage()
        );
        logError(e);
      }
    } else if (
      response.getStatusCode() != 200 &&
      response.getStatusCode() != 201
    ) {
      String integrationError = 'Billecta' + '-->' + response.getBody();
      system.debug('ERROR Sending request : ' + integrationError);

      CustomException e = new CustomException(integrationError);
      logError(e);

      callout.Status__c = 'Failed';
      callout.response__c = integrationError;
    }

    update callout;
  }

  @testVisible
  private void logError(Exception e) {
    ApexLog.Error errLog = new ApexLog.Error(
      'BillectaCancelInvociesQueuable',
      'CancelInvoices',
      true,
      e
    );
  }
}