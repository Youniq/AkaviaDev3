/**
 * Primary asynchronous orchestrator for a single GenAI contract review.
 *
 * Runs as a Queueable that allows callouts. The job:
 *   1. Loads the parent {@link ContractReview__c}.
 *   2. Classifies the file as form vs. text via
 *      {@link ContractReviewPromptService#classifyContractType}.
 *   3. Invokes the appropriate review prompt template (form or text variant).
 *   4. Persists the raw LLM JSON to {@link ContractReviewResult__c}.
 *   5. Delegates JSON ingestion to {@link ContractReviewParser} and SV/EN
 *      summary compilation to {@link ContractReviewOutputCompiler} inside a
 *      single savepoint so partial failures roll back atomically.
 *   6. Publishes a {@code ContractReviewCompleted__e} platform event.
 *   7. Sends a best-effort bell notification to the initiating user.
 *   8. On success, chains a {@link ContractReviewDraftQueueable} to generate
 *      the Swedish HTML email draft.
 *
 * Governor-limit notes:
 *   - Up to two HTTP/Einstein callouts per execution (classifier + reviewer).
 *   - One INSERT and several UPDATE DML statements per execution.
 *   - One Queueable chain enqueue (depth 2 from the originating Flow).
 *   - One platform-event publish (PublishAfterCommit).
 */
public with sharing class ContractReviewQueueable implements Queueable, Database.AllowsCallouts {

    private Id reviewId;
    private Id contentDocumentId;

    /**
     * @param reviewId          The ContractReview__c record to process.
     * @param contentDocumentId The ContentDocument representing the contract
     *                          file to be reviewed by the LLM.
     */
    public ContractReviewQueueable(Id reviewId, Id contentDocumentId) {
        this.reviewId = reviewId;
        this.contentDocumentId = contentDocumentId;
    }

    /**
     * Queueable entry point. Drives classify → review → parse → compile →
     * notify → chain. All multi-step DML inside the savepoint is atomic; any
     * caught exception flips the review to {@code Status__c = 'Failure'} and
     * still publishes the completion event so the LWC stops polling.
     *
     * Governor-limit hot spots: HTTP callouts to Einstein and DML inside the
     * savepoint block.
     *
     * @param ctx Queueable execution context (unused).
     */
    public void execute(QueueableContext ctx) {
        ContractReview__c review;
        try {
            review = [
                SELECT Name, Case__c
                FROM ContractReview__c
                WHERE Id = :reviewId
                LIMIT 1
            ];
        } catch (Exception queryEx) {
            recordFailure(queryEx.getMessage());
            EventBus.publish(new ContractReviewCompleted__e(
                ReviewId__c = reviewId
            ));
            return;
        }

        // Classifier callout #1: cheap Gemini Flash Lite call to decide which
        // review prompt template to invoke. Failure here is non-fatal — we
        // fall back to the text template, which is the safer default.
        Boolean isForm = false;
        try {
            isForm = ContractReviewPromptService.classifyContractType(contentDocumentId);
            System.debug(LoggingLevel.DEBUG,
                'Contract type classification result: isForm=' + isForm);
        } catch (Exception classifyEx) {
            System.debug(LoggingLevel.WARN,
                'Contract type classification failed, defaulting to text template: ' + classifyEx.getMessage());
        }

        Boolean success = false;
        try {
            // Reviewer callout #2: full LLM evaluation. Returns the JSON array
            // of {recordId, met, extract, aicomment} entries that the parser
            // consumes below.
            String jsonResponse = isForm
                ? ContractReviewPromptService.generateFormContractReview(reviewId, contentDocumentId)
                : ContractReviewPromptService.generateContractReview(reviewId, contentDocumentId);

            // Savepoint covers result insert + criterion updates + summary
            // compile + status flip so a parse/compile failure leaves the
            // review's runtime criteria untouched.
            Savepoint sp = Database.setSavepoint();
            try {
                ContractReviewResult__c result = new ContractReviewResult__c(
                    ContractReview__c = reviewId,
                    JSON__c = jsonResponse
                );
                insert result;

                ContractReviewParser.parseReviewJSON(new List<Id>{ result.Id });
                ContractReviewOutputCompiler.compileOutput(new List<Id>{ reviewId });

                update new ContractReview__c(
                    Id = reviewId,
                    Status__c = 'Success'
                );
                success = true;
            } catch (Exception innerEx) {
                Database.rollback(sp);
                recordFailure(innerEx.getMessage());
            }
        } catch (Exception outerEx) {
            recordFailure(outerEx.getMessage());
        }

        // PublishAfterCommit: the LWC viewer subscribes to this event to stop
        // polling and refresh the review details — fired even on failure so
        // the UI never gets stuck in the Processing state.
        EventBus.publish(new ContractReviewCompleted__e(
            ReviewId__c = reviewId,
            CaseId__c = review.Case__c
        ));

        try {
            sendBellNotification(review, success);
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR,
                'Bell notification failed: ' + e.getMessage());
        }

        // Chain async draft generation (non-critical — runs in separate transaction)
        if (success) {
            try {
                System.enqueueJob(new ContractReviewDraftQueueable(reviewId, 'Svenska'));
            } catch (Exception chainEx) {
                System.debug(LoggingLevel.ERROR,
                    'Failed to chain draft queueable: ' + chainEx.getMessage());
            }
        }
    }

    /**
     * Persists a failure status and truncated error message to the parent
     * review. Errors during this DML are swallowed (logged only) — the
     * caller still publishes the completion event so the UI can recover.
     *
     * Governor-limit note: 1 UPDATE DML.
     *
     * @param message Human-readable error message; truncated to fit the
     *                {@code ErrorMessage__c} long-text field.
     */
    private void recordFailure(String message) {
        try {
            update new ContractReview__c(
                Id = reviewId,
                Status__c = 'Failure',
                ErrorMessage__c = message.left(32768)
            );
        } catch (Exception dmlEx) {
            System.debug(LoggingLevel.ERROR,
                'Failed to record error status: ' + dmlEx.getMessage());
        }
    }

    /**
     * Sends a single-user bell notification to the initiating user. Wrapped
     * in a try/catch by the caller because notification failures must never
     * mark the review itself as failed.
     *
     * Governor-limit note: 1 SOQL + 1 Messaging.CustomNotification.send.
     *
     * @param review  The review record (used for Name and Case__c target).
     * @param success {@code true} if the review completed successfully.
     */
    private void sendBellNotification(ContractReview__c review, Boolean success) {
        List<CustomNotificationType> notifTypes = [
            SELECT Id
            FROM CustomNotificationType
            WHERE DeveloperName = 'ContractReviewNotification'
            LIMIT 1
        ];
        if (notifTypes.isEmpty()) {
            return;
        }

        Messaging.CustomNotification notification = new Messaging.CustomNotification();
        notification.setNotificationTypeId(notifTypes[0].Id);
        notification.setTargetId(review.Case__c);

        if (success) {
            notification.setTitle('Avtalsgranskning klar — ' + review.Name);
            notification.setBody('Granskningen ' + review.Name + ' är klar.');
        } else {
            notification.setTitle('Avtalsgranskning misslyckades — ' + review.Name);
            notification.setBody('Granskningen ' + review.Name + ' misslyckades. Se felmeddelande i ärendet.');
        }

        notification.send(new Set<String>{ UserInfo.getUserId() });
    }
}