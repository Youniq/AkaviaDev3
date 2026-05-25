/**
 * Deterministically compiles the bilingual (Swedish + English) human-readable
 * summary text from runtime criterion verdicts and the reusable output text
 * stored on {@link ContractReviewCriterion__mdt}. No LLM is involved — this
 * keeps the user-visible summary stable across reviews and prevents drift in
 * tone of voice.
 *
 * Output is written to {@code ContractReview__c.Output_Sv__c} and
 * {@code Output_Eng__c}; downstream the email-draft prompt uses these as its
 * factual base.
 *
 * Governor-limit notes:
 *   - 2 SOQL queries (runtime criteria + MDT lookup), both Id-filtered.
 *   - 1 bulk UPDATE DML.
 */
public with sharing class ContractReviewOutputCompiler {

    public class ContractReviewOutputCompilerException extends Exception {}

    /**
     * Compiles SV + EN summary text for each input review and writes both
     * fields in a single DML.
     *
     * @param reviewIds {@link ContractReview__c} record Ids to compile.
     */
    @InvocableMethod(label='Compile Contract Review Output' description='Compiles output text from evaluated runtime criteria and saves it to the ContractReview__c record.')
    public static void compileOutput(List<Id> reviewIds) {
        if (reviewIds.isEmpty()) {
            return;
        }

        List<ContractReviewRuntimeCriterion__c> runtimeCriteria = [
            SELECT Id, ContractReview__c, CriterionMet__c, ContractReviewCriterionId__c
            FROM ContractReviewRuntimeCriterion__c
            WHERE ContractReview__c IN :reviewIds
        ];

        if (runtimeCriteria.isEmpty()) {
            return;
        }

        Set<Id> mdtIds = new Set<Id>();
        for (ContractReviewRuntimeCriterion__c rc : runtimeCriteria) {
            if (rc.ContractReviewCriterionId__c != null) {
                mdtIds.add(rc.ContractReviewCriterionId__c);
            }
        }

        Map<Id, ContractReviewCriterion__mdt> mdtMap = new Map<Id, ContractReviewCriterion__mdt>([
            SELECT Id, MasterLabel, Display_Title__c, Display_Title_Eng__c,
                   Output_When_True_sv__c, Output_When_False_sv__c,
                   Output_When_True_Eng__c, Output_When_False_Eng__c
            FROM ContractReviewCriterion__mdt
            WHERE Id IN :mdtIds
        ]);

        Map<Id, String> svOutputByReviewId = buildOutputMap(runtimeCriteria, mdtMap, true);
        Map<Id, String> engOutputByReviewId = buildOutputMap(runtimeCriteria, mdtMap, false);

        List<ContractReview__c> toUpdate = new List<ContractReview__c>();
        for (Id reviewId : reviewIds) {
            toUpdate.add(new ContractReview__c(
                Id = reviewId,
                Output_Sv__c = svOutputByReviewId.get(reviewId),
                Output_Eng__c = engOutputByReviewId.get(reviewId)
            ));
        }

        if (!toUpdate.isEmpty()) {
            update toUpdate;
        }
    }

    /**
     * For each review, picks the SV or EN sentence per criterion based on
     * its {@code CriterionMet__c} flag, prepends the resolved heading, and
     * joins the lines with a blank line separator. Criteria with a blank
     * output value (or whose MDT record is missing) are silently skipped.
     *
     * @param runtimeCriteria All runtime criteria for the input reviews.
     * @param mdtMap          Map of MDT Id → MDT record for lookups.
     * @param isSwedish       {@code true} for Swedish, {@code false} for
     *                        English; controls which output / heading
     *                        fields are read.
     * @return Map of review Id → fully compiled summary text.
     */
    @TestVisible
    private static Map<Id, String> buildOutputMap(
        List<ContractReviewRuntimeCriterion__c> runtimeCriteria,
        Map<Id, ContractReviewCriterion__mdt> mdtMap,
        Boolean isSwedish
    ) {
        Map<Id, List<String>> outputsByReview = new Map<Id, List<String>>();

        for (ContractReviewRuntimeCriterion__c rc : runtimeCriteria) {
            ContractReviewCriterion__mdt mdt = mdtMap.get(rc.ContractReviewCriterionId__c);
            if (mdt == null) {
                continue;
            }

            String outputValue;
            if (isSwedish) {
                outputValue = rc.CriterionMet__c
                    ? mdt.Output_When_True_sv__c
                    : mdt.Output_When_False_sv__c;
            } else {
                outputValue = rc.CriterionMet__c
                    ? mdt.Output_When_True_Eng__c
                    : mdt.Output_When_False_Eng__c;
            }

            if (String.isBlank(outputValue)) {
                continue;
            }

            String heading = '\n' + resolveHeading(mdt, isSwedish);
            String formattedOutput = heading + '\n' + outputValue;

            if (!outputsByReview.containsKey(rc.ContractReview__c)) {
                outputsByReview.put(rc.ContractReview__c, new List<String>());
            }
            outputsByReview.get(rc.ContractReview__c).add(formattedOutput);
        }

        Map<Id, String> result = new Map<Id, String>();
        for (Id reviewId : outputsByReview.keySet()) {
            result.put(reviewId, String.join(outputsByReview.get(reviewId), '\n\n'));
        }
        return result;
    }

    /**
     * Returns the language-appropriate heading for the criterion, falling
     * back to {@code MasterLabel} when the localised display title is blank.
     */
    @TestVisible
    private static String resolveHeading(ContractReviewCriterion__mdt mdt, Boolean isSwedish) {
        String displayTitle = isSwedish ? mdt.Display_Title__c : mdt.Display_Title_Eng__c;
        return String.isNotBlank(displayTitle) ? displayTitle : mdt.MasterLabel;
    }
}