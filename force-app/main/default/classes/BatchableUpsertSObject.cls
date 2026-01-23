/**
 * Class to help batch DML:s. At this point only update / insert is supported
 * @author Jenny Blomberg
 * @since 2023-02-03
 */
global class BatchableUpsertSObject implements Database.Batchable<sObject> {
    
    public List<SObject> recordsToUpsert;
    public String dmlOperation;
    public class dmlNotSupportedException extends Exception {}

    /**
     * Constructor to help batch DML operations
     * @param records records to be updated or inserted
     * @param dmlOperationType insert or update
     * @exception 
     */
    global BatchableUpsertSObject(List<SObject> records, String dmlOperationType) {
        if(dmlOperationType == 'insert' || dmlOperationType == 'update'){
            this.recordsToUpsert = new List<SObject>();
            this.recordsToUpsert = records;
            this.dmlOperation = dmlOperationType;
        }else{
            throw new dmlNotSupportedException('Only "update" OR "insert" is valid as input in parameter "dmlOperationType" ');
        }
      }
    
    global Iterable<SObject> start(Database.BatchableContext bc) {
        return recordsToUpsert;
    }

    global void execute(Database.BatchableContext BC, List<sObject> scope) {
        System.debug('----- Starting to ' + this.dmlOperation + ' records in Batch -------');
        System.debug('-----'+ this.recordsToUpsert.size()+ '-------');
        List<SaveResultInvocable.Request> requestList = new List<SaveResultInvocable.Request>();
        SaveResultInvocable.Request request = new SaveResultInvocable.Request();
        request.records = scope;
        request.dmlOperationType = this.dmlOperation;
        requestList.add(request);

   
        List<SaveResultInvocable.Result> results =  SaveResultInvocable.SaveResultInvocable(requestList);
        System.debug(results[0].errorMessages);
    } 
    
    global void finish(Database.BatchableContext BC) {
        
    }
    
}