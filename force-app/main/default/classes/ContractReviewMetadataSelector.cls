/**
 * Read-only AuraEnabled accessor for the three Custom Metadata Types that
 * back the contract-review feature. Used exclusively by the admin LWCs
 * (template sidebar, criteria manager, assignment manager).
 *
 * Sharing: {@code without sharing} so the admin UI sees all MDT regardless
 * of FLS — access to this class is gated upstream by the
 * {@code Contract_Review_Admin} permission set.
 *
 * Governor-limit notes: each public method runs exactly 1 SOQL.
 */
public without sharing class ContractReviewMetadataSelector {
  /**
   * @return All {@link ContractReviewTemplate__mdt} records, ordered by
   *         MasterLabel, suitable for the template sidebar.
   */
  @AuraEnabled
  public static List<ContractReviewTemplate__mdt> getTemplates() {
    return [
      SELECT MasterLabel, DeveloperName, Description__c
      FROM ContractReviewTemplate__mdt
      ORDER BY MasterLabel
    ];
  }

  /**
   * @return All {@link ContractReviewCriterion__mdt} records, ordered by
   *         {@code Sequence__c}. Includes every output / display field
   *         consumed by the criteria manager and the output compiler.
   */
  @AuraEnabled
  public static List<ContractReviewCriterion__mdt> getCriteria() {
    return [
      SELECT
        MasterLabel,
        DeveloperName,
        Definition__c,
        Sequence__c,
        Display_Title__c,
        Display_Title_Eng__c,
        Output_When_False_eng__c,
        Output_When_False_sv__c,
        Output_when_True_Eng__c,
        Output_When_True_sv__c
      FROM ContractReviewCriterion__mdt
      ORDER BY Sequence__c ASC NULLS LAST
    ];
  }

  /**
   * Returns active assignments for one template, ordered by
   * {@code Sequence__c}. {@code IsActive__c = false} acts as a soft-delete
   * — those rows are excluded so the admin UI only sees live mappings.
   *
   * @param templateDeveloperName DeveloperName of the parent template.
   * @return Active assignments with the related criterion fields fetched
   *         in one round-trip.
   */
  @AuraEnabled
  public static List<ContractReviewTemplateAssignment__mdt> getTemplateAssignments(
    String templateDeveloperName
  ) {
    if (String.isBlank(templateDeveloperName)) {
      return new List<ContractReviewTemplateAssignment__mdt>();
    }
    return [
      SELECT
        MasterLabel,
        DeveloperName,
        IsActive__c,
        Sequence__c,
        ContractReviewCriterion__c,
        ContractReviewTemplate__c,
        ContractReviewCriterion__r.DeveloperName,
        ContractReviewCriterion__r.MasterLabel,
        ContractReviewCriterion__r.Definition__c
      FROM ContractReviewTemplateAssignment__mdt
      WHERE
        ContractReviewTemplate__r.DeveloperName = :templateDeveloperName
        AND IsActive__c = TRUE
      ORDER BY Sequence__c ASC NULLS LAST
    ];
  }
}