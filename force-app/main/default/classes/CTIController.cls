public without sharing class CTIController {
  @AuraEnabled
  public static String getPersonContactId(String ssn) {
    String acctId = null;
    List<Account> acctList = [
      SELECT id
      FROM Account
      WHERE SocialSecurityNumber__c = :ssn
    ];
    if (acctList.size() > 0) {
      acctId = acctList[0].Id;
    }
    return acctId;
  }
}