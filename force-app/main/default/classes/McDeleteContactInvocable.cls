/**
 * @description       : 
 * @author            : Malin Nilsson (Stretch Customer AB)
 * @group             : 
 * @last modified on  : 2024-11-18
 * @last modified by  : Malin Nilsson (Stretch Customer AB)
**/
public with sharing class McDeleteContactInvocable {
  
    @InvocableMethod(label='Radera kontakt i Marketing Cloud' description='Tar bort en single kontakt i MC')
    public static void deleteContactInMc(List<Id> accIds){

        List<Callout__c> calloutsToCreate = new List<Callout__c>();

        for(Id accId : accIds){
            McDeleteContactsAsync queueable = new McDeleteContactsAsync(accId);
            Id jobId = System.enqueueJob(queueable);

            Callout__c callout = new Callout__c();
            callout.JobId__c = jobId;
            callout.Account__c = accId;
            callout.Type__c = 'Marketing Cloud - Delete contacts';
            // Set the status to 'Queued'
            callout.Status__c = 'Queued';
            calloutsToCreate.add(callout);
        }

        try {
            insert calloutsToCreate;
        } catch (Exception e){
            ApexLog.Error errLog = new ApexLog.Error('McDeleteContactInvocable', 'deleteContactInMc', false, e);
        }
    }
}