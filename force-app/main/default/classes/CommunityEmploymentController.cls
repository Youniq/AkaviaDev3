public without sharing class CommunityEmploymentController {
  @AuraEnabled(cacheable=true)
  public static List<Employment__c> getUsersActiveEmployment(String accountId) {
    List<Employment__c> employments;
    employments = [
      SELECT
        Id,
        Manager__c,
        EndDate__c,
        Workplace__c,
        Workplace__r.Name,
        Workplace__r.Parent.Name,
        Workplace__r.Parent.OrganisationNumber__c
      FROM Employment__c
      WHERE Person__c = :accountId AND Status__c = 'Aktiv'
      LIMIT 1
    ];
    return employments;
  }

  @AuraEnabled(cacheable=false)
  public static Boolean updateEmployment(Employment__c employment) {
    try {
      update employment;
      return true;
    } catch (Exception e) {
      throw new AuraHandledException(e.getMessage());
    }
  }

  @AuraEnabled(cacheable=true)
  public static List<Account> searchEmployers(string searchInput) {
    string queryString = '%' + searchInput + '%';
    List<Account> searchResult = [
      SELECT Name, OrganisationNumber__c
      FROM Account
      WHERE
        RecordTypeName__c = 'Employer'
        AND Status__c = 'Aktiv'
        AND OrganisationNumber__c != '0'
        AND Name LIKE :queryString
    ];
    return searchResult;
  }

  @AuraEnabled(cacheable=true)
  public static List<Account> getCompanyWorkplaces(string accountId) {
    List<Account> workplaces = [
      SELECT Name, ShippingCity
      FROM Account
      WHERE ParentId = :accountId AND Status__c = 'Aktiv'
    ];
    return workplaces;
  }

  @AuraEnabled(cacheable=false)
  public static String createNewEmployment(Employment__c empRecord) {
    try {
      insert empRecord;
      return empRecord.Id;
    } catch (Exception e) {
      throw new AuraHandledException(e.getMessage());
    }
  }
}