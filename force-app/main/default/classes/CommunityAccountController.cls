public with sharing class CommunityAccountController {

    @AuraEnabled(cacheable=false)
    public static Boolean updateAccount(Account account) {
      try {
          update account;
          return true; 
      } catch (Exception e) {
        throw new AuraHandledException(e.getMessage());
      }
    }
}