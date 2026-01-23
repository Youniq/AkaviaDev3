/**
 * @description       :
 * @author            : Malin Nilsson (Stretch Customer AB)
 * @group             :
 * @last modified on  : 2025-01-28
 * @last modified by  : Malin Nilsson (Stretch Customer AB)
 **/
public class McSyncLeftoverHelper {
  /**
   * @description - Get query for collecting Employments where SyncWithMc__c does not have the correct value (which is found in MC_validator__c)
   * @author Malin Nilsson (Stretch Customer AB) | 2024-03-12
   * @return String
   **/
  public static String employmentsQuery(Integer qLimit, String accId) {

      System.debug('found accID: ' + accId);

    String queryLimit = qLimit != null ? ' LIMIT ' + qLimit : '';
    String accountFilter = accId != null ? ' Person__c = \'' + accId + '\' AND' : '';
    String q = 'SELECT Id, SyncWithMc__c' +
      ' FROM Employment__c' +
      ' WHERE' +
      accountFilter +
      ' ((SyncWithMc__c = FALSE' +
      ' AND MC_validator__c = TRUE)' +
      ' OR (SyncWithMc__c = TRUE' +
      ' AND MC_validator__c = FALSE))' + 
      queryLimit;

      System.debug('employmentsq: ' + q);

      return q;
  }

  /**
   * @description - Get query for collecting Memberships where SyncWithMc__c does not have the correct value (which is found in MC_validator__c)
   * @author Malin Nilsson (Stretch Customer AB) | 2024-03-12
   * @return String
   **/
  public static String membershipsQuery(Integer qLimit, String accId) {
    String queryLimit = qLimit != null ? ' LIMIT ' + qLimit : '';
    String accountFilter = accId != null ? ' Person__c = \'' + accId + '\' AND' : '';

    String q = 'SELECT Id, SyncWithMc__c' +
      ' FROM Membership__c' +
      ' WHERE' +
       accountFilter +
      ' ((SyncWithMc__c = FALSE' +
      ' AND MC_validator__c = TRUE)' +
      ' OR (SyncWithMc__c = TRUE' +
      ' AND MC_validator__c = FALSE))' +
      queryLimit;

      System.debug('membershipsq: ' + q);
      return q;
  }

  /**
   * @description - Get query for collecting Applications where SyncWithMc__c does not have the correct value (which is found in MC_validator__c)
   * @author Malin Nilsson (Stretch Customer AB) | 2024-03-12
   * @return String
   **/
  public static String applicationsQuery(Integer qLimit, String accId) {
    String queryLimit = qLimit != null ? ' LIMIT ' + qLimit : '';
    String accountFilter = accId != null ? ' Person__c = \'' + accId + '\' AND' : '';
    
    String q = 'SELECT Id, SyncWithMc__c' +
      ' FROM Application__c' +
      ' WHERE' +
      accountFilter +
      ' ((SyncWithMc__c = FALSE' +
      ' AND MC_validator__c = TRUE)' +
      ' OR (SyncWithMc__c = TRUE' +
      ' AND MC_validator__c = FALSE))' +
      queryLimit;


      System.debug('applicationsq: ' + q);
      return q;
  }

  /**
   * @description - Get query for collecting Assignments where SyncWithMc__c does not have the correct value (which is found in MC_validator__c)
   * @author Malin Nilsson (Stretch Customer AB) | 2024-03-12
   * @return String
   **/
  public static String assignmentsQuery(Integer qLimit, String accId) {
    String queryLimit = qLimit != null ? ' LIMIT ' + qLimit : '';
    String accountFilter = accId != null ? ' Person__c = \'' + accId + '\' AND' : '';

    String q = 'SELECT Id, SyncWithMc__c' +
      ' FROM Assignment__c' +
      ' WHERE' +
      accountFilter +
      ' ((SyncWithMc__c = FALSE' +
      ' AND MC_validator__c = TRUE)' +
      ' OR (SyncWithMc__c = TRUE' +
      ' AND MC_validator__c = FALSE))' +
      queryLimit;


      System.debug('assignmentsq: ' + q);
      return q;
  }

  /**
   * @description - Get query for collecting Invoices where SyncWithMc__c does not have the correct value (which is found in MC_validator__c)
   * @author Malin Nilsson (Stretch Customer AB) | 2024-03-12
   * @return String
   **/
  // public static String invoicesQuery(Integer qLimit, String accId) {
  //   String queryLimit = qLimit != null ? ' LIMIT ' + qLimit : '';
  //   String accountFilter = accId != null ? ' Person__c = \'' + accId + '\' AND' : '';

  //   String q = 'SELECT Id, SyncWithMc__c' +
  //     ' FROM Invoice__c' +
  //     ' WHERE' +
  //     accountFilter +
  //     ' ((SyncWithMc__c = FALSE' +
  //     ' AND MC_validator__c = TRUE)' +
  //     ' OR (SyncWithMc__c = TRUE' +
  //     ' AND MC_validator__c = FALSE))' +
  //     queryLimit;


  //     System.debug('invoicesQuery: ' + q);
  //     return q;
  // }

  public static String membershipBenefitQuery(Integer qLimit, String accId) {
    String queryLimit = qLimit != null ? ' LIMIT ' + qLimit : '';
    String accountFilter = accId != null ? ' Person__c = \'' + accId + '\' AND' : '';

    String q= 'SELECT Id, SyncWithMc__c' +
      ' FROM MembershipBenefit__c' +
      ' WHERE' +
      accountFilter +
      ' ((SyncWithMc__c = FALSE' +
      ' AND MC_validator__c = TRUE)' +
      ' OR (SyncWithMc__c = TRUE' +
      ' AND MC_validator__c = FALSE))' +
      queryLimit;


      System.debug('membershipBenefitq: ' + q);
      return q;
  }

  public static String campaignMembersQuery(Integer qLimit, String accId) {
    String queryLimit = qLimit != null ? ' LIMIT ' + qLimit : '';
    String accountFilter = accId != null ? ' Contact.Account.Id = \'' + accId + '\' AND' : '';

    String q = 'SELECT Id, SyncWithMc__c' +
      ' FROM CampaignMember' +
      ' WHERE' +
      accountFilter +
      ' ((SyncWithMc__c = FALSE' +
      ' AND MC_validator__c = TRUE)' +
      ' OR (SyncWithMc__c = TRUE' +
      ' AND MC_validator__c = FALSE))' +
      queryLimit;

    System.debug('campaignMembersq: ' + q);
    return q;
  }
}