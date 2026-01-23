public class MigrateGDPRStatusBatchable implements Database.Batchable<sObject>{
    public final String Query;
    public final Date CancelIntervalStart;
    public final Date CancelIntervalEnd;
   	public final String FieldValue;
    static final String FieldName = 'GDPRStatus__c';
    
    public MigrateGDPRStatusBatchable (String q, Date startDate, Date endDate, String v){
        Query = q; 
        CancelIntervalStart = startDate;
        CancelIntervalEnd = endDate;
        FieldValue = v;
    }
    
    public Database.QueryLocator start(Database.BatchableContext BC){
        return Database.getQueryLocator(Query);
    }
    
    public void execute(Database.BatchableContext BC, List<Account> scope){
        try {
            for(Account acc : scope)
        	{
            	acc.put(FieldName, FieldValue);               
        	}      
            update scope;   
          } 
        catch (Exception ex) {
          System.debug(
            '#### ERROR MigrateGDPRStatusBatchable #### ' + 
            'Cause --> ' +
            ex.getCause() +
            'Message --> ' +
            ex.getMessage()
          );
          System.debug(
            'tackTrace --> ' +
            ex.getStackTraceString() +
            'LineNumber --> ' +
            ex.getLineNumber()
          );
        }
    }

    
    public void finish(Database.BatchableContext BC){
        // Get the ID of the AsyncApexJob representing this batch job
       // from Database.BatchableContext.
       // Query the AsyncApexJob object to retrieve the current job's information.
       AsyncApexJob a = [SELECT Id, Status, NumberOfErrors, JobItemsProcessed,
          TotalJobItems, CreatedBy.Email
          FROM AsyncApexJob WHERE Id =
          :BC.getJobId()];
        
       String finishMsg = 'The GDPR Bbatch Apex job processed ' + a.TotalJobItems +
       ' batches with '+ a.NumberOfErrors + ' failures.';
       System.debug(finishMsg);
        
       // Send an email to the Apex job's submitter notifying of job completion.
       //Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
       //String[] toAddresses = new String[] {a.CreatedBy.Email};
       //mail.setToAddresses(toAddresses);
       //mail.setSubject('Apex Sharing Recalculation ' + a.Status);
       //mail.setPlainTextBody(finishMsg);
       //Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });
    }
}