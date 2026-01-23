/**
 * @description       : TEMP JOBB: En klass som ska utföra ett one time job för att migrera uppgifter i Federation ID fältet på User.
 * Iom med lagändring för Säker Start (BankId) så måste medlemmens personnummer finnas i User.FederationIdentifier fältet (inte medlemsnummer vilket det har varit tidigare)
 * @author            : Malin Nilsson (Stretch Customer AB)
 * @group             :
 * @last modified on  : 2024-02-12
 * @last modified by  : Malin Nilsson (Stretch Customer AB)
 **/
public with sharing class sakerStartMigrationBatch implements Database.Batchable<SObject> {
  public Database.QueryLocator start(Database.BatchableContext bc) {
    // Get active users or inactive users where federation id isn't null
    String query = 'Select Id, FederationIdentifier, IsPortalEnabled, IsActive, Account.SocialSecurityNumber__c, Account.MissingSocialSecurityNumber__c from User where profile.Name = \'Akavia Member\' AND (IsActive = true OR (IsActive = false AND FederationIdentifier != null))';
    if (Test.isRunningTest()) {
      query += ' and firstname like \'testClassUser%\' order by lastModifiedDate desc Limit 5';
    } else {
      query += ' order by Account.ID';
    }
    return Database.getQueryLocator(query);
  }

  public void execute(Database.BatchableContext bc, List<User> scope) {
    try {
      for (User record : scope) {
        if (record.IsActive && !record.Account.MissingSocialSecurityNumber__c) {
          record.FederationIdentifier = record.Account.SocialSecurityNumber__c;
        } else if (
          record.Account.MissingSocialSecurityNumber__c || !record.IsActive
        ) {
          record.FederationIdentifier = null;
        }
      }

      if (Test.isRunningTest()) {
        // Make sure to run the error path during test.
        User u = Scope[0];
        u.FirstName = null;
        u.userName = null;
      }

      // Update the processed records with allOrNone parameter set to false
      Database.SaveResult[] updateResults = Database.update(scope, false);
      List<ApexLog.Log> logsToCreate = new List<ApexLog.Log>();

      // Process the results
      for (Database.SaveResult sr : updateResults) {
        if (!sr.isSuccess()) {
          for (Database.Error err : sr.getErrors()) {
            // Handle each error individually
            System.debug(
              'Error updating record: ' +
              err.getStatusCode() +
              ' - ' +
              err.getMessage()
            );

            // instantiate a debug log record.
            ApexLog.Error errLog = new ApexLog.Error(
              'sakerStartMigrationBatch',
              'execute()',
              true,
              err
            );
            logsToCreate.add(errLog);
          }
        }
      }

      if (!Test.isRunningTest()) {
        ApexLog.bulkCreateLogDebug(logsToCreate);
      }
    } catch (Exception e) {
      // Handle any unexpected exceptions
      System.debug('An unexpected error occurred: ' + e.getMessage());
      System.debug('Trace ' + e.getStackTraceString());

      ApexLog.createLogDebug(
        new ApexLog.Error('sakerStartMigrationBatch', 'execute()', true, e)
      );
    }
  }

  public void finish(Database.BatchableContext bc) {
    // Your finish logic (optional)
  }
}