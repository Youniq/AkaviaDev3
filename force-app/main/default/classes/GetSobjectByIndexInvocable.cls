/**
 * @description    : Invocable Apex class that retrieves a specific SObject from a list based on its index position.
 *                   This class can be called from Flow Builder to get a single record from a collection of records.
 * @author         : Malin Nilsson (Stretch Customer AB)
 * @group          : Utilities
 * @last modified on  : 2026-01-09
 * @last modified by  : Malin Nilsson (Stretch Customer AB)
**/
public with sharing class GetSobjectByIndexInvocable {
    
    /**
     * @description Invocable method that returns a single SObject from a list based on the specified index
     * @param params List of InputParams containing the record list and desired index
     * @return List<SObject> A list containing the single SObject found at the specified index (or null if not found)
     */
    @InvocableMethod(label='Get SObject By Index' 
                     description='Returns a single SObject from a list based on the specified index')
    public static List<SObject> getSObjectByIndex(List<InputParams> params) {
        List<SObject> results = new List<SObject>();
        
        System.debug('getSObjectByIndex params: ' + params);
        for(InputParams param : params) {
            // Return null if the input list is empty or index is negative
            if(param.recordList == null || param.recordList.isEmpty() || param.index < 0) {
                results.add(null);
                continue;
            }
            
            // Return null if the index is out of bounds
            if(param.index >= param.recordList.size()) {
                results.add(null);
                continue;
            }
            
            // Return the SObject at the specified index
            results.add(param.recordList[param.index]);
        }
        System.debug('getSObjectByIndex results: ' + results);
        return results;
    }
    
    /**
     * @description Inner class to hold the input parameters for the invocable method
     */
    public class InputParams {
        @InvocableVariable(required=true label='List of SObjects' description='The list of SObjects to search through')
        public List<SObject> recordList;
        
        @InvocableVariable(required=true label='Index' description='The index of the record to retrieve (the first record is index 0, second record is index 1, etc.)')
        public Integer index;
    }
}