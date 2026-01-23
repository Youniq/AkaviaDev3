/**
 * @description       : 
 * @author            : Malin Nilsson (Stretch Customer AB)
 * @group             : 
 * @last modified on  : 2024-11-18
 * @last modified by  : Malin Nilsson (Stretch Customer AB)
**/
public with sharing class McDeleteContactsAsync implements Queueable, Database.AllowsCallouts { 

    private static final string endpoint = '/contacts/v1/contacts/actions/delete?type=keys';
    private Id singleAccToDelete;

    public McDeleteContactsAsync(){
        // Used by the scheduled job, apex class 'ScheduleDeleteMcContacts'.
     }

    // Used whn coming from invocable method to delete a single person from Marketing Cloud (MC)
    public McDeleteContactsAsync(Id accId){
        this.singleAccToDelete = accId;
    }



    public void execute(QueueableContext context) {
         // Get callout-record by jobId
            Callout__c currCallout = [Select Id, Status__c, Request__c, Response__c,
                                        Path__c, Code__c,
                                        ErrorLog__c from Callout__c where jobId__c = :context.getJobId()];
        try {

            List<Account> toMcDelete;
            if(this.singleAccToDelete != null) {
                // Coming here when request is to delete single account
                toMcDelete =  [SELECT Id, ContactCaseSafeID__c, DeletedFromMc__c, SyncWithMc__c FROM Account 
                                WHERE IsPersonAccount = true
                                AND Id = :this.singleAccToDelete];

            }
            else {
                // In case we are about to delete contacts in MC from out scheduled job
                Integer deleteLimit = getContactDeleteLimit();
                Date sixMonthsAgo =  Date.today().addMonths(-6);

                if(Test.isRunningTest()){
                    // Skip the full query for running tests
                    toMcDelete = [SELECT Id, ContactCaseSafeID__c, DeletedFromMc__c, SyncWithMc__c FROM Account 
                                            WHERE IsPersonAccount = true 
                                            AND SyncWithMc__c = false 
                                            AND DeletedFromMc__c = false limit :deleteLimit];
                } else {
                    // Running live
                    toMcDelete = [SELECT Id, ContactCaseSafeID__c, DeletedFromMc__c, SyncWithMc__c FROM Account 
                                                WHERE IsPersonAccount = true 
                                                AND SyncWithMc__c = false 
                                                AND MemberPhase__c = 'Avslutad' 
                                                AND (MembershipStatus__c = 'Avliden' OR CancellationDate__c < :sixMonthsAgo) 
                                                AND DeletedFromMc__c = false limit :deleteLimit];
                }
            }

            List<String> mcKeysToDelete = new List<String>();
            for(Account a : toMcDelete){
                // ContactCaseSafeID__c is used as Contact Key in Marketing Cloud. Like the external id
                mcKeysToDelete.add(a.ContactCaseSafeID__c);
            }

            // Setting up the request body
            DeleteByKeyRequest reqData = new DeleteByKeyRequest();
            reqData.values = mcKeysToDelete; // Commented away for test-purposes.
            reqData.DeleteOperationType = 'ContactAndAttributes';
            Boolean success = sendDeleteRequest(reqData, currCallout);

        if(success){
            setSfAccountMcDeleted(toMcDelete);  // Commented away for test-purposes.
        }
        } catch(Exception e){
            currCallout.Status__c = 'Failed';
            currCallout.ErrorLog__c = e.getMessage() + '\n \n' + e.getStackTraceString();
             System.debug('Delete Request error: ' + e);
        }
        finally{
            update currCallout;
        }
    }

    private Boolean sendDeleteRequest(DeleteByKeyRequest reqData, Callout__c currCallout) {
        Http http = new Http();
        HttpResponse res;
        HttpRequest req = new HttpRequest();
        String baseUrl = 'callout:MarketingCloudInteg'; // There's only a prod version in MC

        req.setMethod('POST');
        req.setEndpoint(baseUrl + endpoint);
        req.setHeader(GlobalConstants.HTTP_HEADER_FIELD_NAME_CONTENT_TYPE, GlobalConstants.HTTP_HEADER_FIELD_CONTENT_TYPE_VALUE_APPLICATION_JSON);

        // Set the request body
        String bodyAsString = reqData.toJson();
        req.setBodyAsBlob(Blob.valueof(bodyAsString));

        currCallout.Request__c = bodyAsString;
        currCallout.Path__c = req.getEndpoint();

        res = http.send(req);
        currCallout.Response__c = res.getBody();
        currCallout.code__c = String.valueOf(res.getStatusCode());

        if (res.getStatusCode() == 200 || res.getStatusCode() == 201) {
            currCallout.Status__c = 'OK';
            System.debug('Delete Request success: ' + res.toString());
            System.debug('Delete Request success: ' + res.getBody());
        } else {
            currCallout.Status__c = 'Failed';
            System.debug('Delete Request failed: ' + res.toString());
            System.debug('Delete Request failed: ' + res.getBody());
        }
       

        return currCallout.Status__c == 'OK' ? true : false;
    }

    private void setSfAccountMcDeleted(List<Account> accounts ){

        for(Account a : accounts){
            a.DeletedFromMc__c = true;
        }
        update accounts;
    }

    private Integer getContactDeleteLimit(){
        McSetting__c setting = McSetting__c.getOrgDefaults();

        if(setting == null) {
            throw new IllegalArgumentException('Custom Settings McSetting__c not set. Aborting job.');
        }
        else if(setting.ContactDeleteLimit__c == null || setting.ContactDeleteLimit__c <=0)
        {
            throw new IllegalArgumentException('Custom Settings McSetting__c.ContactDeletionLimit__c value must have a positive value! Aborting job.');
        }
        else {
            // Success:
             System.debug(LoggingLevel.DEBUG, 'contactDeleteLimit: ' + (Integer)setting.ContactDeleteLimit__c);
            return (Integer)setting.ContactDeleteLimit__c;
        }      
    }

    private class DeleteByKeyRequest{
        public List<String> values;
        public String DeleteOperationType;

        // Method to serialize the request to JSON
        public String toJson() {
            return JSON.serialize(this);
        }
    }
}