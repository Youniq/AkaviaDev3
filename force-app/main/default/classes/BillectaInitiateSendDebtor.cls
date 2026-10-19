
/**
 * @description       : Initiates creation or update of Billecta debtors.
 *                      Validates Accounts, schedules Queueable jobs and
 *                      creates corresponding Callout__c tracking records.
 *
 * @author            : Jenny Blomberg
 * @last modified on  : 2026-10-19
 * @last modified by  : Stefan Trieton (Stretch Customer AB)
 */
public class BillectaInitiateSendDebtor {

    public class Request {

        @InvocableVariable(
            label='Account Id'
            description='Det Account id som ska skickas till Billecta'
            required=true
        )
        public String recordId;

        @InvocableVariable(
            label='create / update / createOrUpdate'
            description='Skriv in create, update eller createOrUpdate beroende på vilken uppdatering du vill göra i Billecta'
            required=true
        )
        public String billectaAction;
    }

    public class Response {

        @InvocableVariable(
            label='Error Message'
            description='Om det förekom ett valideringsfel vid körning så returneras det här.'
        )
        public String errorMsg;
    }

    @InvocableMethod
    public static List<Response> sendDebtorWithPaymentMethod(
        List<Request> requests
    ) {
        List<Response> responses = new List<Response>();

        if (requests == null || requests.isEmpty()) {
            return responses;
        }

        Map<Id, String> accountIdsToAction =
            new Map<Id, String>();

        // Validate input and preserve one response per request.
        for (Request req : requests) {

            Response resp = new Response();

            if (req == null ||
                String.isBlank(req.recordId)) {

                resp.errorMsg = 'Account Id saknas.';
                responses.add(resp);
                continue;
            }

            try {
                Id accountId = (Id) req.recordId;

                accountIdsToAction.put(
                    accountId,
                    req.billectaAction
                );

                resp.errorMsg = null;

            } catch (Exception e) {
                resp.errorMsg =
                    'Ogiltigt Account Id: ' + req.recordId;
            }

            responses.add(resp);
        }

        if (accountIdsToAction.isEmpty()) {
            return responses;
        }

        Map<Id, String> resultByAccount =
            sendDebtorInternal(
                accountIdsToAction,
                true
            );

        // Map results back to the original request order.
        for (Integer i = 0; i < requests.size(); i++) {

            if (responses[i].errorMsg != null) {
                continue;
            }

            Id accountId = (Id) requests[i].recordId;

            responses[i].errorMsg =
                resultByAccount.get(accountId);
        }

        return responses;
    }

    /**
     * Existing public entry point.
     */
    public static List<String> sendDebtor(
        Map<Id, String> accountIdsToAction,
        Boolean sendPaymentMethod
    ) {
        List<String> responseMessages =
            new List<String>();

        if (accountIdsToAction == null ||
            accountIdsToAction.isEmpty()) {

            return responseMessages;
        }

        Map<Id, String> results =
            sendDebtorInternal(
                accountIdsToAction,
                sendPaymentMethod
            );

        for (Id accountId : accountIdsToAction.keySet()) {
            responseMessages.add(
                results.get(accountId)
            );
        }

        return responseMessages;
    }

    /**
     * Validate Accounts and schedule Billecta jobs.
     */
    private static Map<Id, String> sendDebtorInternal(
        Map<Id, String> accountIdsToAction,
        Boolean sendPaymentMethod
    ) {
        Map<Id, String> results =
            new Map<Id, String>();

        for (Id accountId : accountIdsToAction.keySet()) {
            results.put(accountId, null);
        }

        // Batch processing for larger requests.
        if (accountIdsToAction.size() >= 50) {

            String billectaAction =
                accountIdsToAction.values().get(0);

            // Preserve existing behavior:
            // batch requests must use the same action.
            for (String currentAction :
                accountIdsToAction.values()) {

                if (currentAction != billectaAction) {
                    throw new BillectaException(
                        'Alla poster i samma batch måste ha samma Billecta-åtgärd.'
                    );
                }
            }

            BillectaUpdateDebtorsBatch batch =
                new BillectaUpdateDebtorsBatch(
                    accountIdsToAction.keySet(),
                    billectaAction,
                    sendPaymentMethod
                );

            Database.executeBatch(batch, 1);

            return results;
        }

        List<Account> accounts = [
            SELECT
                Id,
                BillectaID__c,
                SocialSecurityNumber__c,
                FirstName,
                LastName,
                CurrentCOAdress__c,
                CurrentStreetAdress__c,
                CurrentZipCode__c,
                CurrentCity__c,
                CurrentCountry__c,
                CurrentCountryCode__c,
                PersonMobilePhone,
                PersonEmail,
                MemberNumber__c,
                FeeCategory__c,
                ProtectedIdentity__c,
                AutogiroBank__c,
                AG_BankClearingNumber__c,
                AG_BankAccountNumber__c,
                AG_BankIDSignToken__c,
                AutogiroApprovalStatus__c,
                PaymentMethod__c,
                DistributionMethod__c,
                IsDistributionPostalPaperOnly__c,
                BillectaMarkedForUpdate__c,
                EinvoiceBank__c
            FROM Account
            WHERE Id IN :accountIdsToAction.keySet()
              AND CancellationDateGDPR__c = NULL
        ];

        Set<Id> foundAccountIds = new Set<Id>();

        List<Callout__c> calloutsScheduled =
            new List<Callout__c>();

        for (Account acc : accounts) {

            foundAccountIds.add(acc.Id);

            try {

                String action =
                    accountIdsToAction.get(acc.Id);

                BillectaValidationHelper.validateBillectaActionInput(action);

                BillectaValidationHelper.validateAccountForAction(
                    acc,
                    action
                );

            } catch (BillectaException e) {

                results.put(acc.Id, e.getMessage());

                System.debug(
                    LoggingLevel.ERROR,
                    'Billecta validation failed for Account ' +
                    acc.Id + ': ' + e.getMessage()
                );

                ApexLog.Error errLog =
                    new ApexLog.Error(
                        'BillectaInitiateSendDebtor',
                        'sendDebtor',
                        true,
                        e
                    );

                ApexLog.createLogDebug(errLog);

                continue;
            }

            // Schedule asynchronous Billecta callout.
            Id jobId = System.enqueueJob(
                new BillectaSendDebtorAsync(
                    acc,
                    sendPaymentMethod
                )
            );

            calloutsScheduled.add(
                new Callout__c(
                    JobId__c = jobId,
                    Type__c = acc.BillectaID__c == null
                        ? 'Billecta - Create Debtor'
                        : 'Billecta - Update Debtor',
                    Account__c = acc.Id,
                    Status__c = 'Queued'
                )
            );

            System.debug(
                'Billecta job scheduled: ' +
                jobId + ' / Account: ' + acc.Id
            );
        }

        // Report Accounts not returned by SOQL.
        for (Id accountId : accountIdsToAction.keySet()) {

            if (!foundAccountIds.contains(accountId)) {

                results.put(
                    accountId,
                    'Account hittades inte eller är GDPR-avslutat.'
                );
            }
        }

        if (!calloutsScheduled.isEmpty()) {

            // All-or-none:
            // If tracking records cannot be inserted,
            // the transaction must roll back together
            // with the scheduled Queueable jobs.
            insert calloutsScheduled;

            System.debug(
                'Billecta Callout records created: ' +
                calloutsScheduled.size()
            );
        }

        return results;
    }
}
