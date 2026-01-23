/**
 * @description       : 
 * @author            : Malin Nilsson (Stretch Customer AB)
 * @group             : 
 * @last modified on  : 2024-12-16
 * @last modified by  : Malin Nilsson (Stretch Customer AB)
**/
public with sharing class BillectaDeleteDebtorAsync implements Queueable, Database.AllowsCallouts {
    private List<Account> accounts;  // The field BillectaId__c must be loaded on  the Accouns.
    
    public BillectaDeleteDebtorAsync(List<Account> accounts) {
        this.accounts = accounts;
    }

     public void execute(QueueableContext context) {
        System.debug('----------- INIT Queueable job for BillectaDeleteDebtorAsync jobId '+ context.getJobId() +' -------------');

        List<Callout__c> calloutsToCreate = new List<Callout__c>();
        List<Account> accountsToUpdate = new List<Account>();
        Boolean errorOccured = false;
        Id jobId = context.getJobId();

        for(Account acc: this.accounts){
            Callout__c currCallout = new Callout__c();
                currCallout.jobId__c = jobId;
                currCallout.Status__c = 'Queued';
                currCallout.Type__c = 'Billecta - Delete Debtor';
                currCallout.Account__c = acc.Id;
                currCallout.sentOn__c = Datetime.now();

                try {

                currCallout = deleteFromBillecta(currCallout, acc);

                // Empty billecta Id on account after deleting debtor in Billecta
                Account accToBeUpdated = new Account();
                accToBeUpdated.Id = acc.Id;
                accToBeUpdated.BillectaId__c = null;
                accountsToUpdate.add(accToBeUpdated);

                } catch (Exception e){
                    errorOccured = true;
                
                    currCallout.status__c = 'Failed';
                    currCallout.errorLog__c =  e.getMessage();
                    System.debug('Caught Exception: ' + e.getMessage());

                } finally {
                    calloutsToCreate.add(currCallout);
                }
        }

        try {
            update accountsToUpdate;
            insert calloutsToCreate;
        } catch(Exception e) {
            System.debug(e.getMessage());
            ApexLog.Error err = new ApexLog.Error('BillectaDeleteDebtorAsync', 'execute on dml accounts & callout logs', true, e);
            ApexLog.createLogDebug(err);
        }
    }

    /**
    * @description - Sends a callout to Billecta, attempting to delete debtor.
    * @author Malin Nilsson (Stretch Customer AB) | 2024-12-02 
    * @param co - CalloutOut__c
    * @return Callout__c - the callout record 
    **/
    public Callout__c deleteFromBillecta(Callout__c co, Account acc){
     	Blob jsonPayload;	
        System.debug('*** deleteFromBillecta START ***');
 		
        Http http = new Http(); 
        HttpRequest request = new HttpRequest(); 
       	HttpResponse response = new HttpResponse();

        if(acc.BillectaID__c == null){
            throw new IllegalArgumentException('BillectaId__c is null on account ('+ acc.Id +'). Cannot delete debtor in Billecta. Cancelling job.');
        }  

        request = BillectaUtils.initBillectaRequest(request);
        request = BillectaUtils.DeleteDebtor(request, acc.BillectaId__c);
        System.debug('Request: ' + request); 
        
        co.path__c = request.getEndpoint();

        try {
            response = http.send(request);
        }
        catch(Exception e) {
            String error = e.getStackTraceString().replace('\n',' / ')+' - '+e.getMessage();
            throw new  CalloutException(error);
        }

        System.debug('Response Code: ' + response.getStatusCode());
        System.debug('Response Body: ' + response.getBody());


         if(response.getStatusCode()==200 ||response.getStatusCode()==201 ) {
                co.Response__c = response.getBody();
                co.Status__c = 'OK';
        
        }else {
            String err = co.errorLog__c+'<--APEX*****Billecta-->'+  ' Response Code ' + String.valueOf(response.getStatusCode()) + ': '+response.getBody();
            // Throw an exception to easier handle all errors in the same way in catch block. 
            throw new CalloutException(err);
        } 
        
        return co;
		
	}
}