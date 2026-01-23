/**
 * @description       : Utility class for building queries to delete old records based on retention periods
 * @author            : Malin Nilsson (Stretch Customer AB)
 * @group             : 
 * @last modified on  : 2025-04-28
 * @last modified by  : Malin Nilsson (Stretch Customer AB)
**/
public with sharing class RecordDeletionUtils {
    
    // Constants
    private static final Integer DEFAULT_RETENTION_YEARS = 10;
    
    // Custom retention period in years for mapped for unique account membership statuses
    // This is not currently used but keeping it here as it probably will be used in the future (2025-04-15)
    private static final Map<String, Integer> ACCOUNT_STATUS_RETENTION_MAP = new Map<String, Integer>{
        'Avliden' => 1,    // delete after 1 year
        'Utesluten' => 1,  // delete after 1 year
        'Avslutad' => 1,   // delete after 1 year
        'Ej medlem' => 1   // delete after 1 year
    };
    
    /**
     * Builds a query for Tasks that are older than the retention period
     * @return String The SOQL query
     */
    public static String buildTaskQuery() {
        return buildRetentionQuery('Task', 'What.Type', 'Account');
    }
    
    /**
     * Builds a query for EmailMessages that are older than the retention period
     * @return String The SOQL query
     */
    public static String buildEmailMessageQuery() {
        return buildRetentionQuery('EmailMessage', 'RelatedTo.Type', 'Account');
    }

    /**
     * Builds a query for IndividualEmailResult that are older than 3 months (93 days)
     * @return String The SOQL query
     */
    public static String buildIndividualEmailResultQuery() {
        return 'select id from et4ae5__IndividualEmailResult__c where CreatedDate < N_DAYS_AGO:93 limit 100000';
    }


     /* Collects invoices which
     * are created more than one year ago and has the paymentStatus 'Betald'/'Makulerad'/'Pausad'
     * OR if the invoice is older than 5 years (1827 days = 365*5 + 2, 2 for leapyears) and has a payment status = 'Ej betald'/'Delbetald'
     */
    public static String buildInvoiceQuery() {
        return 'select id from Invoice__c where (CreatedDate < N_DAYS_AGO:365 AND (PaymentStatus__c  = \'Betald\' OR PaymentStatus__c = \'Makulerad\' OR PaymentStatus__c = \'Pausad\')) OR (CreatedDate < N_DAYS_AGO:1827 AND (PaymentStatus__c = \'Ej betald\' OR PaymentStatus__c = \'Delbetald\')) order by CreatedDate asc limit 100000';
    }
    
    /**
     * Builds the base query for record deletion
     * The result query should look like this:
     * SELECT Id, CreatedDate FROM EmailMessage WHERE RelatedTo.Type = 'Account' AND IsDeleted = false AND (CreatedDate < 2015-04-25T00:00:00Z) Order By CreatedDate ASC ALL ROWS
     * @param objectName The name of the object to query, 
     * @param relationshipField The field name that relates to a filter, e.g. 'What.Type' or 'RelatedTo.Type'
     * @param relationshipFilter The filter to apply to the relationship field, e.g. 'Account' or 'Case'
     * @return String The base SOQL query
     */
    private static String buildRetentionQuery(String objectName, String relationshipField, String relationshipFilter) {
        String tenYearsAgo = getRetentionDate(DEFAULT_RETENTION_YEARS);
        String testRetentionDate = getRetentionDate(3);

        if(objectName == 'EmailMessage') {
            System.debug('objectName: ' + objectName);
            System.debug('relationshipField: ' + relationshipField);
            System.debug('relationshipFilter: ' + relationshipFilter);
        }
        
        String query = 'SELECT Id, CreatedDate FROM ' + objectName + 
                      ' WHERE ' + relationshipField + ' = \'' + relationshipFilter + '\'' +
                      ' AND IsDeleted = false'; // don't return records already in the recyclebin
        query += ' AND (';
        
         // TODO in future: Add the custom retention period for specific account membership statuses
        // Add retention date conditions based on Account membership status
      
        // for (String status : ACCOUNT_STATUS_RETENTION_MAP.keySet()) {
        //     Integer retentionYears = ACCOUNT_STATUS_RETENTION_MAP.get(status);
        //     String retentionDate = getRetentionDate(retentionYears);
        //     query += '(Account.Status__c = \'' + status + '\' AND CreatedDate < ' + retentionDate + ') OR ';
        // }
        
        // Add default retention period
        if(!GenericUtils.isSandbox()) { // if not sandbox, use default retention period 
            query += '(CreatedDate < ' + tenYearsAgo + '))';
        } else {
            query += '(CreatedDate < ' + testRetentionDate + '))'; // test retention date = 3 year
        }
        query += ' Order By CreatedDate ASC ALL ROWS'; // ALL ROWS is important to return Tasks that have been archived
        return query;
    }
    
    /**
     * Calculates the retention date based on the number of years
     * @param retentionYears Number of years to retain records
     * @return String The formatted retention date in SOQL format (YYYY-MM-DDTHH:MM:SSZ)
     */
    private static String getRetentionDate(Integer retentionYears) {
        // using Date.today() to get the current date in the UTC timezone, and where time is automatically set to 00:00:00 when parsing to DateTime
        DateTime retentionDateTime = Date.today().addYears(-retentionYears);
        return retentionDateTime.formatGmt('yyyy-MM-dd\'T\'HH:mm:ss\'Z\'');
    }
}