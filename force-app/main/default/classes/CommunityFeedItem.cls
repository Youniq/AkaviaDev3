/**
 * Feed post for Mina sidor, including per-member read/unread status.
 * FeedItem cannot have custom fields, so isRead is resolved from FeedRead__c.
 */
public with sharing class CommunityFeedItem {
  @AuraEnabled
  public Id Id { get; set; }

  @AuraEnabled
  public Id ParentId { get; set; }

  @AuraEnabled
  public String Body { get; set; }

  @AuraEnabled
  public Datetime CreatedDate { get; set; }

  @AuraEnabled
  public Id CreatedById { get; set; }

  @AuraEnabled
  public CreatedByUser CreatedBy { get; set; }

  @AuraEnabled
  public String Visibility { get; set; }

  @AuraEnabled
  public String Type { get; set; }

  @AuraEnabled
  public Id RelatedRecordId { get; set; }

  @AuraEnabled
  public String caseNumber { get; set; }

  @AuraEnabled
  public String caseSubject { get; set; }

  @AuraEnabled
  public Boolean isRead { get; set; }

  public class CreatedByUser {
    @AuraEnabled
    public String FirstName { get; set; }

    @AuraEnabled
    public String LastName { get; set; }

    @AuraEnabled
    public Id AccountId { get; set; }
  }
}