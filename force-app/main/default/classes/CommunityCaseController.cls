/**
 * @description       :
 * @author            : Malin Nilsson (Stretch Customer AB)
 * @group             :
 * @last modified on  : 2023-10-25
 * @last modified by  : Malin Nilsson (Stretch Customer AB)
 **/
public without sharing class CommunityCaseController {
  @AuraEnabled
  public static List<CaseComment> getCaseComments(String caseId) {
    List<CaseComment> caseComments = [
      SELECT
        Id,
        ParentId,
        IsPublished,
        CommentBody,
        CreatedDate,
        CreatedBy.Name,
        CreatedBy.ProfileId,
        LastModifiedDate,
        LastModifiedById
      FROM CaseComment
      WHERE ParentId = :caseId
      ORDER BY CreatedDate DESC
    ];
    return caseComments;
  }

  @AuraEnabled
  public static CaseComment addCaseComment(String caseId, String commentBody) {
    try {
      CaseComment caseComment = new CaseComment(
        ParentId = caseId,
        CommentBody = commentBody
      );
      insert caseComment;
      return caseComment;
    } catch (Exception e) {
      throw new AuraHandledException(e.getMessage());
    }
  }

  @AuraEnabled
  public static List<CaseFeed> getFeedItemsByCase(String caseId) {
    List<CaseFeed> feedItems = [
      SELECT
        Id,
        ParentId,
        Body,
        CreatedDate,
        CreatedBy.FirstName,
        CreatedBy.LastName,
        Visibility
      FROM CaseFeed
      WHERE
        ParentId = :caseId
        AND (Type = 'TextPost'
        OR Type = 'ContentPost')
        AND Visibility = 'AllUsers'
      ORDER BY CreatedDate DESC
    ];
    return feedItems;
  }

  /**
   * Gets sub comments on case feed items.
   */
  @AuraEnabled
  public static List<FeedComment> getSubCommentByCase(String caseId) {
    List<FeedComment> feedComment = [
      SELECT
        Id,
        CommentBody,
        CreatedDate,
        CreatedBy.FirstName,
        CreatedBy.LastName,
        FeedItemId,
        Status
      FROM FeedComment
      WHERE
        ParentId = :caseId
        AND (CommentType = 'TextComment'
        OR CommentType = 'ContentComment')
        AND FeedItemId IN (
          SELECT id
          FROM FeedItem
          WHERE
            Visibility = 'AllUsers'
            AND (Type = 'TextPost'
            OR Type = 'ContentPost')
        )
      ORDER BY CreatedDate DESC
    ];
    return feedComment;
  }

  /**
   * Gets the case owners out of office information.
   * This methods test is initiated from the CommunityCaseControllerWSharing.TestGetCaseWithOwnerOOO().
   */
  @AuraEnabled
  public static User getOwnerOOO(String ownerId) {
    User ownerOooInfo;

    // Check that the case owner is a user and not a queue.
    if (ownerId.startsWith('005')) {
      try {
        ownerOooInfo = [
          SELECT IsOutOfOffice__c, OutOfOfficeAutoResponderText__c
          FROM User
          WHERE Id = :ownerId
        ];
      } catch (Exception e) {
        // Logg errors but don't stop the application just because we didn't get the ooo msg.
        System.debug(
          'Error in CommunityCaseController.getOwnerOOO(' +
          ownerId +
          ')'
        );
        System.debug(e.getMessage());
        System.debug(e.getStackTraceString());
      }
    }
    return ownerOooInfo;
  }

  /**
   * @description - Retrieves the metadata settings deciding the component behaviour
   * @return List<PortalQuickCaseSetting__mdt> - The list of settings.
   **/
  @AuraEnabled
  public static List<PortalQuickCaseSetting__mdt> getActiveQuickCaseSettings() {
    try {
      List<PortalQuickCaseSetting__mdt> quickCaseSettings = [
        SELECT
          CategoryApiName__c,
          RecordTypeDeveloperName__c,
          Reason__c,
          Type__c,
          Priority__c,
          BottomInformationSV__c,
          BottomInformationEN__c,
          Description__c,
          NoInputFromUser__c
        FROM PortalQuickCaseSetting__mdt
        WHERE Status__c = 'Aktiv'
      ];

      return quickCaseSettings;
    } catch (Exception e) {
      throw new AuraHandledException(e.getMessage());
    }
  }
}