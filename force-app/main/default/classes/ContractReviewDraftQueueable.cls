/**
 * Asynchronous job that produces the HTML email draft for one review in one
 * language. Chained from {@link ContractReviewQueueable} after a successful
 * review (Swedish only by default), and may be enqueued manually for English.
 *
 * Reads the precomputed SV/EN summary from {@link ContractReview__c}, calls
 * {@link ContractReviewPromptService#generateEmailDraft} to ask Einstein for
 * an HTML draft, writes the result to {@code ResponseDraft__c} or
 * {@code ResponseDraft_Eng__c}, and publishes
 * {@code ContractReviewDraftCompleted__e} so the LWC viewer can refresh its
 * Svarstext tab.
 *
 * Governor-limit notes:
 *   - 1 HTTP/Einstein callout per execution.
 *   - 1 SOQL + at most 1 UPDATE DML per execution.
 *   - 1 platform-event publish (PublishAfterCommit), always fired so the UI
 *     learns about both success and failure.
 */
public with sharing class ContractReviewDraftQueueable implements Queueable, Database.AllowsCallouts {

    private Id reviewId;
    private String language;

    private static final Set<String> ALLOWED_LANGUAGES = new Set<String>{ 'Svenska', 'English' };

    /**
     * @param reviewId The review record whose summary should be turned into
     *                 an email draft.
     * @param language Either {@code 'Svenska'} or {@code 'English'}; any
     *                 other value throws {@link IllegalArgumentException}
     *                 immediately so a misconfigured caller fails fast.
     */
    public ContractReviewDraftQueueable(Id reviewId, String language) {
        if (!ALLOWED_LANGUAGES.contains(language)) {
            throw new IllegalArgumentException(
                'Unsupported language: ' + language + '. Allowed: ' + ALLOWED_LANGUAGES
            );
        }
        this.reviewId = reviewId;
        this.language = language;
    }

    /**
     * Queueable entry point. Performs one Einstein callout to generate the
     * draft and one DML to persist it. Any thrown exception is caught and
     * surfaced via {@code ContractReviewDraftCompleted__e} with
     * {@code Status__c = 'Failed'}; the job itself does not re-throw so the
     * platform does not retry the Queueable.
     *
     * Governor-limit hot spot: the Einstein callout. Cumulative callout time
     * across the job must stay under the 120 s limit.
     *
     * @param ctx Queueable execution context (unused).
     */
    public void execute(QueueableContext ctx) {
        // Default to Success; flipped to 'Failed' on the first error path
        // and surfaced through the platform event below.
        String status = 'Success';
        String errorMessage = null;
        Id caseId;

        try {
            ContractReview__c review = [
                SELECT Output_Sv__c, Output_Eng__c, Case__c
                FROM ContractReview__c
                WHERE Id = :reviewId
                LIMIT 1
            ];
            caseId = review.Case__c;

            String outputText = language == 'Svenska'
                ? review.Output_Sv__c
                : review.Output_Eng__c;

            if (String.isBlank(outputText)) {
                status = 'Failed';
                errorMessage = 'No output text available for the requested language';
            } else {
                String generatedHtml = ContractReviewPromptService.generateEmailDraft(
                    review.Case__c, outputText, language
                );

                if (String.isBlank(generatedHtml)) {
                    status = 'Failed';
                    errorMessage = 'Prompt template returned empty response';
                } else {
                    ContractReview__c toUpdate = new ContractReview__c(Id = reviewId);
                    if (language == 'Svenska') {
                        toUpdate.ResponseDraft__c = generatedHtml;
                    } else {
                        toUpdate.ResponseDraft_Eng__c = generatedHtml;
                    }
                    update toUpdate;
                }
            }
        } catch (Exception ex) {
            status = 'Failed';
            errorMessage = ex.getMessage().left(32768);
            System.debug(LoggingLevel.ERROR,
                'Draft generation failed (' + language + '): ' + ex.getMessage());
        }

        EventBus.publish(new ContractReviewDraftCompleted__e(
            ReviewId__c = reviewId,
            CaseId__c = caseId,
            Language__c = language,
            Status__c = status,
            ErrorMessage__c = errorMessage
        ));
    }
}