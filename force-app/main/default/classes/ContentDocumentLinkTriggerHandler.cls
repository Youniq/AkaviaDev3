/**
 * This launches Flow and passes ContentVersionId etc.
 */
public with sharing class ContentDocumentLinkTriggerHandler {
  public void handleAfterInsert(
    List<ContentDocumentLink> newList,
    Map<ID, ContentDocumentLink> newMap
  ) {
    System.debug('ContentDocumentLinkTriggerHandler.afterInsert');

    Set<ID> contentDocumentIds = new Set<ID>();
    for (ContentDocumentLink cdl : newList) {
      contentDocumentIds.add(cdl.ContentDocumentId);
    }

    List<ContentDocumentLink> cdls = new List<ContentDocumentLink>(
      [
        SELECT
          Id,
          LinkedEntityId,
          ContentDocumentId,
          ContentDocument.LatestPublishedVersionId,
          Visibility
        FROM ContentDocumentLink
        WHERE
          Id IN :newList
          AND ContentDocumentId IN :contentDocumentIds
      ]
    );

    for (ContentDocumentLink cdl : cdls) {
      Map<String, Object> inputs = new Map<String, Object>{
        'varContentDocumentLinkId' => cdl.Id,
        'varRecordId' => cdl.LinkedEntityId,
        'varContentDocumentId' => cdl.ContentDocumentId,
        'varContentVersionId' => cdl.ContentDocument.LatestPublishedVersionId,
        'varContentDocumentLinkVisibility' => cdl.Visibility
      };

      Flow.Interview myFlow = Flow.Interview.createInterview(
        'Handle_File_Shared_To_Record_Flow',
        inputs
      );
      myFlow.start();
    }
  }
}
