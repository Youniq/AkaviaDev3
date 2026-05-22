/*
 * Author @ Jenny Blomberg
 * Invocable class to make callout to Billect to create a debtor (member)
 * OR to update the debtor (member)
 *
 * Triggered by flow / process builder
 */
public class BillectaInitiateSendDebtor {
  public class Request {
    @InvocableVariable(
      label='Account Id'
      description='Det Account id som ska skickas till Billecta'
      required=true
    )
    public String recordId;

    @InvocableVariable(
      label='create / update / createOrUpdate'
      description='Skriv in \'create\', \'update\' eller \'createOrUpdate\' beroende på vilken uppdatering du vill göra i Billecta'
      required=true
    )
    public String billectaAction;
  }

  public class Response {
    @invocableVariable(
      label='Error Message'
      description='Om det förekom ett valideringsfel vid körning så returneras det här.'
    )
    public String errorMsg;
  }

  @Invocablemethod
  public static List<Response> sendDebtorWithPaymentMethod(
    List<Request> requests
  ) {
    Map<Id, String> accountIdsToAction = new Map<Id, String>();

     for (Request r : requests) {
       accountIdsToAction.put(r.recordId, r.billectaAction);
     }  

    List<String> responseMsgList = sendDebtor(accountIdsToAction, true);
    List<Response> responses = new List<Response>();
    for (String msg : responseMsgList) {
      Response resp = new Response();
      resp.errorMsg = msg;
      responses.add(resp);
    }

    return responses;
  }

  public static List<String> sendDebtor(
      Map<Id, String> accountIdsToAction,
      Boolean sendPaymentMethod
  ) {
      List<String> responseMsgList = new List<String>();
      List<Callout__c> calloutsScheduled = new List<Callout__c>();

      if (accountIdsToAction.size() < 50) {
          List<Account> accs = [
              SELECT
                  Id,
                  BillectaID__c,
                  SocialSecurityNumber__c,
                  FirstName,
                  LastName,
                  CurrentCOAdress__c,
                  CurrentStreetAdress__c,
                  CurrentZipCode__c,
                  CurrentCity__c,
                  CurrentCountry__c,
                  CurrentCountryCode__c,
                  PersonMobilePhone,
                  PersonEmail,
                  MemberNumber__c,
                  FeeCategory__c,
                  ProtectedIdentity__c,
                  AutogiroBank__c,
                  AG_BankClearingNumber__c,
                  AG_BankAccountNumber__c,
                  AG_BankIDSignToken__c,
                  PaymentMethod__c,
                  DistributionMethod__c,
                  AutogiroApprovalStatus__c,
                  LatestSentPMDetails_Billecta__c,
                  IsDistributionPostalPaperOnly__c,
                  BillectaMarkedForUpdate__c,
                  EinvoiceBank__c
              FROM Account
              WHERE Id IN :accountIdsToAction.keySet()
              AND CancellationDateGDPR__c = NULL
          ];

          for (Account acc : accs) {
              String resp;

              try {
                  BillectaValidationHelper.validateBillectaActionInput(
                      accountIdsToAction.get(acc.Id)
                  );

                  BillectaValidationHelper.validateAccountForAction(
                      acc,
                      accountIdsToAction.get(acc.Id)
                  );

                  String currentPMDetails = '';

                  Boolean billectaCompletedAutogiro =
                      acc.PaymentMethod__c == 'AG' &&
                      acc.AutogiroApprovalStatus__c == 'Completed';

                  if (sendPaymentMethod && billectaCompletedAutogiro)
                  {
                      System.debug(
                          'Skipping debtor sync after Billecta autogiro completion.'
                      );

                      responseMsgList.add(null);
                      continue;
                  }

                  Id jobId = System.enqueueJob(
                      new BillectaSendDebtorAsync(acc, sendPaymentMethod)
                  );

                  System.debug('-----------JOB ID-------------' + jobId);

                  calloutsScheduled.add(
                      new Callout__c(
                          jobId__c = jobId,
                          Type__c = acc.BillectaID__c == null
                              ? 'Billecta - Create Debtor'
                              : 'Billecta - Update Debtor',
                          Account__c = acc.Id,
                          Status__c = 'Queued'
                      )
                  );
              } catch (BillectaException e) {
                  System.debug(
                      LoggingLevel.ERROR,
                      'BillectaInitiateSendDebtor.sendDebtor() ' + e.getMessage()
                  );

                  ApexLog.Error errLog = new ApexLog.Error(
                      'BillectaInitiateSendDebtor',
                      'sendDebtor',
                      true,
                      e
                  );

                  ApexLog.createLogDebug(errLog);
                  resp = e.getMessage();
              }

              responseMsgList.add(resp);
          }
      } else {
          String billectaAction = accountIdsToAction.values().get(0);

          BillectaUpdateDebtorsBatch BC = new BillectaUpdateDebtorsBatch(
              accountIdsToAction.keySet(),
              billectaAction,
              sendPaymentMethod
          );

          Id batchId = Database.executeBatch(BC, 1);

          for (Id accountId : accountIdsToAction.keySet()) {
              responseMsgList.add(null);
          }
      }

      if (calloutsScheduled.size() > 0) {
          System.debug('--- Create Callouts ---');

          try {
              insert calloutsScheduled;
          } catch (Exception e) {
              System.debug('--- Error inserting Callouts --- ' + calloutsScheduled);

              ApexLog.Error logError = new ApexLog.Error(
                  'BillectaInitiateSendDebtor',
                  'sendDebtor',
                  true,
                  e
              );

              ApexLog.createLogDebug(logError);
          }

          System.debug('--- Created Callouts ---' + calloutsScheduled);
      }

      return responseMsgList;
  }
}