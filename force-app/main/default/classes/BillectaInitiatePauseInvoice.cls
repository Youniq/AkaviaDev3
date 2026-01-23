/*
 * Author @ Jenny Blomberg
 * Invocable class to make callout to Billect to pause all active invoices on a member (debtor)
 */

public without sharing class BillectaInitiatePauseInvoice {
    
    @Invocablemethod
    public static void pauseInvoice(List<String> AccountRecordIds){
        List<Callout__c> calloutsScheduled = new List<Callout__c>(); 
        List<Invoice__c> invoices = [SELECT Id, BillectaID__c, Person__c
                                    FROM Invoice__c WHERE Person__c IN: AccountRecordIds AND (PaymentStatus__c = 'Ej betald' OR PaymentStatus__c = 'Delbetald')];

        Map<Id, Account> idToAccMap = new Map<Id, Account>([SELECT Id, BillectaID__c FROM Account WHERE Id IN: AccountRecordIds]);
        if(invoices.size() > 0){
            for(Invoice__c inv: invoices){
            
                Id jobId = System.enqueueJob(new BillectaSendInvoiceAsync(idToAccMap.get(inv.Person__c), inv));
            	   System.debug('-----------JOB ID-------------' + jobId);
            	   calloutsScheduled.add(new Callout__c(jobId__c = jobId, 
                                                 Type__c = 'Billecta - Pause Invoice',
                                                 Account__c = inv.Person__c,
                                                 Invoice__c = inv.Id,
                                                 Status__c = 'Queued'));
            }
       
            //Insert Callout__c records
            if(calloutsScheduled.size() > 0){
                System.debug('--- Create Callouts ---');
                try {
                    insert calloutsScheduled;
                } catch(exception e) {
                    System.debug('--- Error inserting Callouts --- ' + calloutsScheduled);
                    ApexLog.Error logError = new ApexLog.Error('BillectaInitiatePauseInvoice', 'pauseInvoice', true, e);
                    ApexLog.createLogDebug(logError);
                }
                System.debug('--- Created Callouts ---' + calloutsScheduled);        
            
            }
        }        
    }
}