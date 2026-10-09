/**
 * Read/unread status for case feed posts on Mina sidor.
 */
public without sharing class CommunityFeedReadService {
  private static final Integer DEFAULT_FEED_LIMIT = 50;
  private static final Integer MAX_FEED_LIMIT = 200;

  public static Id getCurrentUserAccountId() {
    User runningUser = [
      SELECT AccountId
      FROM User
      WHERE Id = :UserInfo.getUserId()
      LIMIT 1
    ];
    return runningUser.AccountId;
  }

  public static String uniqueKey(Id accountId, String feedItemId) {
    return String.valueOf(accountId) + '-' + normalizeFeedItemId(feedItemId);
  }

  public static String normalizeFeedItemId(String feedItemId) {
    if (String.isBlank(feedItemId)) {
      return null;
    }
    try {
      return String.valueOf((Id) feedItemId.trim());
    } catch (Exception ex) {
      return feedItemId.trim();
    }
  }

  public static List<CommunityFeedItem> getFeedItemsByCase(
    String caseId,
    Id accountId
  ) {
    return getFeedItemsByCase(caseId, accountId, null);
  }

  public static List<CommunityFeedItem> getFeedItemsByCase(
    String caseId,
    Id accountId,
    Integer rowLimit
  ) {
    if (String.isBlank(caseId)) {
      return new List<CommunityFeedItem>();
    }
    return queryVisibleFeeds(
      getVisibleCases(accountId, caseId),
      accountId,
      rowLimit
    );
  }

  public static List<CommunityFeedItem> getFeedItemsForMember(Id accountId) {
    return getFeedItemsForMember(accountId, null);
  }

  public static List<CommunityFeedItem> getFeedItemsForMember(
    Id accountId,
    Integer rowLimit
  ) {
    if (accountId == null) {
      return new List<CommunityFeedItem>();
    }
    return queryVisibleFeeds(
      getVisibleCases(accountId, null),
      accountId,
      rowLimit
    );
  }

  private static List<Case> getVisibleCases(Id accountId, String caseId) {
    if (String.isNotBlank(caseId)) {
      if (accountId == null) {
        return [
          SELECT Id, CaseNumber, Subject
          FROM Case
          WHERE Id = :caseId AND HideForMember__c = FALSE
          LIMIT 1
        ];
      }
      return [
        SELECT Id, CaseNumber, Subject
        FROM Case
        WHERE
          Id = :caseId
          AND HideForMember__c = FALSE
          AND AccountId = :accountId
        LIMIT 1
      ];
    }
    return [
      SELECT Id, CaseNumber, Subject
      FROM Case
      WHERE
        AccountId = :accountId
        AND HideForMember__c = FALSE
        AND Status != 'Sammanslagen'
      ORDER BY CreatedDate DESC
    ];
  }

  private static List<CommunityFeedItem> queryVisibleFeeds(
    List<Case> visibleCases,
    Id accountId,
    Integer rowLimit
  ) {
    if (visibleCases == null || visibleCases.isEmpty()) {
      return new List<CommunityFeedItem>();
    }

    Map<Id, Case> casesById = new Map<Id, Case>(visibleCases);
    Set<Id> caseIds = casesById.keySet();
    Integer resolvedLimit = resolveLimit(rowLimit);

    List<FeedItem> feeds = [
      SELECT
        Id,
        ParentId,
        Body,
        CreatedDate,
        CreatedById,
        CreatedBy.FirstName,
        CreatedBy.LastName,
        Visibility,
        Type,
        RelatedRecordId
      FROM FeedItem
      WHERE
        ParentId IN :caseIds
        AND (Type = 'TextPost'
        OR Type = 'ContentPost')
        AND Visibility = 'AllUsers'
      ORDER BY CreatedDate DESC
      LIMIT :resolvedLimit
    ];

    Set<String> feedItemIds = new Set<String>();
    Set<Id> createdByIds = new Set<Id>();
    for (FeedItem feed : feeds) {
      feedItemIds.add(String.valueOf(feed.Id));
      createdByIds.add(feed.CreatedById);
    }

    Map<Id, User> createdByUsers = new Map<Id, User>();
    if (!createdByIds.isEmpty()) {
      createdByUsers = new Map<Id, User>(
        [
          SELECT Id, AccountId, FirstName, LastName
          FROM User
          WHERE Id IN :createdByIds
        ]
      );
    }

    Map<String, Boolean> readByFeedItemId = getReadMap(accountId, feedItemIds);
    List<CommunityFeedItem> result = new List<CommunityFeedItem>();
    for (FeedItem feed : feeds) {
      result.add(
        toFeedItem(
          feed,
          casesById.get(feed.ParentId),
          createdByUsers.get(feed.CreatedById),
          accountId,
          readByFeedItemId
        )
      );
    }
    return result;
  }

  private static Integer resolveLimit(Integer rowLimit) {
    if (rowLimit == null || rowLimit <= 0) {
      return DEFAULT_FEED_LIMIT;
    }
    return Math.min(rowLimit, MAX_FEED_LIMIT);
  }

  public static void setReadStatus(
    List<String> feedItemIds,
    Id accountId,
    Boolean isRead
  ) {
    if (accountId == null || feedItemIds == null || feedItemIds.isEmpty()) {
      return;
    }

    Boolean readValue = isRead == null ? true : isRead;
    Map<String, FeedRead__c> existingByKey = new Map<String, FeedRead__c>();
    Set<String> normalizedIds = new Set<String>();
    for (String feedItemId : feedItemIds) {
      String normalized = normalizeFeedItemId(feedItemId);
      if (String.isNotBlank(normalized)) {
        normalizedIds.add(normalized);
      }
    }
    if (normalizedIds.isEmpty()) {
      return;
    }

    for (FeedRead__c existing : [
      SELECT Id, UniqueKey__c, IsRead__c, FeedItemId__c
      FROM FeedRead__c
      WHERE
        Person__c = :accountId
        AND FeedItemId__c IN :normalizedIds
    ]) {
      existingByKey.put(existing.UniqueKey__c, existing);
    }

    List<FeedRead__c> toUpsert = new List<FeedRead__c>();
    for (String feedItemId : normalizedIds) {
      String key = uniqueKey(accountId, feedItemId);
      FeedRead__c record = existingByKey.get(key);
      if (record == null) {
        record = new FeedRead__c(
          Person__c = accountId,
          FeedItemId__c = feedItemId,
          UniqueKey__c = key
        );
      }
      record.IsRead__c = readValue;
      toUpsert.add(record);
    }

    upsert toUpsert UniqueKey__c;
  }

  private static Map<String, Boolean> getReadMap(
    Id accountId,
    Set<String> feedItemIds
  ) {
    Map<String, Boolean> readByFeedItemId = new Map<String, Boolean>();
    if (accountId == null || feedItemIds == null || feedItemIds.isEmpty()) {
      return readByFeedItemId;
    }

    for (FeedRead__c record : [
      SELECT FeedItemId__c, IsRead__c
      FROM FeedRead__c
      WHERE Person__c = :accountId AND FeedItemId__c IN :feedItemIds
    ]) {
      readByFeedItemId.put(record.FeedItemId__c, record.IsRead__c);
    }
    return readByFeedItemId;
  }

  private static CommunityFeedItem toFeedItem(
    FeedItem feed,
    Case parentCase,
    User createdByUser,
    Id accountId,
    Map<String, Boolean> readByFeedItemId
  ) {
    CommunityFeedItem item = new CommunityFeedItem();
    item.Id = feed.Id;
    item.ParentId = feed.ParentId;
    item.Body = feed.Body;
    item.CreatedDate = feed.CreatedDate;
    item.CreatedById = feed.CreatedById;
    item.Visibility = feed.Visibility;
    item.Type = feed.Type;
    item.RelatedRecordId = feed.RelatedRecordId;
    if (parentCase != null) {
      item.caseNumber = parentCase.CaseNumber;
      item.caseSubject = parentCase.Subject;
    }
    item.CreatedBy = new CommunityFeedItem.CreatedByUser();
    item.CreatedBy.FirstName = feed.CreatedBy.FirstName;
    item.CreatedBy.LastName = feed.CreatedBy.LastName;
    Id createdByAccountId = createdByUser == null
      ? null
      : createdByUser.AccountId;
    item.CreatedBy.AccountId = createdByAccountId;

    Boolean isOwnPost =
      feed.CreatedById == UserInfo.getUserId() ||
      (accountId != null && createdByAccountId == accountId);
    item.isRead = isOwnPost;
    if (readByFeedItemId.containsKey(String.valueOf(feed.Id))) {
      item.isRead = readByFeedItemId.get(String.valueOf(feed.Id));
    }
    return item;
  }
}