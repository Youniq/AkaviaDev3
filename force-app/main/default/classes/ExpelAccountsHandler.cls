/*******************************************************************
* @author: Jenny Blomberg
* @date: 2022-05-02
* @updated: 2023-12-07
* @updatedBy: Malin Nilsson
* @description: This was first built in flow but due to extensive amount of 
* SOQL queries (many related records to be hanldled) and Map functionality still
* not available in flow, limits were reached and the flow was replaced by APEX.  
* 
* This class is a helperclass called from ExpelAccountBatchable and AccountsController. 
* VisualForce Page MembersToExpell initiates the process. 
* This helper alters all defined fields on Members and their related records when being expelled 
* due to lack of payment. 
*
* @Jira Tickets : ACF-204, ACF-205, ACF-454, ACF-659 (Update to yrk år1 members)

********************************************************************/
public class ExpelAccountsHandler {
  public static void expel(List<Account> accounts) {
    Date lastDayOfPreviousMonth = Date.today().toStartOfMonth().addDays(-1);

    //Data Setup
    Map<Id, Account> accountsMap = withChildInfo(accounts);
    // Map<Id, Account> studentAccounts = new Map<Id, Account>();
    // for (Account account : accountsMap.values()) {
    //   if (isStudent(account)) {
    //     studentAccounts.put(account.Id, account);
    //   }
    // }

    //Assignments need enddat
    Map<Id, Assignment__c> assignments = assignmentsForAccounts(
      accountsMap.keyset()
    );
    for (Assignment__c assignment : assignments.values()) {
      Id accountId = assignment.Person__c;
      // Boolean isStudent = studentAccounts.containsKey(accountId); Malin
      assignment.EndDate__c = lastDayOfPreviousMonth;
      // assignment.EndDate__c = isStudent
      //   ? studentCancellationDate(studentAccounts.get(accountId))
      //   : lastDayOfPreviousMonth;
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

    //MembershipBenefits need end date and status
    Map<Id, MembershipBenefit__c> membershipBenefits = membershipBenefitsForAccounts(
      accountsMap.keyset()
    );
    for (MembershipBenefit__c membershipBenefit : membershipBenefits.values()) {
      Id accountId = membershipBenefit.Person__c;
      //Boolean isStudent = studentAccounts.containsKey(accountId); Malin
      membershipBenefit.Status__c = 'Avslutad';
      membershipBenefit.EndDate__c = lastDayOfPreviousMonth;
      // membershipBenefit.EndDate__c = isStudent Malin
      //   ? studentCancellationDate(studentAccounts.get(accountId))
      //   : lastDayOfPreviousMonth;
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

    //FeeCategories need end date and status
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
      //Boolean isStudent = studentAccounts.containsKey(accountId); Malin

      switch on feeCategory.Status__c {
        when 'Kommande' {
          //Delete all fee categories that have status = "Kommande"
          feeCategoriesToDelete.put(feeCategory.Id, feeCategory);
          continue;
        }
        when 'Aktiv' {
          // Active Fee Categories should be updated with EndDate
          feeCategory.EndDate__c = lastDayOfPreviousMonth;
          // feeCategory.EndDate__c = isStudent Malin
          //   ? studentCancellationDate(studentAccounts.get(accountId))
          //   : lastDayOfPreviousMonth;
          feeCategoriesToUpdate.put(feeCategory.Id, feeCategory);
          continue;
        }
        // when 'Avslutad' { Malin
        //   // For Students we want to update Membership with Studerande as latest FeeCategory
        //   if (isStudent && feeCategory.MembershipCategory__c == 'Studerande') {
        //     studentFeeCategoryByMembershipId.put(
        //       feeCategory.Membership__c,
        //       feeCategory.Id
        //     );
        //   }
        // }
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

    //Memberships need
    memberships = membershipsForAccounts(accountsMap.keyset());
    for (Membership__c membership : memberships.values()) {
      Id accountId = membership.Person__c;
      // Boolean isStudent = studentAccounts.containsKey(accountId);
      // Boolean updateFeeCategory = studentFeeCategoryByMembershipId.containsKey(
      //   membership.Id
      // );
      membership.EndDate__c = lastDayOfPreviousMonth;
      // membership.EndDate__c = isStudent
      //   ? studentCancellationDate(studentAccounts.get(accountId))
      //   : lastDayOfPreviousMonth;
      // membership.CurrentFeeCategory__c = updateFeeCategory
      //   ? studentFeeCategoryByMembershipId.get(membership.Id)
      //   : membership.CurrentFeeCategory__c;
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
      //Boolean isStudent = studentAccounts.containsKey(account.Id);
      account.ActivePortalUser__c = false;
      account.CancellationReason__c = 'Utesluten pga bristande betalning';
      account.Type = 'Föredetta medlem';
      account.Expell__c = false;
      account.CancellationDate__c = lastDayOfPreviousMonth;
      // account.CancellationDate__c = isStudent 
      //   ? studentCancellationDate(account)
      //   : lastDayOfPreviousMonth;


      // Don't set RestInvoice details if the fee category is 'Dubbelansluten SRAT' (Azure DevOps #53)
      if(account.LatestMembership__r.CurrentFeeCategory__r.FeeCategory__c == 'Dubbelansluten SRAT'){
        account.RestInvoiceAmount__c = null;
        account.RestInvoiceAmountDate__c = null;
        account.RestInvoiceAmountType__c = null;
      } else {
      // Fråga till Michaela; ska Yrk1 medlemmar () få restfaktura, eller ska ev RestInvoiceAmount__c sättas till null ? (Så görs det idag)
      // Svar fr Michaela: nulla inte restfakutaamount utan spara det, behövs om uteslutningen ångras.
      // En restfaktura som ligger på en utesluten medlem skickas inte  till medlem förrän den medlemmen eventuellt blir aktiv igen.
      account.RestInvoiceAmount__c = accountToAmountMap.get(account.Id);
      account.RestInvoiceAmountDate__c = system.Today();
      account.RestInvoiceAmountType__c = 'Expelled';

      // account.RestInvoiceAmount__c = isStudent
      //   ? null
      //   : accountToAmountMap.get(account.Id);
      // account.RestInvoiceAmountDate__c = isStudent ? null : system.Today();
        // account.RestInvoiceAmountType__c = isStudent ? null : 'Expelled';
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

      // If running in test, we don't want to enqueue the job to prevent hitting queue limit
      if(!Test.isRunningTest()){
        Id jobId = System.enqueueJob(
          new BillectaCancelInvociesQueuable(invoicesToCancel.values())
        );
          
        createCancelInvoicesCalloutLog(jobId, new List<Id>(accountsMap.keySet()));
      }
    }

    for (Account account : accountsMap.values()) {
      if (account.PersonEmail == null || account.PersonEmail == '') {
        accountsMap.remove(account.Id);
      }
    }

    invokeSendEmailFlow(accountsMap.values());
  }

  public static void invokeSendEmailFlow(List<Account> accounts) {
    Map<String, Object> flowVariables = new Map<String, Object>();
    flowVariables.put('accountList', accounts);
    Flow.Interview.Send_Email_To_Expelled_Members flow = new Flow.Interview.Send_Email_To_Expelled_Members(
      flowVariables
    );

    if(!Test.isRunningTest()){
       flow.start();
    }
  }

  public static Map<Id, Invoice__c> invoicesForAccounts(Set<Id> accountIds) {
    return new Map<Id, Invoice__c>(
      [
        SELECT
          Id,
          BillectaID__c,
          Amount__c,
          AmountAkassa__c,
          Person__c,
          RemainingAmount__c
        FROM Invoice__c
        WHERE
          BillectaID__c != NULL
          AND PaymentStatus__c != 'Makulerad'
          AND PaymentStatus__c != 'Betald'
          AND Person__c IN :accountIds
      ]
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
          AND (EndDate__c > TODAY
          OR EndDate__c = NULL)
      ]
    );
  }

  public static Map<Id, Membership__c> membershipsForAccounts(
    Set<Id> accountIds
  ) {
    // Find memberships that haven't been expelled yet
    // This includes memberships with EndDate = NULL (active) and memberships with EndDate set 
    // (e.g., from withdrawal requests via Account_Scheduled_Cancellation_of_Membership flow)
    // that should still be marked as expelled when expulsion process runs
    return new Map<Id, Membership__c>(
      [
        SELECT Id, Person__c, EndDate__c, CurrentFeeCategory__c, ExitReason__c, Expelled__c
        FROM Membership__c
        WHERE Person__c IN :accountIds 
        AND (Expelled__c = false OR Expelled__c = NULL)
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
    // Iterate through each returned result

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

  /**
   * This method is used in the expel process when deleting related records (like Employmentc records). 
   * If the deletion of a related record fails, the associated Account is removed from further processing to maintain data integrity.
   */
  public static Map<Id, Account> cleanAccountsMapAfterDelete(
    Database.DeleteResult[] drList,
    Map<Id, sObject> deletedRecords,
    String deletedRecordsPersonField,
    Map<Id, Account> accountsMapToClean
  ) {
    // Iterate through each returned result
    for (Integer i = 0; i < drList.size(); i++) {
      Database.DeleteResult dr = drList[i];
      sObject origRecord = deletedRecords.values()[i];
      if (!dr.isSuccess()) {
        // Operation failed, so get all errors
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
        // Always use the full invoice amount. Any partially paid invoices are handled by the Billecta and corrected on the next invoice.
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
      Account__c = accId, // Acc refrence will be null if there are multiple accounts.
      Status__c = 'Queued'
    );

    insert callout;
  }

  // Returns false if there is no Latest Membership or CurrentFeeCategory, as expected
  // public static Boolean isStudent(Account account) {
  //   if (Test.isRunningTest()) {
  //     return account.LatestMembership__r.CurrentFeeCategory__r.AutoUpgrade__c;
  //   }
  //   if (
  //     // Youre a yrk år 1 (student) if you have no oayes invoices and you were autoupgraded.
  //     account.NoOfPayedInvoicesAsEmployed__c == 0 &&
  //     account.LatestMembership__r.CurrentFeeCategory__r.AutoUpgrade__c
  //   ) {
  //     return true;
  //   } else {
  //     return false;
  //   }
  // }

  // public static Date studentCancellationDate(Account account) {
  //   return account.LatestMembership__r.CurrentFeeCategory__r.StartDate__c - 1;
  // }
}