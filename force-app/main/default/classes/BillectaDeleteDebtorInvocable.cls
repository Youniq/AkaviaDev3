/**
 * @description       : Apex Action to initiate job to delete a debtor in Billecta
 * @author            : Malin Nilsson (Stretch Customer AB)
 * @group             : 
 * @last modified on  : 2024-12-06
 * @last modified by  : Malin Nilsson (Stretch Customer AB)
**/
public without sharing class BillectaDeleteDebtorInvocable {


    public class Request{
        @InvocableVariable
        public String accountId;
    }

    @InvocableMethod(label='Delete member from Billecta' description='Attempts to delete the member/debtor from Billecta')
    public static void DeleteDebtor(List<Request> requests){

        Set<String> accountIds = new Set<String>();
        // List<Callout__c> calloutsToCreate = new List<Callout__c>();

        for(Request r: requests){
            accountIds.add(r.accountId);
        }

        List<Account> debtorsToDelete = [SELECT Id, BillectaId__c FROM Account WHERE Id in :accountIds]; 

        // Ensure we're within limits to be able to fire a queueable for each account in requests
        if (Limits.getQueueableJobs() < Limits.getLimitQueueableJobs() && debtorsToDelete.size() < 40) {
            if(debtorsToDelete.size() > 0){
                System.enqueueJob(new BillectaDeleteDebtorAsync(debtorsToDelete));
            }
            
        } else {
            // Start a batch to handle all requests.
            BillectaDeleteDebtorsBatch batchjob = new BillectaDeleteDebtorsBatch(debtorsToDelete);
            // process 40 records in each batch (max 50 in each as queueables are started for each account)
            Database.executeBatch(batchjob, 40);       
        }
    }
}