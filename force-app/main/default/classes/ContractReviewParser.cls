/**
 * Deserialises the LLM JSON stored on {@link ContractReviewResult__c} and
 * applies the verdicts onto the matching {@link ContractReviewRuntimeCriterion__c}
 * records. Strict by design: any malformed JSON, missing/invalid
 * {@code recordId}, or unknown criterion id throws
 * {@link ContractReviewParserException} so the caller (the queueable) can
 * roll back its savepoint and mark the review as Failure.
 *
 * Governor-limit notes:
 *   - 2 SOQL queries per call (results lookup + criteria lookup).
 *   - 1 bulk UPDATE DML covering all criteria for all input results.
 */
public with sharing class ContractReviewParser {

    public class ContractReviewParserException extends Exception {}

    /**
     * Internal shape that mirrors the JSON contract emitted by the review
     * prompt templates. Field names must match exactly— they are bound by
     * {@code JSON.deserialize}.
     */
    @TestVisible
    private class ParsedCriterion {
        public String recordId;
        public Boolean met;
        public String extract;
        public String aicomment;
    }

    /**
     * Bulk-safe entry point. Reads each result's JSON, accumulates the
     * verdicts, then issues a single UPDATE on the affected runtime
     * criteria.
     *
     * Governor-limit hot spots: the SOQL on results and the SOQL on
     * criteria — both filtered by Id sets so they remain selective.
     *
     * @param resultIds {@link ContractReviewResult__c} record Ids whose
     *                  {@code JSON__c} should be ingested.
     * @throws ContractReviewParserException if any JSON body is missing,
     *         malformed, references an invalid criterion id, or refers
     *         to a criterion that does not exist.
     */
    @InvocableMethod(label='Parse Contract Review JSON' description='Parses the JSON__c field from ContractReviewResult__c and updates related ContractReviewRuntimeCriterion__c records.')
    public static void parseReviewJSON(List<Id> resultIds) {
        if (resultIds == null || resultIds.isEmpty()) {
            return;
        }

        Map<Id, ContractReviewResult__c> resultsMap = new Map<Id, ContractReviewResult__c>([
            SELECT Id, JSON__c
            FROM ContractReviewResult__c
            WHERE Id IN :resultIds
        ]);

        Map<Id, ParsedCriterion> criterionDataById = new Map<Id, ParsedCriterion>();

        for (Id resultId : resultIds) {
            ContractReviewResult__c result = resultsMap.get(resultId);

            if (result == null || String.isBlank(result.JSON__c)) {
                throw new ContractReviewParserException(
                    'No JSON found on ContractReviewResult__c: ' + resultId
                );
            }

            criterionDataById.putAll(parseJSON(resultId, result.JSON__c));
        }

        if (criterionDataById.isEmpty()) {
            return;
        }

        Map<Id, ContractReviewRuntimeCriterion__c> criteriaMap = new Map<Id, ContractReviewRuntimeCriterion__c>([
            SELECT Id
            FROM ContractReviewRuntimeCriterion__c
            WHERE Id IN :criterionDataById.keySet()
        ]);

        List<ContractReviewRuntimeCriterion__c> toUpdate = buildUpdates(criterionDataById, criteriaMap);

        if (!toUpdate.isEmpty()) {
            update toUpdate;
        }
    }

    /**
     * Deserialises one result's JSON body into a map keyed by criterion Id.
     * Validates that every entry has a non-blank, well-formed Id.
     *
     * @param resultId Used only for error messages.
     * @param jsonBody Raw JSON returned by the LLM.
     * @return Map of criterion Id → parsed verdict.
     * @throws ContractReviewParserException on any validation failure.
     */
    @TestVisible
    private static Map<Id, ParsedCriterion> parseJSON(Id resultId, String jsonBody) {
        List<ParsedCriterion> parsed;
        try {
            parsed = (List<ParsedCriterion>) JSON.deserialize(jsonBody, List<ParsedCriterion>.class);
        } catch (Exception e) {
            throw new ContractReviewParserException(
                'Failed to parse JSON on ContractReviewResult__c ' + resultId + ': ' + e.getMessage()
            );
        }

        Map<Id, ParsedCriterion> result = new Map<Id, ParsedCriterion>();
        for (ParsedCriterion pc : parsed) {
            if (String.isBlank(pc.recordId)) {
                throw new ContractReviewParserException(
                    'Missing recordId in JSON on ContractReviewResult__c: ' + resultId
                );
            }
            try {
                Id criterionId = Id.valueOf(pc.recordId);
                result.put(criterionId, pc);
            } catch (Exception e) {
                throw new ContractReviewParserException(
                    'Invalid criterion ID "' + pc.recordId + '": ' + e.getMessage()
                );
            }
        }
        return result;
    }

    /**
     * Builds the list of criterion records to update, throwing if any
     * verdict references a criterion Id that does not exist on this review
     * (defensive guard against LLM hallucination).
     */
    @TestVisible
    private static List<ContractReviewRuntimeCriterion__c> buildUpdates(
        Map<Id, ParsedCriterion> criterionDataById,
        Map<Id, ContractReviewRuntimeCriterion__c> existingCriteria
    ) {
        List<ContractReviewRuntimeCriterion__c> toUpdate = new List<ContractReviewRuntimeCriterion__c>();
        for (Id criterionId : criterionDataById.keySet()) {
            ContractReviewRuntimeCriterion__c criterion = existingCriteria.get(criterionId);
            if (criterion == null) {
                throw new ContractReviewParserException(
                    'ContractReviewRuntimeCriterion__c not found: ' + criterionId
                );
            }
            ParsedCriterion pc = criterionDataById.get(criterionId);
            criterion.CriterionMet__c = pc.met;
            criterion.Extract__c = pc.extract;
            criterion.ai_comment__c = pc.aicomment;
            toUpdate.add(criterion);
        }
        return toUpdate;
    }
}