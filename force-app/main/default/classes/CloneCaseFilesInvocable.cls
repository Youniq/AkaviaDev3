/**
 * @description       : NO LONGER USEd. Has been replaced with 100% flow.
 *                      An invocable action enabling users to copy files from one case to another.
 * @author            : Malin Nilsson (Stretch Customer AB)
 * @group             :
 * @last modified on  : 2024-03-21
 * @last modified by  : Malin Nilsson (Stretch Customer AB)
 **/
public with sharing class CloneCaseFilesInvocable {
  // public class Request {
  //   @InvocableVariable(
  //     label='Source Case Id'
  //     description='The Id of the case where you want to copy file/files from.'
  //     required='true'
  //   )
  //   public String fromCaseId;

  //   @InvocableVariable(
  //     label='Destination Case Id'
  //     description='The Id of the case where you want to send the files.'
  //     required='true'
  //   )
  //   public String toCaseId;

  //   @InvocableVariable(
  //     label='List of Content Document Ids'
  //     description='The contentDocumentIds of the files you wish to clone to another case.'
  //     required='true'
  //   )
  //   public List<String> contentDocumentIds;

  //   @InvocableVariable(
  //     label='Visibility: all users (True/False)'
  //     description='Expects a boolean value. \n If True: Shares the documents with all users that have access (incl. members). If False: Documents is shared with Akavia users only (Visibility: internal users).'
  //     required='true'
  //   )
  //   public Boolean publicVisibilty;
  // }

  // @InvocableMethod(label='Clone file/files between cases')
  // public static void CloneFilesBetweenCases(
  //   List<CloneCaseFilesInvocable.Request> requests
  // ) {
  //   for (CloneCaseFilesInvocable.Request req : requests) {
  //     if (req.contentDocumentIds != null && req.contentDocumentIds.size() > 0) {
  //       // Clone files
  //       List<ContentDocumentLink> toBeCloned = [
  //         SELECT
  //           ContentDocumentId,
  //           Id,
  //           IsDeleted,
  //           LinkedEntityId,
  //           ShareType,
  //           SystemModstamp,
  //           Visibility
  //         FROM ContentDocumentLink
  //         WHERE
  //           LinkedEntityId = :req.fromCaseId
  //           AND ContentDocumentId IN :req.contentDocumentIds
  //       ];

  //       String visibilityVal = req.publicVisibilty
  //         ? 'AllUsers'
  //         : 'InternalUsers';

  //       cloneFiles(toBeCloned, req.toCaseId, visibilityVal);
  //     } else {
  //       throw new AuraHandledException(
  //         'You have not selected any files to copy.'
  //       );
  //     }
  //   }
  // }

  // private static void cloneFiles(
  //   List<ContentDocumentLink> toBeClonedContentDocumentLinks,
  //   String newCaseId,
  //   String visibilityValue
  // ) {
  //   for (ContentDocumentLink cdl : toBeClonedContentDocumentLinks) {
  //     cdl.Id = null;
  //     cdl.LinkedEntityId = newCaseId;
  //     cdl.Visibility = visibilityValue;
  //   }

  //   try {
  //     insert toBeClonedContentDocumentLinks;
  //   } catch (Exception e) {
  //     System.debug(
  //       'Error in CloneCaseFilesInvocable.CloneFilesBetweenCases(). Message: ' +
  //       e.getMessage()
  //     );
  //     throw e;
  //   }
  // }
}