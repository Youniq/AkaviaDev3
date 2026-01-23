/* @Author Jenny Blomberg
 * Generic helper to help testdatafactory in Test calsses
 */
public with sharing class TestDataFactorySetupParams {
  public Integer numberOfAccounts; //Member accounts
  public boolean addMembershipsToMembers;
  public Date membershipStartDate;
  public boolean addStudentFeeCategoryToMemberships;
  public boolean addYrkesverksamFeeCategoryToMemberships;
  public boolean addAssignmentToMembers;
  public Date assignmentStartDate;
  public boolean addEmploymentsToMembers;
  public boolean addMembershipBenefitsToMembers;
  public Integer numberOfCallouts;
  public Integer numberOfBenefits;
  public String calloutPath;
  public String calloutStatus;
  public String calloutType;
  public boolean studentAccounts = false;
  public boolean cancelledAccounts = false; //remove this when fixed for all testclasess
  public Integer numberOfEmployerAccounts;
  public Integer numberOfWorkplaceAccounts; // Creates both Workplaces and parent Employer Account
  public Integer numberOfUnpaidInvoices;
  public Integer numberOfPaidInvoices;
  public Integer numberOfContentVersions;
  public Integer numberOfCases;
  public Integer numberOfCaseFiles; // only have an effect when used together with numberOfCases.
  public Integer numberOfCaseFeedItems; // only have an effect when used together with numberOfCases.
  public Integer numberOfMemberUsers;
}

/**
 * Student
 * Yrkesverksam
 * Yrkesverksam 1 året
 */