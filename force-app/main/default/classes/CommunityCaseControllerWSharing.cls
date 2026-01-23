/**
 * @description       :
 * @author            : Malin Nilsson (Stretch Customer AB)
 * @group             :
 * @last modified on  : 2023-10-25
 * @last modified by  : Malin Nilsson (Stretch Customer AB)
 **/
public with sharing class CommunityCaseControllerWSharing {
  @AuraEnabled
  public static CommunityCaseModel getCase(String caseId) {
    try {
      Case currCase = [
        SELECT
          CaseNumber,
          CategoryCommunity__c,
          Status,
          Subject,
          CreatedDate,
          Owner.Name,
          Owner.FirstName,
          Owner.LastName,
          OwnerId,
          Type,
          RecordTypeId,
          (SELECT ContentDocumentId FROM ContentDocumentLinks)
        FROM Case
        WHERE Id = :caseId
      ];

      User ownerOOO = CommunityCaseController.getOwnerOOO(currCase.OwnerId);
      CommunityCaseModel communityCase;
      if (ownerOOO != null) {
        communityCase = new CommunityCaseModel(
          currCase,
          ownerOOO.IsOutOfOffice__c,
          ownerOOO.OutOfOfficeAutoResponderText__c
        );
      } else {
        communityCase = new CommunityCaseModel(currCase);
      }
      return communityCase;
    } catch (Exception e) {
      System.debug(
        'Error in CommunityCaseControllerWSharing.getCase(' +
        caseId +
        ')'
      );
      System.debug(e.getMessage());
      System.debug(e.getStackTraceString());
      return null;
    }
  }

  @AuraEnabled
  public static List<ContentVersion> getFilesContentVersion(
    List<String> contentDocIds
  ) {
    List<ContentVersion> docs = [
      SELECT ContentDocumentId, FileExtension, Title
      FROM ContentVersion
      WHERE ContentDocumentId IN :contentDocIds
    ];
    return docs;
  }

  /**
   * @description - Fetches case records for a member to be displayed in the portal.
   * @param accountId - member account ID
   * @return List<Case>
   **/
  @AuraEnabled
  public static List<Case> getAccountCases(String accountId) {
    List<Case> cases = [
      SELECT
        Id,
        AccountId,
        CaseNumber,
        CategoryCommunity__c,
        Status,
        Type,
        CreatedDate
      FROM Case
      WHERE
        AccountId = :accountId
        AND HideForMember__c = FALSE
        AND Status != 'Sammanslagen'
      ORDER BY CreatedDate DESC
    ];
    return cases;
  }

  @AuraEnabled
  public static Case getAccountNewestCase(String accountId) {
    List<Case> cases = [
      SELECT Id, CaseNumber
      FROM Case
      WHERE AccountId = :accountId AND HideForMember__c = FALSE
      ORDER BY CreatedDate DESC
      LIMIT 1
    ];

    if (cases.size() > 0) {
      return cases[0];
    }
    return null;
  }

  @AuraEnabled(cacheable=false)
  public static Boolean createNewCase(Case caseRecord) {
    try {
      insert caseRecord;
      return true;
    } catch (Exception e) {
      throw new AuraHandledException(e.getMessage());
    }
  }

  /**
   * Gets the id for RecordType where DeveloperName = input
   */
  @AuraEnabled(cacheable=true)
  public static String getCaseRecordTypeIdByDeveloperName(
    string developerName
  ) {
    List<RecordType> recordTypes = [
      SELECT Id
      FROM RecordType
      WHERE SObjectType = 'Case' AND DeveloperName = :developerName
      LIMIT 1
    ];

    if (recordTypes.size() > 0) {
      return recordTypes[0].Id;
    }
    throw new AuraHandledException(
      'Could not find a record type for the given developer name.'
    );
  }

  /**
   * Gets the Name for RecordType where Id = input
   */
  @AuraEnabled(cacheable=true)
  public static List<RecordType> getCaseRecordTypeNameById(
    string recordTypeId
  ) {
    List<RecordType> recordType = [
      SELECT Name
      FROM RecordType
      WHERE SObjectType = 'Case' AND Id = :recordTypeId
      LIMIT 1
    ];
    return recordType;
  }

  /**
   * Add comment to case / FeedItem
   */
  @AuraEnabled
  public static FeedItem addFeedItemToCase(String caseId, String comment) {
    try {
      FeedItem feedItem = new FeedItem(
        ParentId = caseId,
        Body = comment,
        Visibility = 'AllUsers'
      );
      insert feedItem;
      return feedItem;
    } catch (Exception e) {
      throw new AuraHandledException(e.getMessage());
    }
  }
}