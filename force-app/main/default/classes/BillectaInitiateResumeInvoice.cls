public class BillectaInitiateResumeInvoice {

    @Invocablemethod
    public static void resumeInvoice (List<String> AccountRecordIds){
        List<Callout__c> calloutsToSchedule = new List<Callout__c>();
        List<Invoice__c> invoices = [SELECT Id, BillectaID__c, Person__c 
                                     FROM Invoice__c WHERE Person__c IN: AccountRecordIds AND PaymentStatus__c = 'Pausad'];
        
        Map<Id, Account> idToAccMap = new Map<Id, Account>([SELECT Id, BillectaID__c FROM Account WHERE Id IN: AccountRecordIds]);
        if(invoices.size() > 0){
            for(Invoice__c inv: invoices){
            
                Id jobId = System.enqueueJob(new BillectaSendInvoiceAsync(idToAccMap.get(inv.Person__c), inv));
                   System.debug('-----------JOB ID-------------' + jobId);
                   calloutsToSchedule.add(new Callout__c(jobId__c = jobId, 
                                                 Type__c = 'Billecta - Resume Invoice',
                                                 Account__c = inv.Person__c,
                                                 Invoice__c = inv.Id,
                                                 Status__c = 'Queued'));
        
            }
            
            if(calloutsToSchedule.size() > 0){
                System.debug('--- Create Callouts ---');
                try {
                    insert calloutsToSchedule;
                } catch(exception e) {
                    System.debug('--- Error inserting Callouts --- ' + calloutsToSchedule);
                    ApexLog.Error logError = new ApexLog.Error('BillectaInitiateResumeInvoice', 'resumeInvoice', true, e);
                    ApexLog.createLogDebug(logError);
                }
                System.debug('--- Created Callouts ---' + calloutsToSchedule);        
                
            }
            
        }
    }
}