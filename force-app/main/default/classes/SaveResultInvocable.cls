/**
 * A class with Invocable Method to enable Flows to save a List of SObjects without rollback if 
 * one or more records would fail during save. (the successful records will still be saved)
 * This can also be used from APEX ofc.
 * @author Jenny Blomberg
 * @since 2023-02-03
 */
public with sharing class SaveResultInvocable {
    /**
     * Custom Class to be used as input to invocable method
     */
    public class Request {
        @InvocableVariable
        public List<sObject> records;

        @InvocableVariable(label='Insert/Update' description='Insert or Update')
        public String dmlOperationType;
    }

    /**
     * Custom Class to be used as result to send back from invocable method
     */
    public class Result {
        @InvocableVariable(label='Successfull Records' description='Successfull Records' required=true)
        public List<sObject> successes = new List<sObject>();
        
        @InvocableVariable(label='Number of Successfull Records' description='Successfull Records' required=true)
        public Integer noOfsuccesses;

        @InvocableVariable(label='Number of Failed Records' description='Successfull Records' required=true)
        public Integer noOfFailedRecords;

        @InvocableVariable(label='Failed Records' description='Failed Records' required=true)
        public List<sObject> failedRecords = new List<sObject>();

        @InvocableVariable(label='Error Messages' description='Error Messages' required=true)
        public List<String> errorMessages = new List<String>();
    }

    /****************************************************************
     * @author: Jenny Blomberg
     * @date: 2023-01-12
     * @param: List<Request>
     * @return List<Result>
     * @description: Invocable method that can be called from flow. This will enable a flow to save / update records
     * without roll back if 1 ror more records fail
    *****************************************************************/ 
   @InvocableMethod(label='Insert or update records ' description='Input: if new account --> SSN, if existing account --> account')
   public static List<Result> SaveResultInvocable(List<Request> requests) {

       List<Result> results = new List<Result>();

       for (Request r: requests) {
            Result result = new result();
            switch on r.dmlOperationType {
                when 'insert' {
                    Database.SaveResult[] srList = Database.insert(r.records, false);

                    for (Database.SaveResult sr : srList) {
                        Integer recordIndex = srList.indexOf(sr);
                        if (sr.isSuccess()) {
                            // Operation was successful, so get the ID of the record that was processed
                            System.debug('Successfully inserted ID: ' + sr.getId());
                            result.successes.add(r.records[recordIndex]);
                        }
                        else {
                            // Operation failed, so get all errors
                            String errorMessage = '';                
                            for(Database.Error err : sr.getErrors()) {
                                errorMessage += err.getStatusCode() + ': ' + err.getMessage();
                            }
                            result.errorMessages.add(errorMessage);
                            result.failedRecords.add(r.records[recordIndex]);
                        }
                    }
                }
                when 'update' {
                    Database.SaveResult[] srList = Database.update(r.records, false);

                    for (Database.SaveResult sr : srList) {
                        Integer recordIndex = srList.indexOf(sr);
                        if (sr.isSuccess()) {
                            // Operation was successful, so get the ID of the record that was processed
                            System.debug('Successfully updated ID: ' + sr.getId());
                            result.successes.add(r.records[recordIndex]);
                        }
                        else {
                            // Operation failed, so get all errors
                            String errorMessage = '';                
                            for(Database.Error err : sr.getErrors()) {
                                errorMessage += ' Failed to update ID : ' + r.records[recordIndex].Id + ', ' + err.getStatusCode() + ': ' + err.getMessage() +'<br>';
                            }
                            result.errorMessages.add(errorMessage);
                            result.failedRecords.add(r.records[recordIndex]);
                        }
                    }        
                }
            }
            result.noOfFailedRecords = result.failedRecords.size();
            result.noOfsuccesses = result.successes.size();
            results.add(result);
       }

       return results;
    }
}