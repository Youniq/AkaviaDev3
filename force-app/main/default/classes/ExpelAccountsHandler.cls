public class ExpelAccountsHandler {

  public static void expel(List<Account> accounts) {
    Date lastDayOfPreviousMonth = Date.today().toStartOfMonth().addDays(-1);
    Map<Id, Account> accountsMap = withChildInfo(accounts);
    Map<Id, Assignment__c> assignments = assignmentsForAccounts(
      accountsMap.keyset()
    );
    for (Assignment__c assignment : assignments.values()) {
      Id accountId = assignment.Person__c;
      assignment.EndDate__c = lastDayOfPreviousMonth;
    }

    Database.SaveResult[] assignmentSRlist = Database.update(
      assignments.values(),
      false
    );

    accountsMap = cleanAccountsMapAfterUpdate(
      assignmentSRlist,
      assignments,
      'Person__c',
      accountsMap
    );

    Map<Id, MembershipBenefit__c> membershipBenefits = membershipBenefitsForAccounts(
      accountsMap.keyset()
    );
    for (MembershipBenefit__c membershipBenefit : membershipBenefits.values()) {
      Id accountId = membershipBenefit.Person__c;
      membershipBenefit.Status__c = 'Avslutad';
      membershipBenefit.EndDate__c = lastDayOfPreviousMonth;
    }

    Database.SaveResult[] membershipBenefitsSRlist = Database.update(
      membershipBenefits.values(),
      false
    );

    accountsMap = cleanAccountsMapAfterUpdate(
      membershipBenefitsSRlist,
      membershipBenefits,
      'Person__c',
      accountsMap
    );

    Map<Id, Membership__c> memberships = membershipsForAccounts(
      accountsMap.keyset()
    );

    Map<Id, FeeCategory__c> feeCategories = feeCategoriesForMemberships(
      memberships.keyset()
    );

    Map<Id, FeeCategory__c> feeCategoriesToDelete = new Map<Id, FeeCategory__c>();
    Map<Id, FeeCategory__c> feeCategoriesToUpdate = new Map<Id, FeeCategory__c>();
    Map<Id, Id> studentFeeCategoryByMembershipId = new Map<Id, Id>();
    for (FeeCategory__c feeCategory : feeCategories.values()) {
      Id accountId = feeCategory.Membership__r.Person__c;
      switch on feeCategory.Status__c {
        when 'Kommande' {
          feeCategoriesToDelete.put(feeCategory.Id, feeCategory);
          continue;
        }
        when 'Aktiv' {
          feeCategory.EndDate__c = lastDayOfPreviousMonth;
          feeCategoriesToUpdate.put(feeCategory.Id, feeCategory);
          continue;
        }
      }
    }

    Database.SaveResult[] feeCategoriesSRlist = Database.update(
      feeCategoriesToUpdate.values(),
      false
    );

    accountsMap = cleanAccountsMapAfterUpdate(
      feeCategoriesSRlist,
      feeCategoriesToUpdate,
      'Membership__r.Person__c',
      accountsMap
    );

    Database.DeleteResult[] feeCategoriesDRlist = Database.delete(
      feeCategoriesToDelete.values(),
      false
    );

    accountsMap = cleanAccountsMapAfterDelete(
      feeCategoriesDRlist,
      feeCategoriesToDelete,
      'Membership__r.Person__c',
      accountsMap
    );

    memberships = membershipsForAccounts(accountsMap.keyset());
    for (Membership__c membership : memberships.values()) {
      Id accountId = membership.Person__c;
      membership.EndDate__c = lastDayOfPreviousMonth;
      membership.ExitReason__c = 'Uteslutning';
      membership.Expelled__c = true;
    }

    Database.SaveResult[] membershipsSRlist = Database.update(
      memberships.values(),
      false
    );

    accountsMap = cleanAccountsMapAfterUpdate(
      membershipsSRlist,
      memberships,
      'Person__c',
      accountsMap
    );

    Map<Id, Employment__c> employments = employmentsForAccounts(
      accountsMap.keyset()
    );

    Database.DeleteResult[] employmentsDRlist = Database.delete(
      employments.values(),
      false
    );

    accountsMap = cleanAccountsMapAfterDelete(
      employmentsDRlist,
      employments,
      'Person__c',
      accountsMap
    );

    Map<Id, Invoice__c> invoicesToCancel = invoicesForAccounts(
      accountsMap.keyset()
    );

    Map<Id, Decimal> accountToAmountMap = calculateRestInvoiceAmount(
      invoicesToCancel.values()
    );
    for (Account account : accountsMap.values()) {
      account.ActivePortalUser__c = false;
      account.CancellationReason__c = 'Utesluten pga bristande betalning';
      account.Type = 'Föredetta medlem';
      account.Expell__c = false;
      account.CancellationDate__c = lastDayOfPreviousMonth;
      
      Boolean firstYearLowPayment = isFirstYearLowPayment(account);

      if (firstYearLowPayment) {
          account.RestInvoiceAmount__c = null;
          account.RestInvoiceAmountDate__c = null;
          account.RestInvoiceAmountType__c = null;
      } else {
          account.RestInvoiceAmount__c = accountToAmountMap.get(account.Id);
          account.RestInvoiceAmountDate__c = System.today();
          account.RestInvoiceAmountType__c = 'Expelled';
      }

    }

    Database.SaveResult[] accountsSRlist = Database.update(
      accountsMap.values(),
      false
    );

    Map<Id, Account> tempAccountMap = new Map<Id, Account>();
    tempAccountMap.putAll(accountsMap);
    accountsMap = cleanAccountsMapAfterUpdate(
      accountsSRlist,
      tempAccountMap,
      'Id',
      accountsMap
    );

    invoicesToCancel = invoicesForAccounts(accountsMap.keyset());
    if(invoicesToCancel.size() > 0){
      if(!Test.isRunningTest()){
        Id jobId = System.enqueueJob(
          new BillectaCancelInvociesQueuable(invoicesToCancel.values())
        );
        createCancelInvoicesCalloutLog(jobId, new List<Id>(accountsMap.keySet()));
      }
    }

    Map<String, List<Account>> emailGroups = groupAccountsForEmail(
        new List<Account>(accountsMap.values())
    );

    if (!emailGroups.get('standard').isEmpty()) {
        invokeSendEmailFlow(emailGroups.get('standard'));
    }

    if (!emailGroups.get('firstYear').isEmpty()) {
        invokeSendFirstYearEmailFlow(emailGroups.get('firstYear'));
    }
  }

  public static Boolean isFirstYearLowPayment(Account account) {
    return account.LatestMembership__r != null &&
      account.LatestMembership__r.CurrentFeeCategory__r != null &&
      account.LatestMembership__r.CurrentFeeCategory__r.MembershipCategory__c ==
        'Yrkesverksam första året' &&
      (account.NoOfPayedInvoicesAsEmployed__c == null ||
       account.NoOfPayedInvoicesAsEmployed__c < 3);
  }

  public static Map<String, List<Account>> groupAccountsForEmail(
      List<Account> accounts
  ) {
      Map<String, List<Account>> groups = new Map<String, List<Account>>{
          'standard' => new List<Account>(),
          'firstYear' => new List<Account>()
      };

      if (accounts == null) {
          return groups;
      }

      for (Account account : accounts) {
          if (account == null || String.isBlank(account.PersonEmail)) {
              continue;
          }

          if (isFirstYearLowPayment(account)) {
              groups.get('firstYear').add(account);
          } else {
              groups.get('standard').add(account);
          }
      }

      return groups;
  }

  public static void invokeSendEmailFlow(List<Account> accounts) {
    Map<String, Object> flowVariables = new Map<String, Object>();
    flowVariables.put('accountList', accounts);
    if (!Test.isRunningTest()) {
      Flow.Interview.Send_Email_To_Expelled_Members flow =
        new Flow.Interview.Send_Email_To_Expelled_Members(flowVariables);
      flow.start();
    }
  }

  public static void invokeSendFirstYearEmailFlow(List<Account> accounts) {
      if (accounts == null || accounts.isEmpty() || Test.isRunningTest()) {
          return;
      }

      Map<String, Object> flowVariables = new Map<String, Object>{
          'accountList' => accounts
      };

      Flow.Interview.Send_Email_To_Expelled_First_Year_Members flow =
          new Flow.Interview.Send_Email_To_Expelled_First_Year_Members(
              flowVariables
          );

      flow.start();
  }

  
  public static Map<Id, Invoice__c> invoicesForAccounts(
      Set<Id> accountIds
  ) {
      return new Map<Id, Invoice__c>(
          InvoiceHelper.invoicesForAccounts(accountIds)
      );
  }


  public static Map<Id, Assignment__c> assignmentsForAccounts(
    Set<Id> accountIds
  ) {
    return new Map<Id, Assignment__c>(
      [
        SELECT Id, Person__c, EndDate__c
        FROM Assignment__c
        WHERE
          Person__c IN :accountIds
          AND (EndDate__c > TODAY
          OR EndDate__c = NULL)
      ]
    );
  }

  public static Map<Id, MembershipBenefit__c> membershipBenefitsForAccounts(
    Set<Id> accountIds
  ) {
    return new Map<Id, MembershipBenefit__c>(
      [
        SELECT Id, Person__c, EndDate__c
        FROM MembershipBenefit__c
        WHERE
          Person__c IN :accountIds
          AND (Status__c = 'Aktiv'
          OR Status__c = 'Aktiverad'
          OR Status__c = 'Skickad till försäkringsbolag')
          AND (EndDate__c > TODAY
          OR EndDate__c = NULL)
      ]
    );
  }

  public static Map<Id, Membership__c> membershipsForAccounts(
    Set<Id> accountIds
  ) {
    return new Map<Id, Membership__c>(
      [
        SELECT Id, Person__c, EndDate__c, CurrentFeeCategory__c, ExitReason__c, Expelled__c
        FROM Membership__c
        WHERE Person__c IN :accountIds
        AND (Expelled__c = false OR Expelled__c = NULL)
        AND SenasteMedlemskap__c = true
      ]
    );
  }

  public static Map<Id, FeeCategory__c> feeCategoriesForMemberships(
    Set<Id> membershipIds
  ) {
    return new Map<Id, FeeCategory__c>(
      [
        SELECT
          Id,
          Status__c,
          MembershipCategory__c,
          EndDate__c,
          Membership__r.Person__c
        FROM FeeCategory__c
        WHERE Membership__c IN :membershipIds
        ORDER BY StartDate__c DESC
      ]
    );
  }

  public static Map<Id, Employment__c> employmentsForAccounts(
    Set<Id> accountIds
  ) {
    return new Map<Id, Employment__c>(
      [
        SELECT Id, Person__c, EndDate__c
        FROM Employment__c
        WHERE Person__c IN :accountIds AND EndDate__c = NULL
      ]
    );
  }

  public static Map<Id, Account> withChildInfo(List<Account> accounts) {
    return new Map<Id, Account>(
      [
        SELECT
          Id,
          LatestMembership__r.CurrentFeeCategory__r.FeeCategory__c,
          LatestMembership__r.CurrentFeeCategory__r.MembershipCategory__c,
          LatestMembership__r.CurrentFeeCategory__r.AutoUpgrade__c,
          LatestMembership__r.CurrentFeeCategory__r.StartDate__c,
          ActivePortalUser__c,
          PersonContactId,
          PersonEmail,
          CancellationReason__c,
          Expell__c,
          CancellationDate__c,
          NoOfPayedInvoicesAsEmployed__c
        FROM Account
        WHERE Id IN :accounts
      ]
    );
  }

  public static Map<Id, Account> cleanAccountsMapAfterUpdate(
    Database.SaveResult[] srList,
    Map<Id, sObject> updatedRecords,
    String updatedRecordsPersonField,
    Map<Id, Account> accountsMapToClean
  ) {
    for (Integer i = 0; i < srList.size(); i++) {
      Database.SaveResult sr = srList[i];
      sObject origRecord = updatedRecords.values()[i];
      system.debug('origRecord ' + origRecord);
      if (!sr.isSuccess()) {
        for (Database.Error err : sr.getErrors()) {
          System.debug('The following error has occurred.');
          System.debug(err.getStatusCode() + ': ' + err.getMessage());
          System.debug('Fields that affected this error: ' + err.getFields());
        }
        System.debug('updated record Id' + sr.getId());
        System.debug('updated record' + updatedRecords.get(sr.getId()));
        Id accountId = (Id) origRecord.get(updatedRecordsPersonField);
        if (accountsMapToClean.containsKey(accountId)) {
          accountsMapToClean.remove(accountId);
        }
      }
    }
    return accountsMapToClean;
  }

  public static Map<Id, Account> cleanAccountsMapAfterDelete(
    Database.DeleteResult[] drList,
    Map<Id, sObject> deletedRecords,
    String deletedRecordsPersonField,
    Map<Id, Account> accountsMapToClean
  ) {
    for (Integer i = 0; i < drList.size(); i++) {
      Database.DeleteResult dr = drList[i];
      sObject origRecord = deletedRecords.values()[i];
      if (!dr.isSuccess()) {
        for (Database.Error err : dr.getErrors()) {
          System.debug('The following error has occurred.');
          System.debug(err.getStatusCode() + ': ' + err.getMessage());
          System.debug('Fields that affected this error: ' + err.getFields());
        }
        Id accountId = (Id) deletedRecords.get(origRecord.Id)
          .get(deletedRecordsPersonField);
        if (accountsMapToClean.containsKey(accountId)) {
          accountsMapToClean.remove(accountId);
        }
      }
    }
    return accountsMapToClean;
  }

  public static Map<Id, Decimal> calculateRestInvoiceAmount(
    List<Invoice__c> overdueInvoices
  ) {
    Map<Id, Decimal> accountToAmountMap = new Map<Id, Decimal>();
    for (Invoice__c inv : overdueInvoices) {
      Decimal restAmount = 0;
      if (
        (inv.RemainingAmount__c == null ||
        inv.RemainingAmount__c > 0) && inv.AmountAkassa__c != null
      ) {
        restAmount = inv.Amount__c - inv.AmountAkassa__c;
      } else if (inv.RemainingAmount__c != null) {
        restAmount = inv.Amount__c;
      }
      if (accountToAmountMap.containsKey(inv.Person__c)) {
        system.debug(restAmount);
        system.debug(accountToAmountMap.get(inv.Person__c));
        restAmount = restAmount + accountToAmountMap.get(inv.Person__c);
        accountToAmountMap.put(inv.Person__c, restAmount);
      } else {
        accountToAmountMap.put(inv.Person__c, restAmount);
      }
    }
    return accountToAmountMap;
  }

  private static void createCancelInvoicesCalloutLog(
    Id jobId,
    List<Id> accIds
  ) {
    String accId;
    if (accIds != null && accIds.size() == 1) {
      accId = accIds[0];
    }
    Callout__c callout = new Callout__c(
      jobId__c = jobId,
      Type__c = 'Billecta - Cancel Invoices',
      Account__c = accId,
      Status__c = 'Queued'
    );
    insert callout;
  }
}
