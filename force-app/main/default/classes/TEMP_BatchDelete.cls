/**
 * @description       : When you delete a rec (archived or not), it is first moved to the Recycle Bin (soft delete). Salesforce permanently deletes records from the Recycle Bin after 15 days.
 * @author            : Malin Nilsson (Stretch Customer AB)
 * @group             : 
 * @last modified on  : 2025-04-28
 * @last modified by  : Malin Nilsson (Stretch Customer AB)
**/
global class TEMP_BatchDelete implements Database.Batchable <SObject>, Database.Stateful {
	
    public static String DEFAULT_QUERY = 'SELECT Id, CreatedDate FROM SalesCostMonth__c';
    private String query;
    private Integer totalDeletedRecords = 0;
    
    global TEMP_BatchDelete(String q) {
        query = q;
    }
    
    global Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator(query);
    }
    
    global void execute(Database.BatchableContext bc, List<SObject> scope) {
        try {
            System.debug('*** EXECUTE - Processing batch of ' + scope.size() + ' records');
            
            if (!scope.isEmpty()) {
                Database.DeleteResult[] results = Database.delete(scope, false);
                
                // Log any failures
                for (Database.DeleteResult dr : results) {
                    if (!dr.isSuccess()) {
                        for (Database.Error err : dr.getErrors()) {
                            ApexLog.Error logError = new ApexLog.Error(
                                'TEMP_BatchDelete',
                                'execute',
                                true,
                                err
                            );
                            ApexLog.createLogDebug(logError);
                        }
                    } else {
                        totalDeletedRecords++;
                    }
                }
            }
        } catch (Exception e) {
            ApexLog.Error logError = new ApexLog.Error(
                'TEMP_BatchDelete',
                'execute',
                true,
                e
            );
            ApexLog.createLogDebug(logError);
        }
    }
    
    global void finish(Database.BatchableContext bc) {
        ApexLog.Information logInfo = new ApexLog.Information(
            'TEMP_BatchDelete',
            'finish()',
            false,
            'Batch deletion completed. Total records deleted: ' + totalDeletedRecords + '.',
            'Query used: ' + query
        );
        ApexLog.createLogDebug(logInfo);
        System.debug('*** BATCH COMPLETED');
    }
}