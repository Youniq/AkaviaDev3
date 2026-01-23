/**
 * Invocable method to be used by flow ()
 * to update a workplace or employer from BASUN (BBC)
 * @author Jenny Blomberg
 * @since 2023-04-27
 */
public with sharing class BasunUpdateInvocable {

    /**
     * Wrapper class to hold input values fot he invocable method
     */
    public class FlowInputs {
        @InvocableVariable
        public String basunId;

        @InvocableVariable
        public String recordTypeDevName;
      }
    
    
    @InvocableMethod(label='Get Workplace/Employer info' description='Update Worksite/Company account from BBC')
    public static void getAccountInfo(List<FlowInputs> requests) {
      
        Set<String> workplaceBasunIds = new Set<String>();
        Set<String> employerBasunIds = new Set<String>();

        for(FlowInputs fi: requests){
            switch on fi.recordTypeDevName {
                when 'Workplace' {
                    workplaceBasunIds.add(fi.basunId);
                }
                when 'Employer'{
                    employerBasunIds.add(fi.basunId);
                }
                when else {
                    continue;
                }
            }
           
        }

        if(!workplaceBasunIds.isEmpty()){
            DownloadWorksiteBatchable cb = new DownloadWorksiteBatchable(workplaceBasunIds);
            Database.executeBatch(cb, 10);
        }
        if(!employerBasunIds.isEmpty()){
            DownloadCompanyBatchable cb = new DownloadCompanyBatchable(employerBasunIds);
            Database.executeBatch(cb, 10);
        }
        
    }
}