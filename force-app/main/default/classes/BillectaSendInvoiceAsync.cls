/**
 * @description       :
 * @author            : Malin Nilsson (Stretch Customer AB)
 * @group             :
 * @last modified on  : 2024-12-16
 * @last modified by  : Malin Nilsson (Stretch Customer AB)
 **/
public class BillectaSendInvoiceAsync implements Queueable, Database.AllowsCallouts {
  private Account acc { get; set; }
  private BillectaCreateInvoice retroactiveInv { get; set; }
  private Invoice__c inv { get; set; }
  public String errorMessage { get; set; }
  private String BillectaId { get; set; }

  public BillectaSendInvoiceAsync(Account acc) {
    this.acc = acc;
  }

  public BillectaSendInvoiceAsync(
    Account acc,
    BillectaCreateInvoice retroactiveInv
  ) {
    this.acc = acc;
    this.retroactiveInv = retroactiveInv;
  }

  public BillectaSendInvoiceAsync(Account acc, Invoice__c inv) {
    this.acc = acc;
    this.inv = inv;
  }

  public void execute(QueueableContext context) {
    Callout__c currentCallout = [
      SELECT
        Id,
        Status__c,
        sentOn__c,
        Duration__c,
        Response__c,
        Account__c,
        jobId__c,
        errorLog__c,
        Type__c
      FROM Callout__c
      WHERE jobId__c = :context.getJobId()
    ];

    Long start = System.now().getTime();

    /******FIRST WE CREATE/UPDATE INVOICE*****/
    currentCallout = sendToBillecta(currentCallout);

    if (currentCallout.errorLog__c == null)
      currentCallout.status__c = 'OK';

    currentCallout.sentOn__c = System.now();
    currentCallout.Duration__c = system.now().getTime() - start;

    /******SECOND WE CREATE INVOICE RECORD AND ATTACH BILLECTAID *****/
    if (
      currentCallout.Type__c == 'Billecta - Create Invoice' ||
      currentCallout.Type__c == 'Billecta - Create Retroactive Invoice'
    ) {
      if (currentCallout.status__c == 'OK') {
        BillectaCreateInvoice.CreatedView jsonResponse = BillectaCreateInvoice.parse(
          currentCallout.Response__c
        );
        system.debug('parsed json : ' + jsonresponse);
        BillectaId = jsonResponse.PublicId;

        system.debug('BillectaId String : ' + BillectaId);
        Invoice__c inv = new Invoice__c();

        if (this.retroactiveInv == null) {
          // An invoice for current month
          inv.MembershipCategory__c = this.acc.MembershipCategory__c;
          inv.FeeCategory__c = this.acc.FeeCategory__c;
          inv.Person__c = this.acc.Id;
          inv.BillectaID__c = BillectaId;
        } else {
          // A retroactive invoice
          inv.MembershipCategory__c = this.retroactiveInv.MembershipCategory;
          inv.FeeCategory__c = this.retroactiveInv.FeeCategory;
          inv.Person__c = this.acc.Id;
          inv.BillectaId__c = BillectaId;
        }

        try {
          insert inv;
        } catch (Exception e) {
          currentCallout = setFailedCalloutValues(currentCallout, e);
        }
      }
    } else if (currentCallout.Type__c == 'Billecta - Pause Invoice') {
      if (currentCallout.status__c == 'OK') {
        this.inv.PaymentStatus__c = 'Pausad';
        try {
          update inv;
        } catch (Exception e) {
          currentCallout = setFailedCalloutValues(currentCallout, e);
        }
      }
    }

    /******THIRD WE UPDATE CALLOUT*****/

    update currentCallout;
  }

  public Callout__c sendToBillecta(Callout__c co) {
    Blob jsonPayload;
    System.debug('*** sendPayload START ***');
    Billecta__c credentials = [
      SELECT Id, Creditor__c
      FROM Billecta__c
    ];

    Http http = new Http();
    HttpRequest request = new HttpRequest();
    HttpResponse response = new HttpResponse();

    Boolean incomeInsurance = false;

    if (this.acc.MembershipBenefits__r.size() > 0) {
      incomeInsurance = true;
    }

    if (co.Type__c == 'Billecta - Create Invoice') {
      jsonPayload = BillectaEncodeJSON.encodeAkaviaInvoiceActionView(
        this.acc,
        incomeInsurance,
        credentials.Creditor__c
      );
      request = BillectaUtils.initBillectaRequest(request);
      request = BillectaUtils.CreateInvoice(request, jsonPayload);

      co.request__c = jsonPayload.toString();
      co.path__c = request.getEndpoint();

      System.debug('Request: ' + request);
      System.debug('Body: ' + request.getBody());
    }
    if (co.Type__c == 'Billecta - Create Retroactive Invoice') {
      jsonPayload = BillectaEncodeJSON.encodeAkaviaRetroactiveInvoice(
        this.acc,
        this.retroactiveInv,
        credentials.Creditor__c
      );

      System.debug(JSON.serializePretty(jsonPayload));

      request = BillectaUtils.initBillectaRequest(request);
      request = BillectaUtils.CreateInvoice(request, jsonPayload);
      co.request__c = jsonPayload.toString();
      co.path__c = request.getEndpoint();

      System.debug('Request: ' + request);
      System.debug('Body: ' + request.getBody());
    } else if (co.Type__c == 'Billecta - Pause Invoice') {
      request = BillectaUtils.initBillectaRequest(request);
      request = BillectaUtils.PauseInvoice(request, this.inv.BillectaID__c);
      co.path__c = request.getEndpoint();
    }

    try {
      response = http.send(request);
    } catch (Exception e) {
      co = setFailedCalloutValues(co, e);
    }

    if (response.getStatusCode() == 200 || response.getStatusCode() == 201)
      co.Status__c = 'OK';
    else if (
      response.getStatusCode() != 200 &&
      response.getStatusCode() != 201
    ) {
      co.Status__c = 'Failed';
      co.errorLog__c =
        co.errorLog__c +
        '<--APEX*****Billecta-->' +
        response.getBody();
    }

    System.debug('Response Code: ' + response.getStatusCode());
    System.debug('Response Body: ' + response.getBody());
    co.Response__c = response.getBody();
    return co;
  }

  public Callout__c setFailedCalloutValues(Callout__c c, Exception e) {
    c.Status__c = 'Failed';
    c.errorLog__c =
      e.getStackTraceString().replace('\n', ' / ') +
      ' - ' +
      e.getMessage();
    ApexLog.Error logError = new ApexLog.Error(
      'BillectaSendInvoiceAsync',
      'execute',
      true,
      e
    );
    ApexLog.createLogDebug(logError);
    return c;
  }
}