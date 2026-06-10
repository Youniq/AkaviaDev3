public class BillectaSendRetroactiveInvoiceAsync implements Queueable, Database.AllowsCallouts {

    private Id accountId;
    private Id calloutId;
    private BillectaCreateInvoice retroactiveInv;

    public BillectaSendRetroactiveInvoiceAsync(
        Id accountId,
        Id calloutId,
        BillectaCreateInvoice retroactiveInv
    ) {
        this.accountId = accountId;
        this.calloutId = calloutId;
        this.retroactiveInv = retroactiveInv;
    }

    public void execute(QueueableContext context) {

        System.debug('=== RETROACTIVE START ===');
        System.debug('accountId: ' + accountId);
        System.debug('calloutId: ' + calloutId);

        Long start = System.now().getTime();

        Callout__c co = [
            SELECT Id,
                   Status__c,
                   Response__c,
                   Request__c,
                   Path__c,
                   ErrorLog__c,
                   SentOn__c,
                   Duration__c
            FROM Callout__c
            WHERE Id = :calloutId
            LIMIT 1
        ];

        try {

            Account acc = [
                SELECT Id,
                    MemberNumber__c,
                    MembershipCategory__c,
                    FeeCategory__c,
                    SocialSecurityNumber__c,
                    BillectaID__c
                FROM Account
                WHERE Id = :accountId
                LIMIT 1
            ];

            Billecta__c credentials = [
                SELECT Id,
                       Creditor__c
                FROM Billecta__c
                LIMIT 1
            ];

            HttpRequest req = new HttpRequest();

            req = BillectaUtils.initBillectaRequest(req);

            Blob bodyBlob = BillectaEncodeJSON.encodeAkaviaRetroactiveInvoice(
                acc,
                retroactiveInv,
                credentials.Creditor__c
            );

            System.debug('Retroactive payload: ' + bodyBlob.toString());

            /** Method is commented out. only used for PUBLIC API
            req = BillectaUtils.CreateRetroactiveInvoice(
                req,
                bodyBlob
            );
            */

            co.Request__c = bodyBlob.toString();
            co.Path__c = req.getEndpoint();

            System.debug('Retroactive endpoint: ' + req.getEndpoint());

            HttpResponse res = new Http().send(req);

            co.Response__c = res.getBody();

            System.debug('Retroactive status: ' + res.getStatusCode());
            System.debug('Retroactive body: ' + res.getBody());

            if (res.getStatusCode() == 200 || res.getStatusCode() == 201) {

                co.Status__c = 'OK';

            } else {

                co.Status__c = 'Failed';
                co.ErrorLog__c = res.getBody();
            }

        } catch (Exception e) {

            System.debug('Retroactive ERROR: ' + e.getMessage());
            System.debug(e.getStackTraceString());

            co.Status__c = 'Failed';
            co.ErrorLog__c =
                e.getMessage() +
                ' | ' +
                e.getStackTraceString();
        }

        co.SentOn__c = System.now();
        co.Duration__c = System.now().getTime() - start;

        update co;
    }
}