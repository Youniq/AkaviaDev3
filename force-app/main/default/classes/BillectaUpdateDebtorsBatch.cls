
/**
 * @description       : Creates or updates Billecta debtors asynchronously.
 *                      Validates Accounts, schedules Queueable jobs and
 *                      creates corresponding Callout__c records.
 * @last modified on  : 2026-10-19
 * @last modified by  : Stefan Trieton (Stretch Customer AB)
 */
public class BillectaUpdateDebtorsBatch
    implements Database.Batchable<sObject>, Database.Stateful {

    private Set<Id> accountIds;
    private Boolean updatePM;
    private String action;
    private String calloutExtraMsg;

    public BillectaUpdateDebtorsBatch(
        Set<Id> accountIds,
        String billectaAction,
        Boolean updatePaymentMethod
    ) {
        this(
            accountIds,
            billectaAction,
            updatePaymentMethod,
            null
        );
    }

    public BillectaUpdateDebtorsBatch(
        Set<Id> accountIds,
        String billectaAction,
        Boolean updatePaymentMethod,
        String extraMessage
    ) {
        this.accountIds = accountIds == null
            ? new Set<Id>()
            : new Set<Id>(accountIds);

        this.action = billectaAction;
        this.updatePM = updatePaymentMethod;
        this.calloutExtraMsg = extraMessage;

        BillectaValidationHelper.validateBillectaActionInput(
            this.action
        );
    }

    public Database.QueryLocator start(
        Database.BatchableContext bc
    ) {
        return Database.getQueryLocator([
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
            WHERE Id IN :accountIds
              AND CancellationDateGDPR__c = NULL
        ]);
    }

    public void execute(
        Database.BatchableContext bc,
        List<sObject> scope
    ) {
        List<Callout__c> calloutsScheduled =
            new List<Callout__c>();

        for (sObject record : scope) {
          
            Account acc = (Account) record;

            try {
                BillectaValidationHelper.validateAccountForAction(
                    acc,
                    action
                );

            } catch (BillectaException e) {
                System.debug(
                    LoggingLevel.ERROR,
                    'Billecta validation failed for Account ' +
                    acc.Id + ': ' + e.getMessage()
                );

                ApexLog.Error errLog = new ApexLog.Error(
                    'BillectaUpdateDebtorsBatch',
                    'execute',
                    true,
                    e
                );

                ApexLog.createLogDebug(errLog);
                continue;
            }

            Id jobId = System.enqueueJob(
                new BillectaSendDebtorAsync(
                    acc,
                    updatePM
                )
            );

            calloutsScheduled.add(
                new Callout__c(
                    JobId__c = jobId,
                    Type__c = acc.BillectaID__c == null
                        ? 'Billecta - Create Debtor'
                        : 'Billecta - Update Debtor',
                    Account__c = acc.Id,
                    Status__c = 'Queued',
                    ExtraMessage__c = calloutExtraMsg
                )
            );

            System.debug(
                'Billecta Queueable scheduled: ' +
                jobId + ' / Account: ' + acc.Id
            );
        }

        if (calloutsScheduled.isEmpty()) {
            return;
        }

        // All-or-none:
        // If Callout__c records cannot be created, the transaction
        // must fail so that the Queueable jobs are not committed
        // without their corresponding tracking records.
        insert calloutsScheduled;

        System.debug(
            'Billecta Callout records created: ' +
            calloutsScheduled.size()
        );
    }

    public void finish(
        Database.BatchableContext bc
    ) {
        AsyncApexJob job = [
            SELECT Id, Status, NumberOfErrors,
                   JobItemsProcessed, TotalJobItems
            FROM AsyncApexJob
            WHERE Id = :bc.getJobId()
            LIMIT 1
        ];

        System.debug(
            'BillectaUpdateDebtorsBatch finished. ' +
            'Status: ' + job.Status +
            ', Errors: ' + job.NumberOfErrors +
            ', Processed: ' + job.JobItemsProcessed +
            '/' + job.TotalJobItems
        );
    }
}
