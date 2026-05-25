/**
 * Read-side AuraEnabled controller backing the {@code contractReviewViewer}
 * LWC. All public methods are exposed to LWC and enforce field-level
 * security via {@code WITH USER_MODE} SOQL plus
 * {@code Security.stripInaccessible} on returned criteria.
 *
 * Sharing: {@code with sharing}. {@code ContractReview__c} is
 * {@code ControlledByParent} (Case), so record visibility follows the Case.
 *
 * Governor-limit notes:
 *   - {@link #getReviewDetails} executes up to 4 SOQL queries per call.
 *   - {@link #getContractReviews} and {@link #getReviewDetails} are
 *     {@code cacheable=true}; clients should call {@code refreshApex}
 *     after platform-event signals to invalidate the cache.
 *   - {@link #generateDraft} performs 1 enqueueJob (no callouts here
 *     — the Einstein call happens inside the queueable).
 */
public with sharing class ContractReviewController {
  // Corresponds to SUPPORTED_EXTENSIONS in ContractReviewFileSelector
  private static final Set<String> SUPPORTED_FILE_EXTENSIONS = new Set<String>{
    'pdf', 'jpg', 'jpeg', 'png'
  };

  /**
   * Aggregated payload for the viewer's main wire. Aggregates the review
   * record, its runtime criteria, the resolved template label, the linked
   * contract file (PDF/JPG/PNG if any), and both SV/EN draft fields so the LWC needs
   * exactly one round-trip.
   */
  public class ReviewDetailsWrapper {
    @AuraEnabled
    public List<ContractReviewRuntimeCriterion__c> criteria;
    @AuraEnabled
    public Id contentDocumentId;
    @AuraEnabled
    public Id contentVersionId;
    @AuraEnabled
    public String outputSv;
    @AuraEnabled
    public String outputEng;
    @AuraEnabled
    public String templateName;
    @AuraEnabled
    public String fileName;
    @AuraEnabled
    public String responseDraft;
    @AuraEnabled
    public String responseDraftEng;
    @AuraEnabled
    public String fileExtension;
  }

  /**
   * Resolves a Custom Metadata Type record Id to its MasterLabel. Reads from
   * the platform cache (no SOQL) by using {@code getAll()}.
   *
   * @param templateId The 15- or 18-char Id of a {@link ContractReviewTemplate__mdt}.
   * @return The MasterLabel, or {@code null} when the input is blank,
   *         malformed, or the MDT record no longer exists.
   */
  @TestVisible
  private static String getTemplateName(String templateId) {
    if (String.isBlank(templateId)) {
      return null;
    }
    Id validId;
    try {
      validId = Id.valueOf(templateId);
    } catch (StringException e) {
      return null;
    }
    for (
      ContractReviewTemplate__mdt mdt : ContractReviewTemplate__mdt.getAll()
        .values()
    ) {
      if (mdt.Id == validId) {
        return mdt.MasterLabel;
      }
    }
    return null;
  }

  /**
   * Returns all reviews for a Case, newest first, for the picker in the
   * viewer. Cacheable so the LWC wire reuses results until invalidated by
   * a {@code refreshApex}.
   *
   * Governor-limit note: 1 SOQL ({@code WITH USER_MODE}, FLS-enforced).
   *
   * @param caseId The Case the reviews belong to.
   * @return Reviews ordered by {@code CreatedDate DESC}.
   * @throws AuraHandledException if {@code caseId} is null or any platform
   *         exception bubbles up from the query.
   */
  @AuraEnabled(cacheable=true)
  public static List<ContractReview__c> getContractReviews(Id caseId) {
    try {
      if (caseId == null) {
        AuraHandledException e = new AuraHandledException(
          'Case Id is required'
        );
        e.setMessage('Case Id is required');
        throw e;
      }
      return [
        SELECT Id, Name, CreatedDate, Status__c, ErrorMessage__c, LastModifiedDate
        FROM ContractReview__c
        WHERE Case__c = :caseId
        WITH USER_MODE
        ORDER BY CreatedDate DESC
      ];
    } catch (AuraHandledException e) {
      throw e;
    } catch (Exception e) {
      AuraHandledException ex = new AuraHandledException(e.getMessage());
      ex.setMessage(e.getMessage());
      throw ex;
    }
  }

  /**
   * Builds the full {@link ReviewDetailsWrapper} consumed by the viewer in a
   * single round-trip. Returns an empty wrapper (rather than throwing) when
   * {@code reviewId} is null so the LWC can render an empty initial state.
   *
   * Governor-limit note: up to 4 SOQL queries:
   *   1) {@link ContractReview__c} (with output and draft fields).
   *   2) {@link ContractReviewRuntimeCriterion__c} list (FLS-stripped).
   *   3) {@link ContentDocumentLink} for the most recent linked supported file (pdf/jpg/jpeg/png).
   *   4) {@link ContentVersion} to resolve the latest version Id and file
   *      name (only when a supported file link exists).
   *
   * @param reviewId The review to load; may be null.
   * @return Populated wrapper (or an empty one if input is null).
   * @throws AuraHandledException on any unexpected platform exception.
   */
  @AuraEnabled(cacheable=true)
  public static ReviewDetailsWrapper getReviewDetails(Id reviewId) {
    ReviewDetailsWrapper wrapper = new ReviewDetailsWrapper();
    wrapper.criteria = new List<ContractReviewRuntimeCriterion__c>();
    wrapper.contentDocumentId = null;
    wrapper.contentVersionId = null;
    wrapper.outputSv = null;
    wrapper.outputEng = null;
    wrapper.templateName = null;
    wrapper.fileName = null;
    wrapper.fileExtension = null;
    wrapper.responseDraft = null;
    wrapper.responseDraftEng = null;

    if (reviewId == null) {
      return wrapper;
    }

    try {
      List<ContractReview__c> reviews = [
        SELECT Output_Sv__c, Output_Eng__c, ContractReviewTemplateId__c, ResponseDraft__c, ResponseDraft_Eng__c
        FROM ContractReview__c
        WHERE Id = :reviewId
        WITH USER_MODE
        LIMIT 1
      ];
      if (!reviews.isEmpty()) {
        wrapper.outputSv = reviews[0].Output_Sv__c;
        wrapper.outputEng = reviews[0].Output_Eng__c;
        wrapper.templateName = getTemplateName(
          reviews[0].ContractReviewTemplateId__c
        );
        wrapper.responseDraft = reviews[0].ResponseDraft__c;
        wrapper.responseDraftEng = reviews[0].ResponseDraft_Eng__c;
      }

      wrapper.criteria = [
        SELECT
          Id,
          Name,
          Definition__c,
          CriterionMet__c,
          Extract__c,
          ai_comment__c
        FROM ContractReviewRuntimeCriterion__c
        WHERE ContractReview__c = :reviewId
        WITH USER_MODE
        ORDER BY Name
      ];
      SObjectAccessDecision decision = Security.stripInaccessible(
        AccessType.READABLE,
        wrapper.criteria
      );
      wrapper.criteria = (List<ContractReviewRuntimeCriterion__c>) decision.getRecords();

      List<ContentDocumentLink> fileLinks = [
        SELECT ContentDocumentId
        FROM ContentDocumentLink
        WHERE LinkedEntityId = :reviewId AND ContentDocument.FileExtension IN :SUPPORTED_FILE_EXTENSIONS
        WITH USER_MODE
        ORDER BY SystemModstamp DESC
        LIMIT 1
      ];
      if (!fileLinks.isEmpty()) {
        wrapper.contentDocumentId = fileLinks[0].ContentDocumentId;

        List<ContentVersion> versions = [
          SELECT Id, Title, FileExtension
          FROM ContentVersion
          WHERE
            ContentDocumentId = :wrapper.contentDocumentId
            AND IsLatest = TRUE
          WITH USER_MODE
          LIMIT 1
        ];
        if (!versions.isEmpty()) {
          wrapper.contentVersionId = versions[0].Id;
          wrapper.fileName =
            versions[0].Title + '.' + versions[0].FileExtension;
          wrapper.fileExtension = versions[0].FileExtension;
        }
      }

      return wrapper;
    } catch (Exception e) {
      AuraHandledException ex = new AuraHandledException(e.getMessage());
      ex.setMessage(e.getMessage());
      throw ex;
    }
  }

  /**
   * Manual escape hatch for stuck reviews. Surfaced in the LWC viewer when
   * a review has been in {@code Processing} for more than 10 minutes. Only
   * flips the status; does **not** abort the underlying Queueable (the
   * platform will run it to completion, but the user-visible state is
   * already cleared).
   *
   * Governor-limit note: 1 SOQL + 1 UPDATE DML.
   *
   * @param reviewId The review to cancel.
   * @throws AuraHandledException if the review is missing or not in
   *         {@code Processing} status.
   */
  @AuraEnabled
  public static void cancelStuckReview(Id reviewId) {
    try {
      if (reviewId == null) {
        AuraHandledException e = new AuraHandledException(
          'Review Id is required'
        );
        e.setMessage('Review Id is required');
        throw e;
      }
      List<ContractReview__c> reviews = [
        SELECT Id, Status__c
        FROM ContractReview__c
        WHERE Id = :reviewId
        LIMIT 1
      ];
      if (reviews.isEmpty()) {
        AuraHandledException e = new AuraHandledException(
          'Granskningen hittades inte.'
        );
        e.setMessage('Granskningen hittades inte.');
        throw e;
      }
      if (reviews[0].Status__c != 'Processing') {
        AuraHandledException e = new AuraHandledException(
          'Granskningen är inte i bearbetningsläge.'
        );
        e.setMessage('Granskningen är inte i bearbetningsläge.');
        throw e;
      }
      update new ContractReview__c(
        Id = reviewId,
        Status__c = 'Failure',
        ErrorMessage__c = 'Granskningen avbröts manuellt \u2014 den verkade ha fastnat.'
      );
    } catch (AuraHandledException e) {
      throw e;
    } catch (Exception e) {
      AuraHandledException ex = new AuraHandledException(e.getMessage());
      ex.setMessage(e.getMessage());
      throw ex;
    }
  }

  /**
   * On-demand draft generation — typically used by the LWC to (re)generate
   * the English draft, since only the Swedish one is auto-chained from
   * {@link ContractReviewQueueable}.
   *
   * Governor-limit note: 1 SOQL ({@code WITH USER_MODE}) + 1 enqueueJob.
   * The Einstein callout itself happens inside
   * {@link ContractReviewDraftQueueable}.
   *
   * @param reviewId The review whose draft should be (re)generated.
   * @param language Either {@code 'Svenska'} or {@code 'English'}.
   * @throws AuraHandledException for missing review, unsupported language,
   *         or a review that is not in {@code Success} status.
   */
  @AuraEnabled
  public static void generateDraft(Id reviewId, String language) {
    try {
      if (reviewId == null) {
        AuraHandledException e = new AuraHandledException(
          'Review Id is required'
        );
        e.setMessage('Review Id is required');
        throw e;
      }

      Set<String> allowedLanguages = new Set<String>{ 'Svenska', 'English' };
      if (!allowedLanguages.contains(language)) {
        AuraHandledException e = new AuraHandledException(
          'Unsupported language: ' + language
        );
        e.setMessage('Unsupported language: ' + language);
        throw e;
      }

      List<ContractReview__c> reviews = [
        SELECT Id, Status__c
        FROM ContractReview__c
        WHERE Id = :reviewId
        WITH USER_MODE
        LIMIT 1
      ];
      if (reviews.isEmpty()) {
        AuraHandledException e = new AuraHandledException(
          'Granskningen hittades inte.'
        );
        e.setMessage('Granskningen hittades inte.');
        throw e;
      }
      if (reviews[0].Status__c != 'Success') {
        AuraHandledException e = new AuraHandledException(
          'Granskningen är inte klar.'
        );
        e.setMessage('Granskningen är inte klar.');
        throw e;
      }

      System.enqueueJob(new ContractReviewDraftQueueable(reviewId, language));
    } catch (AuraHandledException e) {
      throw e;
    } catch (Exception e) {
      AuraHandledException ex = new AuraHandledException(e.getMessage());
      ex.setMessage(e.getMessage());
      throw ex;
    }
  }

}