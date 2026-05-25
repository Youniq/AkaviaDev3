/**
 * Invocable bridge between the {@code ContractReview} Flow and the async
 * review pipeline. Enforces the single-review-per-Case constraint, flips the
 * review to {@code Status__c = 'Processing'}, enqueues
 * {@link ContractReviewQueueable}, and publishes
 * {@code ContractReviewStarted__e} so the LWC viewer switches state.
 *
 * Governor-limit notes:
 *   - 1 SOQL for the review header.
 *   - 1 SOQL with {@code FOR UPDATE} for the in-progress lock.
 *   - 1 SOQL for file size validation.
 *   - 1 UPDATE DML.
 *   - 1 {@code System.enqueueJob} (depth 1 from the Flow).
 *   - 1 platform-event publish (PublishAfterCommit).
 */
public with sharing class ContractReviewQueueableEnqueuer {

    @TestVisible
    private static Long MAX_FILE_SIZE_BYTES = 15 * 1024 * 1024; // 15 MB

    public class ContractReviewQueueableEnqueuerException extends Exception {}

    /**
     * Invocable input wrapper used by the {@code ContractReview} Flow.
     */
    public class EnqueueRequest {
        @InvocableVariable(required=true label='Contract Review Id')
        public Id reviewId;

        @InvocableVariable(required=true label='Content Document Id')
        public Id contentDocumentId;
    }

    /**
     * Validates the in-progress constraint and kicks off async processing.
     * Only the first request in the list is processed (the Flow is
     * single-record by design).
     *
     * Governor-limit hot spots: the {@code FOR UPDATE} SOQL holds a row
     * lock until the transaction commits, so callers should keep the
     * surrounding work small.
     *
     * @param requests Single-element list provided by the Flow's Apex
     *                 action call.
     * @throws AuraHandledException if another review on the same Case is
     *                              currently in {@code Processing} status.
     */
    @InvocableMethod(label='Enqueue Contract Review Processing' description='Sets status to Processing and enqueues background prompt template call.')
    public static void enqueue(List<EnqueueRequest> requests) {
        if (requests == null || requests.isEmpty()) {
            return;
        }

        EnqueueRequest req = requests[0];

        ContractReview__c review = [
            SELECT Id, Case__c
            FROM ContractReview__c
            WHERE Id = :req.reviewId
            LIMIT 1
        ];

        // FOR UPDATE row-lock: prevents two parallel Flow runs from both
        // passing the in-progress check on the same Case.
        List<ContractReview__c> processingReviews = [
            SELECT Id
            FROM ContractReview__c
            WHERE Case__c = :review.Case__c
              AND Status__c = 'Processing'
            FOR UPDATE
        ];

        if (!processingReviews.isEmpty()) {
            AuraHandledException e = new AuraHandledException(
                'En granskning pågår redan för detta ärende.'
            );
            e.setMessage('En granskning pågår redan för detta ärende.');
            throw e;
        }

        // File size validation
        ContentDocument doc = [
            SELECT ContentSize
            FROM ContentDocument
            WHERE Id = :req.contentDocumentId
            WITH USER_MODE
            LIMIT 1
        ];
        if (doc.ContentSize > MAX_FILE_SIZE_BYTES) {
            String msg = 'Filen är för stor. Maximal filstorlek är 15 MB. Aktuell storlek: '
                + (doc.ContentSize / (1024 * 1024)) + ' MB.';
            AuraHandledException e = new AuraHandledException(msg);
            e.setMessage(msg);
            throw e;
        }

        update new ContractReview__c(
            Id = req.reviewId,
            Status__c = 'Processing'
        );

        System.enqueueJob(
            new ContractReviewQueueable(req.reviewId, req.contentDocumentId)
        );

        EventBus.publish(new ContractReviewStarted__e(
            ReviewId__c = req.reviewId,
            CaseId__c = review.Case__c
        ));
    }
}