/**
 * @description       : Never send in more than 50 records for each batch. THis will trigger a queueable for each acocunt in scope. 
 *                      Max 50 queueables per batch
 * @author            : Malin Nilsson (Stretch Customer AB)
 * @group             : 
 * @last modified on  : 2024-12-06
 * @last modified by  : Malin Nilsson (Stretch Customer AB)
**/
public with sharing class BillectaDeleteDebtorsBatch implements Database.Batchable<sObject>{
     // Holds records to process
    private List<Account> accsToProcess;

    public BillectaDeleteDebtorsBatch(List<Account> accountsToProcess) {
        this.accsToProcess = accountsToProcess;
    }

    public Iterable<Account> start(Database.BatchableContext bc) {
  
        return (Iterable<Account>)this.accsToProcess;   
    }
  
    public void execute(Database.BatchableContext bc, List<Account> scope) { 

        System.debug('----------- INIT Batch job for BillectaDeleteDebtorsBatch jobId '+ bc.getJobId() +' -------------');
        if(scope.size() > 0){
            System.enqueueJob(new BillectaDeleteDebtorAsync(scope));
        }
  }

  public void finish(Database.BatchableContext bc){
     System.debug('----------- FINISH Batch job for BillectaDeleteDebtorsBatch jobId '+ bc.getJobId() +' -------------');
  }
}