
public class BillectaSendDebtorFinalizer implements Finalizer {

    public void execute(FinalizerContext context) {

        if (
            context.getResult() !=
            ParentJobResult.UNHANDLED_EXCEPTION
        ) {
            return;
        }

        String jobId = String.valueOf(
            context.getAsyncApexJobId()
        );

        Exception jobException = context.getException();

        String errorMessage =
            jobException == null
                ? 'Unhandled Queueable exception.'
                : jobException.getMessage() +
                  ' / ' +
                  jobException.getStackTraceString();

        markCalloutFailed(jobId, errorMessage);
    }

    @TestVisible
    private static void markCalloutFailed(
        String jobId,
        String errorMessage
    ) {

        List<Callout__c> callouts = [
            SELECT Id, Status__c, ErrorLog__c, SentOn__c
            FROM Callout__c
            WHERE JobId__c = :jobId
            LIMIT 1
        ];

        if (callouts.isEmpty()) {
            System.debug(
                LoggingLevel.ERROR,
                'Billecta Finalizer: Callout__c not found. ' +
                'JobId: ' + jobId
            );
            return;
        }

        Callout__c co = callouts[0];

        co.Status__c = 'Failed';
        co.SentOn__c = System.now();

        co.ErrorLog__c =
            (String.isBlank(co.ErrorLog__c)
                ? ''
                : co.ErrorLog__c + ' / ') +
            'FINALIZER: ' + errorMessage;

        try {
            update co;
        } catch (Exception e) {
            System.debug(
                LoggingLevel.ERROR,
                'Billecta Finalizer failed to update Callout: ' +
                e.getMessage()
            );
        }
    }
}
