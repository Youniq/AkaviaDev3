/**
 * Controller class for exporting employment data (for members employed by a given employer) to Excel format
 * Used by LWC components to generate Excel files with member information
 */
public without sharing class MemberExportController {
    
    /**
     * Exports member data to Excel format
     * Priority 1: If employerId is provided, export members for that employer
     * Priority 2: If associationId is provided, export members for all employers under that association
     * @param employerId The Account ID of the employer (Priority 1)
     * @param associationId The Association__c ID (Priority 2)
     * @return JSON string of member data for Excel generation
     */
    @AuraEnabled(cacheable=false)
    public static String exportMembersToExcel(Id employerId, Id associationId) {
        try {
            // Validate input
            if (employerId == null && associationId == null) {
                throw new AuraHandledException('Either Employer ID or Association ID is required');
            }
            
            // Validate user access
            if (!validateAccess(employerId, associationId)) {
                throw new AuraHandledException('Access denied. You do not have permission to export member data.');
            }
            
            // Get employer IDs (single or multiple based on input)
            Set<Id> employerIds = getEmployerIds(employerId, associationId);
            
            // Retrieve and transform member data
            List<MemberExportData> memberData = getMemberDataForEmployers(employerIds);
            
            // Return JSON data for client-side Excel generation
            return JSON.serialize(memberData);
            
        } catch (Exception e) {
            System.debug('Error in exportMembersToExcel: ' + e.getMessage());
            throw new AuraHandledException('Error exporting members: ' + e.getMessage());
        }
    }
    
    /**
     * Validates if the current user has access to export member data
     * Handles both single employer and association-wide export scenarios
     * @param employerId The Account ID of the employer (if single employer export)
     * @param associationId The Association__c ID (if association export)
     * @return Boolean indicating if user has access
     */
    public static Boolean validateAccess(Id employerId, Id associationId) {
        try {
            // Check CRUD permissions
            if (!Schema.sObjectType.User.isAccessible()) {
                System.debug(LoggingLevel.ERROR,'MemberExportController.validateAccess: User has no access to User object');
                return false;
            }
            
            // Get current user information
            User currentUser = [SELECT Id, Profile.Name, Contact.AccountId 
                               FROM User 
                               WHERE Id = :UserInfo.getUserId() 
                               LIMIT 1];
            
            // Admin users have full access
            if (currentUser.Profile.Name.containsIgnoreCase('Admin')) {
                return true;
            }
            
            // Reject if user does not have 'Akavia Member' profile
            if (currentUser.Profile.Name != 'Akavia Member') {
                System.debug(LoggingLevel.ERROR,'MemberExportController.validateAccess: User has no Akavia Member profile');
                return false;
            }
            
            // Get user's person account ID
            Id personAccountId = currentUser?.Contact?.AccountId;
            if (personAccountId == null) {
                System.debug(LoggingLevel.ERROR,'MemberExportController.validateAccess: User has no person account');
                return false;
            }
            
            Id targetAssociationId;
            
            // Determine which association to validate against
            if (employerId != null) {
                // Single employer: Get employer's association
                List<Account> employers = [SELECT Id, Association__c 
                                   FROM Account 
                                   WHERE Id = :employerId 
                                   LIMIT 1];
                
                // Reject if employer has no association assigned
                if (employers.isEmpty() || employers[0]?.Association__c == null) {
                    System.debug(LoggingLevel.ERROR,'MemberExportController.validateAccess: Employer has no Association');
                    return false;
                }
                
                targetAssociationId = employers[0].Association__c;
            } else if (associationId != null) {
                // Association export: Use the provided association ID
                targetAssociationId = associationId;
                
                // Verify at least one employer exists under this association
                List<Account> employersInAssociation = [SELECT Id 
                                                        FROM Account 
                                                        WHERE Association__c = :associationId 
                                                        LIMIT 1];
                
                if (employersInAssociation.isEmpty()) {
                    System.debug(LoggingLevel.ERROR,'MemberExportController.validateAccess: No employers found for association');
                    return false;
                }
            } else {
                System.debug(LoggingLevel.ERROR,'MemberExportController.validateAccess: Neither employerId nor associationId provided');
                return false;
            }
            
            // Query for active assignments with required criteria
            List<Assignment__c> userAssignments = [SELECT Id, AssignmentAssociation__c 
                                                  FROM Assignment__c 
                                                  WHERE Person__c = :personAccountId 
                                                  AND Status__c = 'Aktiv' 
                                                  AND Type__c = 'Lokalt Förtroendevald' 
                                                  AND Role__c IN ('Ordförande, vice', 'Ordförande', 'Medlemsadministratör') 
                                                  AND AssignmentAssociation__c = :targetAssociationId
                                                  LIMIT 1];
            
            // Check if user has any qualifying assignments
            if (userAssignments.isEmpty()) {
                System.debug(LoggingLevel.ERROR,'MemberExportController.validateAccess: User has no assignments qualifying for export');
                return false;
            }

            return true;
            
        } catch (Exception e) {
            System.debug('Error in validateAccess: ' + e.getMessage());
            return false;
        }
    }
    
    /**
     * Retrieves member data for a set of employers
     * Works for both single employer and multiple employers under an association
     * @param employerIds Set of employer Account IDs
     * @return List of MemberExportData objects
     */
    private static List<MemberExportData> getMemberDataForEmployers(Set<Id> employerIds) {
        try {
            // Query employments for all specified employers
            List<Employment__c> employments = [SELECT Id, StartDate__c, Workplace__r.Name, Workplace__r.parent.Name, Workplace__r.ShippingCity, 
                          Workplace__r.WorkplaceNumber__c, Person__r.Id, Person__r.MemberNumber__c, 
                          Person__r.FirstName, Person__r.LastName, Person__r.PersonEmail, 
                          Person__r.PersonMobilePhone, Person__r.CurrentEmployer__r.Name, 
                          Person__r.LatestMembershipDate__c, Person__r.MembershipCategory__c 
                          FROM Employment__c 
                          WHERE Status__c = 'Aktiv' 
                          AND Hidden__c = false
                          AND Workplace__r.ParentId IN :employerIds
                          AND Person__r.MembershipStatus__c IN ('Aktiv','Begärt utträde') 
                          ORDER BY Person__r.MemberNumber__c 
                          LIMIT 5000];
            
            if (employments.isEmpty()) {
                throw new AuraHandledException('No members found for the specified employer(s).');
            }
                          
            List<MemberExportData> memberData = new List<MemberExportData>();
            
            try {
                for (Employment__c employment : employments) {
                    memberData.add(transformEmploymentToExportData(employment));
                }
            } catch(Exception e) {
                System.debug('Error processing member data: ' + e.getMessage());
                throw new AuraHandledException('Error processing member data: ' + e.getMessage());
            }
            
            return memberData;
            
        } catch(Exception e) {
            System.debug('Error querying member data: ' + e.getMessage());
            throw new AuraHandledException('Error querying member data: ' + e.getMessage());
        }
    }
    
    /**
     * Gets employer IDs based on either single employerId or associationId
     * @param employerId The Account ID of the employer (if provided)
     * @param associationId The Association__c ID (if provided)
     * @return Set of employer IDs
     */
    private static Set<Id> getEmployerIds(Id employerId, Id associationId) {
        Set<Id> employerIds = new Set<Id>();
        
        // Priority 1: Single employer
        if (employerId != null) {
            employerIds.add(employerId);
            return employerIds;
        }
        
        // Priority 2: All employers under association
        if (associationId != null) {
            List<Account> employers = [SELECT Id 
                                       FROM Account 
                                       WHERE Association__c = :associationId];
            
            if (employers.isEmpty()) {
                throw new AuraHandledException('No employers found for the specified association.');
            }
            
            for (Account employer : employers) {
                employerIds.add(employer.Id);
            }
            return employerIds;
        }
        
        // Should never reach here due to validation in main method
        throw new AuraHandledException('Either Employer ID or Association ID is required');
    }
    
    /**
     * Transforms Employment__c record to MemberExportData wrapper
     * @param employment The Employment__c record to transform
     * @return MemberExportData object
     */
    private static MemberExportData transformEmploymentToExportData(Employment__c employment) {
        MemberExportData data = new MemberExportData();
        data.medlemsnummer = employment.Person__r.MemberNumber__c;
        data.fornamn = employment.Person__r.FirstName;
        data.efternamn = employment.Person__r.LastName;
        data.epost = employment.Person__r.PersonEmail;
        data.mobil = employment.Person__r.PersonMobilePhone;
        data.aktuellArbetsgivare = employment.Workplace__r.parent.Name;
        data.senasteMedlemsdatum = employment.Person__r.LatestMembershipDate__c;
        data.medlemskategori = employment.Person__r.MembershipCategory__c;
        data.senasteAnstallningensStartdatum = employment.StartDate__c;
        data.arbetsstallenamn = employment.Workplace__r.Name;
        data.arbetsstalletsOrt = employment.Workplace__r.ShippingCity;
        data.arbetsstallenummer = employment.Workplace__r.WorkplaceNumber__c;
        return data;
    }
    
    
    /**
     * Wrapper class for member export data
     */
    public class MemberExportData {
        public String medlemsnummer;
        public String fornamn;
        public String efternamn;
        public String epost;
        public String mobil;
        public String aktuellArbetsgivare;
        public String arbetsstallenamn;
        public String arbetsstalletsOrt;
        public String arbetsstallenummer;
        public Date senasteMedlemsdatum;
        public String medlemskategori;
        public Date senasteAnstallningensStartdatum;
    }
}