
public class BillectaSendDebtorAsync
    implements Queueable, Database.AllowsCallouts {

    private Account acc { get; set; }
    private Boolean updatePaymentMethod { get; set; }
    private String BillectaId { get; set; }
    private Id calloutId;

    public BillectaSendDebtorAsync(
        Account acc,
        Boolean updatePaymentMethod
    ) {
        this(acc, updatePaymentMethod, null);
    }

    public BillectaSendDebtorAsync(
        Account acc,
        Boolean updatePaymentMethod,
        Id calloutId
    ) {
        this.acc = acc;
        this.updatePaymentMethod = updatePaymentMethod;
        this.calloutId = calloutId;
    }

    public void execute(QueueableContext context) {

        System.attachFinalizer(
            new BillectaSendDebtorFinalizer()
        );

        String jobId = String.valueOf(context.getJobId());

        List<Callout__c> callouts;

        if (calloutId != null) {
            callouts = [
                SELECT Id, Status__c, SentOn__c,
                       Duration__c, Response__c,
                       Account__c, JobId__c,
                       ErrorLog__c, ExtraMessage__c
                FROM Callout__c
                WHERE Id = :calloutId
                LIMIT 1
            ];
        } else {
            callouts = [
                SELECT Id, Status__c, SentOn__c,
                       Duration__c, Response__c,
                       Account__c, JobId__c,
                       ErrorLog__c, ExtraMessage__c
                FROM Callout__c
                WHERE JobId__c = :jobId
                LIMIT 1
            ];
        }

        if (callouts.isEmpty()) {
            System.debug(
                LoggingLevel.ERROR,
                'BillectaSendDebtorAsync: Missing Callout__c for JobId ' +
                jobId
            );
            return;
        }

        Callout__c currentCallout = callouts[0];

        if (currentCallout.ExtraMessage__c == null) {
            currentCallout.ExtraMessage__c =
                updatePaymentMethod
                    ? 'Update Contact and Payment Method'
                    : 'Update Contact Details Only';
        }

        Account accToUpdate = new Account(Id = acc.Id);

        Long start = System.now().getTime();

        currentCallout = sendToBillecta(currentCallout);

        if (currentCallout.ErrorLog__c == null) {
            currentCallout.Status__c = 'OK';
        }

        currentCallout.SentOn__c = System.now();
        currentCallout.Duration__c =
            System.now().getTime() - start;

        if (
            acc.BillectaID__c == null &&
            currentCallout.Status__c == 'OK'
        ) {
            try {
                BillectaCreateDebtor.CreatedView jsonResponse =
                    BillectaCreateDebtor.parse(
                        currentCallout.Response__c
                    );

                BillectaId = jsonResponse.PublicId;

                acc.BillectaID__c = BillectaId;
                accToUpdate.BillectaID__c = BillectaId;

                update accToUpdate;

            } catch (Exception e) {
                currentCallout =
                    setFailedCalloutValues(currentCallout, e);
            }

        } else if (
            acc.BillectaID__c != null &&
            currentCallout.Status__c == 'OK'
        ) {
            try {
                accToUpdate.BillectaMarkedForUpdate__c = null;

                String sentPMDetails = '';

                if (updatePaymentMethod) {
                    sentPMDetails =
                        acc.PaymentMethod__c +
                        ' : ' +
                        acc.DistributionMethod__c;
                }

                if (
                    updatePaymentMethod &&
                    BillectaUtils.isDefaultDeliveryMethodKivra(acc) &&
                    acc.DistributionMethod__c != 'Kivra'
                ) {
                    accToUpdate.DistributionMethod__c = 'Kivra';

                    sentPMDetails =
                        acc.PaymentMethod__c +
                        ' : Default to Kivra';
                }

                accToUpdate.LatestSentPMDetails_Billecta__c =
                    sentPMDetails;

                update accToUpdate;

            } catch (Exception e) {
                currentCallout =
                    setFailedCalloutValues(currentCallout, e);
            }
        }

        update currentCallout;
    }

    public Callout__c sendToBillecta(Callout__c co) {

        Blob jsonPayload;

        Billecta__c credentials = [
            SELECT Id, Creditor__c
            FROM Billecta__c
            LIMIT 1
        ];

        Http http = new Http();
        HttpRequest request = new HttpRequest();
        HttpResponse response = new HttpResponse();

        request = BillectaUtils.initBillectaRequest(request);

        if (acc.BillectaID__c == null) {

            jsonPayload =
                BillectaEncodeJSON.encodeCreateDebtor(
                    acc,
                    credentials.Creditor__c
                );

            request = BillectaUtils.CreateDebtor(
                request,
                jsonPayload
            );

        } else {

            request = BillectaUtils.GetDebtor(
                request,
                acc.BillectaID__c
            );

            try {
                response = http.send(request);
            } catch (Exception e) {
                return setFailedCalloutValues(co, e);
            }

            if (
                response.getStatusCode() == 200 ||
                response.getStatusCode() == 201
            ) {

                co.Response__c =
                    'RESPONSE GET DEBTOR: ' +
                    response.getBody() +
                    'END GET DEBTOR *******   RESPONSE UPDATE DEBTOR:  ';

                BillectaCreateDebtor.DebtorView currentDebtor =
                    BillectaCreateDebtor.parseDebtor(
                        response.getBody()
                    );

                jsonPayload =
                    BillectaEncodeJSON.encodeUpdateDebtor(
                        acc,
                        currentDebtor,
                        updatePaymentMethod
                    );

                request = BillectaUtils.initBillectaRequest(
                    new HttpRequest()
                );

                request = BillectaUtils.UpdateDebtor(
                    request,
                    jsonPayload
                );

            } else {
                co.Status__c = 'Failed';
                co.ErrorLog__c =
                    '<--APEX*****Billecta-->' +
                    response.getBody();
                co.Path__c = request.getEndpoint();
                return co;
            }
        }

        co.Request__c = jsonPayload.toString();
        co.Path__c = request.getEndpoint();

        try {
            response = http.send(request);
        } catch (Exception e) {
            return setFailedCalloutValues(co, e);
        }

        if (
            response.getStatusCode() == 200 ||
            response.getStatusCode() == 201
        ) {
            co.Status__c = 'OK';
        } else {
            co.Status__c = 'Failed';
            co.ErrorLog__c =
                '<--APEX*****Billecta-->' +
                response.getBody();
        }

        if (co.Response__c != null) {
            co.Response__c += response.getBody();
        } else {
            co.Response__c = response.getBody();
        }

        return co;
    }

    public Callout__c setFailedCalloutValues(
        Callout__c c,
        Exception e
    ) {
        c.Status__c = 'Failed';

        c.ErrorLog__c =
            e.getStackTraceString().replace('\n', ' / ') +
            ' - ' +
            e.getMessage();

        ApexLog.Error logError = new ApexLog.Error(
            'BillectaSendDebtorAsync',
            'execute',
            true,
            e
        );

        //ApexLog.createLogDebug(logError);

        return c;
    }
}
