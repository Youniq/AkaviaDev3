/**
 * Invocable selector that serialises a review's runtime criteria as JSON for
 * direct embedding into Einstein Prompt Templates via the
 * {@code {!$Apex:ContractReviewCriterionSelector.Prompt}} merge field. This
 * is the primary way the LLM learns *which* criteria it must evaluate for a
 * given review.
 *
 * Sharing: {@code with sharing}. Returns {@code '[]'} when no criteria are
 * found so the prompt template does not break on a null merge.
 *
 * Governor-limit notes: 1 SOQL per invocation; bulk-safe.
 */
public with sharing class ContractReviewCriterionSelector {
  public class Request {
    @InvocableVariable(
      required=true
      description='The Id of the ContractReview__c record'
    )
    public Id contractReviewId;
  }

  public class Response {
    @InvocableVariable
    public String Prompt;
  }

  /**
   * Aggregates criteria across all input review Ids in one SOQL, then maps
   * the JSON back to each request preserving order.
   *
   * @param requests One {@link Request} per prompt template invocation.
   * @return One {@link Response} per request, with {@code Prompt} set to a
   *         JSON array (possibly {@code '[]'}).
   */
  @InvocableMethod(
    label='Get Contract Review Criteria'
    description='Queries ContractReviewRuntimeCriterion__c records for a given ContractReview__c Id and returns them as serialized JSON.'
  )
  public static List<Response> getCriteria(List<Request> requests) {
    List<Response> results = new List<Response>();

    if (requests == null || requests.isEmpty()) {
      return results;
    }

    Set<Id> reviewIds = new Set<Id>();
    for (Request req : requests) {
      if (req != null && req.contractReviewId != null) {
        reviewIds.add(req.contractReviewId);
      }
    }

    Map<Id, List<ContractReviewRuntimeCriterion__c>> criteriaByReview = new Map<Id, List<ContractReviewRuntimeCriterion__c>>();
    if (!reviewIds.isEmpty()) {
      for (ContractReviewRuntimeCriterion__c c : [
        SELECT Id, Name, Definition__c, ContractReview__c
        FROM ContractReviewRuntimeCriterion__c
        WHERE ContractReview__c IN :reviewIds
        ORDER BY Name
      ]) {
        if (!criteriaByReview.containsKey(c.ContractReview__c)) {
          criteriaByReview.put(c.ContractReview__c, new List<ContractReviewRuntimeCriterion__c>());
        }
        criteriaByReview.get(c.ContractReview__c).add(c);
      }
    }

    for (Request req : requests) {
      Response res = new Response();

      if (req == null || req.contractReviewId == null) {
        res.Prompt = '[]';
      } else {
        List<ContractReviewRuntimeCriterion__c> criteria = criteriaByReview.get(req.contractReviewId);
        res.Prompt = criteria != null ? JSON.serialize(criteria) : '[]';
      }

      results.add(res);
    }

    return results;
  }
}