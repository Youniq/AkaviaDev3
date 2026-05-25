/**
 * Invocable selector that powers the file picklist in the
 * {@code ContractReview} Flow. Returns every supported {@link ContentDocument}
 * (PDF, JPG, JPEG, PNG) linked to the Case **or** to one of the Case's
 * {@link EmailMessage}s, deduplicated.
 *
 * Sharing: {@code with sharing} + {@code WITH USER_MODE} on every SOQL so
 * the user only sees files they would normally see in the UI.
 *
 * Governor-limit notes: 3 SOQL per invocation (EmailMessage,
 * ContentDocumentLink, ContentDocument). Bulk-safe across requests — all
 * Case Ids are aggregated before the queries run.
 */
public with sharing class ContractReviewFileSelector {
  @TestVisible
  private static final Set<String> SUPPORTED_EXTENSIONS = new Set<String>{
    'pdf', 'jpg', 'jpeg', 'png'
  };

  public class Request {
    @InvocableVariable(
      required=true
      description='The Id of the Case record'
    )
    public Id caseId;
  }

  public class Response {
    @InvocableVariable(description='Content Documents linked to the Case and its EmailMessages')
    public List<ContentDocument> contentDocuments;
  }

  /**
   * Bulk-safe entry point used by the Flow's Apex action call. The Flow
   * sends one request per execution today, but the implementation aggregates
   * Case Ids across requests so it is safe under bulk Flow execution.
   *
   * Governor-limit hot spot: the three SOQL calls. The final
   * ContentDocument query is filtered to {@code SUPPORTED_EXTENSIONS} so
   * unsupported attachments never reach the picker.
   *
   * @param requests One {@link Request} per Flow invocation.
   * @return One {@link Response} per request, in the same order.
   */
  @InvocableMethod(
    label='Get Case File Options'
    description='Queries ContentDocuments linked to the Case and its related EmailMessages. Returns a deduplicated list suitable for flow picklist choice sets.'
  )
  public static List<Response> getFiles(List<Request> requests) {
    List<Response> results = new List<Response>();

    if (requests == null || requests.isEmpty()) {
      return results;
    }

    // 1. Collect all Case Ids
    Set<Id> allCaseIds = new Set<Id>();
    for (Request req : requests) {
      if (req != null && req.caseId != null) {
        allCaseIds.add(req.caseId);
      }
    }

    // 2. Query EmailMessages for all Cases → build entity-Id map per Case
    Map<Id, Set<Id>> entityIdsByCaseId = new Map<Id, Set<Id>>();
    for (Id caseId : allCaseIds) {
      entityIdsByCaseId.put(caseId, new Set<Id>{ caseId });
    }

    if (!allCaseIds.isEmpty()) {
      for (EmailMessage em : [
        SELECT Id, ParentId
        FROM EmailMessage
        WHERE ParentId IN :allCaseIds
        WITH USER_MODE
      ]) {
        entityIdsByCaseId.get(em.ParentId).add(em.Id);
      }
    }

    // 3. Flatten all entity Ids, query ContentDocumentLinks
    Set<Id> allEntityIds = new Set<Id>();
    for (Set<Id> ids : entityIdsByCaseId.values()) {
      allEntityIds.addAll(ids);
    }

    Map<Id, Set<Id>> docIdsByEntityId = new Map<Id, Set<Id>>();
    if (!allEntityIds.isEmpty()) {
      for (ContentDocumentLink cdl : [
        SELECT ContentDocumentId, LinkedEntityId
        FROM ContentDocumentLink
        WHERE LinkedEntityId IN :allEntityIds
        WITH USER_MODE
      ]) {
        if (!docIdsByEntityId.containsKey(cdl.LinkedEntityId)) {
          docIdsByEntityId.put(cdl.LinkedEntityId, new Set<Id>());
        }
        docIdsByEntityId.get(cdl.LinkedEntityId).add(cdl.ContentDocumentId);
      }
    }

    // 4. Collect all unique doc Ids, query ContentDocuments
    Set<Id> allDocIds = new Set<Id>();
    for (Set<Id> ids : docIdsByEntityId.values()) {
      allDocIds.addAll(ids);
    }

    Map<Id, ContentDocument> docsById = new Map<Id, ContentDocument>();
    if (!allDocIds.isEmpty()) {
      for (ContentDocument doc : [
        SELECT Id, Title, FileExtension, ContentSize, CreatedDate
        FROM ContentDocument
        WHERE Id IN :allDocIds AND FileExtension IN :SUPPORTED_EXTENSIONS
        WITH USER_MODE
      ]) {
        docsById.put(doc.Id, doc);
      }
    }

    // 5. Map back per request
    for (Request req : requests) {
      Response res = new Response();

      if (req == null || req.caseId == null || !entityIdsByCaseId.containsKey(req.caseId)) {
        res.contentDocuments = new List<ContentDocument>();
      } else {
        Set<Id> dedupedDocIds = new Set<Id>();
        for (Id entityId : entityIdsByCaseId.get(req.caseId)) {
          Set<Id> entityDocIds = docIdsByEntityId.get(entityId);
          if (entityDocIds != null) {
            dedupedDocIds.addAll(entityDocIds);
          }
        }

        List<ContentDocument> docs = new List<ContentDocument>();
        for (Id docId : dedupedDocIds) {
          ContentDocument doc = docsById.get(docId);
          if (doc != null) {
            docs.add(doc);
          }
        }
        res.contentDocuments = docs;
      }

      results.add(res);
    }

    return results;
  }
}