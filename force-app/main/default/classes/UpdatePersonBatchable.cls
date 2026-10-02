/**
 * @description       :
 * @author            : Malin Nilsson (Stretch Customer AB)
 * @group             :
 * @last modified on  : 2025-04-07
 * @last modified by  : Malin Nilsson (Stretch Customer AB)
 **/
global class UpdatePersonBatchable implements Database.Batchable<Sobject> {
  List<Account> personList;

  public UpdatePersonBatchable(List<Account> persons) {
    personList = persons;
  }

  global Iterable<SObject> start(Database.BatchableContext bc) {
    return personList;
  }
  global void execute(Database.BatchableContext bc, List<Account> acctList) {
    try {
      System.debug('LIMIT Query Rows 1 ' + System.Limits.getQueryRows());
      Schema.SObjectField externalIdField = Account.Fields.BCIID__c;

      List<Account> accountsToUpsert = new List<Account>();
      accountsToUpsert = validateAccountList(acctList);

      Database.UpsertResult[] results = Database.upsert(
        accountsToUpsert,
        externalIdField,
        false
      );

      for (Integer index = 0, size = results.size(); index < size; index++) {
        if (results[index].isSuccess()) {
          if (results[index].isCreated()) {
            System.debug(
              acctList[index].SocialSecurityNumber__c + ' was created'
            );
          } else {
            System.debug(
              acctList[index].SocialSecurityNumber__c + ' was updated'
            );
              System.debug(
              acctList[index].Name + ' was updated'
            );
          }
        } else {
          handleUpsertError(acctList[index], results[index]);
        }
      }
    } catch (Exception ex) {
      System.debug(
        'Cause--> ' +
        ex.getCause() +
        'Message--> ' +
        ex.getMessage()
      );
      System.debug(
        'tackTrace--> ' +
        ex.getStackTraceString() +
        'tLineNumber--> ' +
        ex.getLineNumber()
      );

      ApexLog.Error logError = new ApexLog.Error(
        'SchedulableDailyPersonBCI',
        'UpdatePersonBatchable',
        false,
        ex
      );
      ApexLog.createLogDebug(logError);
    }
  }
  global void finish(Database.BatchableContext bc) {
    //System.debug('result--> ' + result.size());
  }

  @TestVisible
  private static void handleUpsertError(
    Account acc,
    Database.UpsertResult errResult
  ) {
    String errorMessage =
      'Fel vid uppdatering av personen ' +
      acc.SocialSecurityNumber__c +
      ' ; ';
    Database.Error[] errors = errResult.getErrors();
    for (Database.Error er : errors) {
      errorMessage = errorMessage + er.getMessage() + ' ; ';
    }

    ApexLog.Information logError = new ApexLog.Information(
      'SchedulableDailyPersonBCI',
      'UpdatePersonBatchable',
      false,
      errorMessage,
      acc.BCIID__c
    );
    ApexLog.createLogDebug(logError);
  }

  @TestVisible
  private static List<Account> validateAccountList(
    List<Account> listToBeValidated
  ) {
    Map<String, Account> acctMap = new Map<String, Account>();

    // first we must put list in a map to be able to use keyset in SOQL
    for (Account acc : listToBeValidated) {
      acctMap.put(acc.BCIID__c, acc);
    }
    System.debug('acctMap.keySet().size(()): ' + acctMap.keySet().size());

    // Now lets fins existing members, these should be updated with the new info
    List<Account> existingMembers = [
      SELECT Id, SocialSecurityNumber__c, BCIID__c
      FROM Account
      WHERE BCIID__c IN :acctMap.keySet() AND IsPersonAccount = TRUE
    ];

    // We need to put existing members in a map with BCIID__c as key so we can fetch them
    // based on BCIID__c later on when validating
    Map<String, Account> existingAccsMap = new Map<String, Account>();
    System.debug('LIMIT Query Rows 2 ' + System.Limits.getQueryRows());

    for (Account acc : existingMembers) {
      existingAccsMap.put(acc.BCIID__c, acc);
    }

    // Now we loop all new values to make sure the BCIID__c already exisits in SF
    // if not - then we need to anonymize the data before insert.

    for (Account acc : listToBeValidated) {
      if (!existingAccsMap.containsKey(acc.BCIID__c)) {
        //now we need to anonymize so that we only save BisnodeID
        //another job will pick the BisnodeID up and make sure we do not monitor this SSN any more
        Account anonymizedAcc = new Account(
          SocialSecurityNumber__c = acc.SocialSecurityNumber__c,
          BCIID__c = acc.BCIID__c,
          BciLastModified__c = acc.BciLastModified__c,
          ProtectedIdentity__c = acc.ProtectedIdentity__c,
          FirstName = 'DELETE',
          LastName = 'FROM BCI MONITOR'
        );

        acctMap.put(anonymizedAcc.BCIID__c, anonymizedAcc);
      }
    }

    return acctMap.values();
  }
}