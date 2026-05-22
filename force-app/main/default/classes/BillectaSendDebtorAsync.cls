/**
 * @description       : 
 * @author            : Malin Nilsson (Stretch Customer AB)
 * @group             : 
 * @last modified on  : 2026-05-22
 * @last modified by  : Stefan Trieton (Stretch Customer AB)
**/
public class BillectaSendDebtorAsync implements Queueable, Database.AllowsCallouts {
    private Account acc { get; set; }
    private Boolean updatePaymentMethod { get; set; }
    private String BillectaId { get; set; }

    public BillectaSendDebtorAsync(Account acc, Boolean updatePaymentMethod) {
        this.acc = acc;
        this.updatePaymentMethod = updatePaymentMethod;
    }

    public void execute(QueueableContext context) {
        Callout__c currentCallout = [
            SELECT Id, Status__c, sentOn__c, Duration__c, Response__c, Account__c,
                   jobId__c, errorLog__c, extraMessage__c
            FROM Callout__c
            WHERE jobId__c = :context.getJobId()
            LIMIT 1
        ];

        Account freshAcc = [
            SELECT Id,
                    PaymentMethod__c,
                    DistributionMethod__c,
                    LatestSentPMDetails_Billecta__c,
                    BillectaID__c,
                    
                    FeeCategory__c,
                    MemberNumber__c,
                    FirstName,
                    LastName,
                    SocialSecurityNumber__c,
                    
                    CurrentStreetAdress__c,
                    CurrentCOAdress__c,
                    CurrentZipCode__c,
                    CurrentCity__c,
                    CurrentCountry__c,
                    CurrentCountryCode__c,
                    
                    PersonMobilePhone,
                    PersonEmail,
                    ProtectedIdentity__c,
                    IsDistributionPostalPaperOnly__c,
                    
                    AG_BankAccountNumber__c,
                    AG_BankClearingNumber__c,
                    AutogiroBank__c,
                    AutogiroApprovalStatus__c,

                    EInvoiceBank__c
            FROM Account
            WHERE Id = :this.acc.Id
            LIMIT 1
        ];

        this.acc = freshAcc;

        if (currentCallout.extraMessage__c == null) {
            currentCallout.extraMessage__c =
                updatePaymentMethod ? 'Update Contact and Payment Method' : 'Update Contact Details Only';
        }

        Account accToUpdate = new Account(Id = freshAcc.Id);

        Long start = System.now().getTime();
        currentCallout = sendToBillecta(currentCallout);

        if (currentCallout.errorLog__c == null) {
            currentCallout.status__c = 'OK';
        }

        currentCallout.sentOn__c = System.now();
        currentCallout.Duration__c = System.now().getTime() - start;

        if (freshAcc.BillectaID__c == null && currentCallout.status__c == 'OK') {
            try {
                BillectaCreateDebtor.CreatedView jsonResponse =
                    BillectaCreateDebtor.parse(currentCallout.Response__c);

                BillectaId = jsonResponse.PublicId;

                this.acc.BillectaID__c = BillectaId;
                accToUpdate.BillectaID__c = BillectaId;

                update accToUpdate;
            } catch (Exception e) {
                currentCallout = setFailedCalloutValues(currentCallout, e);
                update currentCallout;
            }
        } else if (freshAcc.BillectaID__c != null && currentCallout.status__c == 'OK') {
            try {
                accToUpdate.BillectaMarkedForUpdate__c = null;

                String sentPMDetails = '';

                if (this.updatePaymentMethod == true) {
                    sentPMDetails = freshAcc.PaymentMethod__c + ' : ' + freshAcc.DistributionMethod__c;
                }

                if (
                    this.updatePaymentMethod &&
                    BillectaUtils.isDefaultDeliveryMethodKivra(freshAcc) &&
                    freshAcc.DistributionMethod__c != 'Kivra'
                ) {
                    accToUpdate.DistributionMethod__c = 'Kivra';
                    sentPMDetails = freshAcc.PaymentMethod__c + ' : Default to Kivra';
                }

                accToUpdate.LatestSentPMDetails_Billecta__c = sentPMDetails;

                update accToUpdate;
            } catch (Exception e) {
                currentCallout = setFailedCalloutValues(currentCallout, e);
                update currentCallout;
            }
        }

        update currentCallout;
    }

    public Callout__c sendToBillecta(Callout__c co) {
        Blob jsonPayload;
        System.debug('*** sendPayload START ***');

        Billecta__c credentials = [
            SELECT Id, Creditor__c
            FROM Billecta__c
            LIMIT 1
        ];

        Http http = new Http();
        HttpRequest request = new HttpRequest();
        HttpResponse response = new HttpResponse();

        request = BillectaUtils.initBillectaRequest(request);

        if (this.acc.BillectaID__c == null) {
            jsonPayload = BillectaEncodeJSON.encodeCreateDebtor(this.acc, credentials.Creditor__c);
            request = BillectaUtils.CreateDebtor(request, jsonPayload);
        } else {
            request = BillectaUtils.GetDebtor(request, this.acc.BillectaID__c);

            try {
                response = http.send(request);
            } catch (Exception e) {
                co = setFailedCalloutValues(co, e);
            }

            if (response.getStatusCode() == 200 || response.getStatusCode() == 201) {
                co.Response__c =
                    'RESPONSE GET DEBTOR: ' +
                    response.getBody() +
                    'END GET DEBTOR *******   RESPONSE UPDATE DEBTOR:  ';

                BillectaCreateDebtor.DebtorView currentDebtor =
                    BillectaCreateDebtor.parseDebtor(response.getBody());

                jsonPayload =
                    BillectaEncodeJSON.encodeUpdateDebtor(
                        this.acc,
                        currentDebtor,
                        this.updatePaymentMethod
                    );

                request = new HttpRequest();
                request = BillectaUtils.initBillectaRequest(request);
                request = BillectaUtils.UpdateDebtor(request, jsonPayload);
            } else {
                co.Status__c = 'Failed';
                co.errorLog__c =
                    co.errorLog__c +
                    '<--APEX*****Billecta-->' +
                    response.getBody();

                co.path__c = request.getEndpoint();
                return co;
            }
        }

        co.request__c = jsonPayload.toString();
        co.path__c = request.getEndpoint();

        System.debug('Request: ' + request);
        System.debug('Body: ' + request.getBody());

        try {
            response = http.send(request);
        } catch (Exception e) {
            System.debug('Request Header SecureToken: ' + request.getHeader('SecureToken'));
            co = setFailedCalloutValues(co, e);
        }

        if (response.getStatusCode() == 200 || response.getStatusCode() == 201) {
            co.Status__c = 'OK';
        } else {
            co.Status__c = 'Failed';
            co.errorLog__c =
                co.errorLog__c +
                '<--APEX*****Billecta-->' +
                response.getBody();
        }

        System.debug('Response Code: ' + response.getStatusCode());
        System.debug('Response Body: ' + response.getBody());

        if (co.Response__c != null) {
            co.Response__c = co.Response__c + response.getBody();
        } else {
            co.Response__c = response.getBody();
        }

        return co;
    }

    public Callout__c setFailedCalloutValues(Callout__c c, Exception e) {
        c.Status__c = 'Failed';
        c.errorLog__c = e.getStackTraceString().replace('\n', ' / ') + ' - ' + e.getMessage();

        ApexLog.Error logError =
            new ApexLog.Error('BillectaSendDebtorAsync', 'execute', true, e);

        ApexLog.createLogDebug(logError);

        return c;
    }
}