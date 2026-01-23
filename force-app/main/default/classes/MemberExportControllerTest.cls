/**
 * Test class for MemberExportController
 * Tests the member export functionality including SOQL queries, Excel generation, and user access validation
 */
@isTest
public class MemberExportControllerTest {
    
    @TestSetup
    static void setupTestData() {
        // Setup basic test data
        TestDataFactory.setupBasicTestData();
        
        // Create test association
        Association__c testAssociation = new Association__c(
            Name = 'Test Association',
            Type__c = 'Lokalförening',
            AssociationNumber__c = 'ASS001'
        );
        insert testAssociation;
        
        // Create second test association for negative testing
        Association__c testAssociation2 = new Association__c(
            Name = 'Test Association 2',
            Type__c = 'Lokalförening',
            AssociationNumber__c = 'ASS002'
        );
        insert testAssociation2;
        
        // Create test employer account with association
        Account employer = new Account(
            Name = 'Test Employer',
            Association__c = testAssociation.Id,
            RecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('Employer').getRecordTypeId()
        );
        insert employer;
        
        // Create second employer for same association
        Account employer2 = new Account(
            Name = 'Test Employer 2',
            Association__c = testAssociation.Id,
            RecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('Employer').getRecordTypeId()
        );
        insert employer2;
        
        // Create test workplace account
        Account workplace = new Account(
            Name = 'Test Workplace',
            ParentId = employer.Id,
            WorkplaceNumber__c = 'WP001',
            ShippingCity = 'Stockholm',
            RecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('Workplace').getRecordTypeId()
        );
        insert workplace;
        
        // Create test workplace for second employer
        Account workplace2 = new Account(
            Name = 'Test Workplace 2',
            ParentId = employer2.Id,
            WorkplaceNumber__c = 'WP002',
            ShippingCity = 'Gothenburg',
            RecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('Workplace').getRecordTypeId()
        );
        insert workplace2;
        
        // Create test person accounts using TestDataFactory
        TestDataFactorySetupParams params = new TestDataFactorySetupParams();
        params.numberOfAccounts = 5;
        params.numberOfEmployerAccounts = 1;
        params.numberOfWorkplaceAccounts = 1;
        params.addEmploymentsToMembers = true;
        params.addMembershipsToMembers = true;
        params.addAssignmentToMembers = true;
        
        TestDataFactory.setupTestData(params);
        
        // Get the created person accounts
        List<Account> personAccounts = [SELECT Id FROM Account WHERE IsPersonAccount = true LIMIT 5];
        
        // Update assignments to have the correct association and role
        List<Assignment__c> assignments = [SELECT Id, AssignmentAssociation__c, Type__c, Role__c, StartDate__c FROM Assignment__c WHERE Person__c IN :personAccounts];
        System.debug('assignments count: ' + assignments.size());
        for (Assignment__c assignment : assignments) {
            assignment.AssignmentAssociation__c = testAssociation.Id;
            assignment.Type__c = 'Lokalt Förtroendevald';
            assignment.Role__c = 'Ordförande';
            assignment.StartDate__c = Date.today().addDays(-30);
        }
        update assignments;


        // Update employments - split between two workplaces
        List<Employment__c> employments = [SELECT Id, Workplace__c FROM Employment__c];
        for (Integer i = 0; i < employments.size(); i++) {
            // First 3 employments to workplace1, rest to workplace2
            if (i < 3) {
                employments[i].Workplace__c = workplace.Id;
            } else {
                employments[i].Workplace__c = workplace2.Id;
            }
        }
        update employments;
    }
    
    @isTest
    static void testExportMembersToExcelSuccess() {

        // Get test data
        Account employer = [SELECT Id FROM Account WHERE Name = 'Test Employer' LIMIT 1];
        Account personAccount = [SELECT Id FROM Account WHERE IsPersonAccount = true LIMIT 1];
        
        // Get the Contact record for the person account
        Contact personContact = [SELECT Id FROM Contact WHERE AccountId = :personAccount.Id LIMIT 1];
        
        // Create member user with ContactId (required for portal users)
        User memberUser = createTestUser('Member User', 'Akavia Member', personContact.Id);
         String result;

        Test.startTest();
        System.runAs(memberUser) {
            result = MemberExportController.exportMembersToExcel(employer.Id, null);
        }
        Test.stopTest();
        
        // Verify result is not empty (JSON data)
        System.assertNotEquals(null, result, 'Export result should not be null');
        System.assert(result.length() > 0, 'Export result should contain data');
        
        // Verify it's valid JSON
        List<Object> parsedResult = (List<Object>) JSON.deserializeUntyped(result);
        System.assert(parsedResult.size() > 0, 'Parsed result should contain member data');
    }
    
    @isTest
    static void testExportMembersToExcelNullEmployerId() {
        Test.startTest();
        try {
            MemberExportController.exportMembersToExcel(null, null);
            System.assert(false, 'Expected exception was not thrown');
        } catch (AuraHandledException e) {
            System.debug('Error: ' + e.getMessage());
            Assert.isTrue(e != null,'e is null');
        }
        Test.stopTest();
    }
    
    @isTest
    static void testExportMembersByAssociationSuccess() {
        // Get test data
        Association__c association = [SELECT Id FROM Association__c WHERE Name = 'Test Association' LIMIT 1];
        Account personAccount = [SELECT Id FROM Account WHERE IsPersonAccount = true LIMIT 1];
        
        // Get the Contact record for the person account
        Contact personContact = [SELECT Id FROM Contact WHERE AccountId = :personAccount.Id LIMIT 1];
        
        // Create member user with ContactId (required for portal users)
        User memberUser = createTestUser('Member User Assoc', 'Akavia Member', personContact.Id);
        String result;

        Test.startTest();
        System.runAs(memberUser) {
            result = MemberExportController.exportMembersToExcel(null, association.Id);
        }
        Test.stopTest();
        
        // Verify result is not empty (JSON data)
        System.assertNotEquals(null, result, 'Export result should not be null');
        System.assert(result.length() > 0, 'Export result should contain data');
        
        // Verify it's valid JSON
        List<Object> parsedResult = (List<Object>) JSON.deserializeUntyped(result);
        System.assert(parsedResult.size() > 0, 'Parsed result should contain member data from multiple employers');
    }
    
    @isTest
    static void testExportMembersByAssociationAdminUser() {
        // Get test association
        Association__c association = [SELECT Id FROM Association__c WHERE Name = 'Test Association' LIMIT 1];
        
        // Create admin user
        User adminUser = createTestUser('Admin User Assoc', 'System Administrator', null);
        
        Test.startTest();
        String result;
        System.runAs(adminUser) {
            result = MemberExportController.exportMembersToExcel(null, association.Id);
        }
        Test.stopTest();
        
        // Verify result is not empty (JSON data)
        System.assertNotEquals(null, result, 'Export result should not be null');
        System.assert(result.length() > 0, 'Export result should contain data');
    }
    
    @isTest
    static void testExportMembersByAssociationAccessDenied() {
        // Get test association
        Association__c association = [SELECT Id FROM Association__c WHERE Name = 'Test Association' LIMIT 1];
        
        // Get an existing person account and delete its assignment
        Account personAccount = [SELECT Id FROM Account WHERE IsPersonAccount = true LIMIT 1];
        Assignment__c assignment = [SELECT Id FROM Assignment__c WHERE Person__c = :personAccount.Id LIMIT 1];
        delete assignment;
        
        // Get the Contact record for the person account
        Contact personContact = [SELECT Id FROM Contact WHERE AccountId = :personAccount.Id LIMIT 1];
        
        // Create member user with ContactId but without proper assignment
        User memberUser = createTestUser('No Access User Assoc', 'Akavia Member', personContact.Id);
        
        Test.startTest();
        System.runAs(memberUser) {
            Boolean exceptionThrown = false;
            try {
                MemberExportController.exportMembersToExcel(null, association.Id);
                System.assert(false, 'Expected exception was not thrown');
            } catch (AuraHandledException e) {
                exceptionThrown = true;
            }
            System.assert(exceptionThrown, 'Expected exception was not thrown');
        }
        Test.stopTest();
    }
    
    @isTest
    static void testExportMembersByAssociationNoEmployers() {
        // Create association without any employers
        Association__c emptyAssociation = new Association__c(
            Name = 'Empty Association',
            Type__c = 'Lokalförening',
            AssociationNumber__c = 'ASS003'
        );
        insert emptyAssociation;
        
        // Get test person account with assignment
        Account personAccount = [SELECT Id FROM Account WHERE IsPersonAccount = true LIMIT 1];
        
        // Create assignment for the empty association
        Assignment__c newAssignment = new Assignment__c(
            Person__c = personAccount.Id,
            AssignmentAssociation__c = emptyAssociation.Id,
            Type__c = 'Lokalt Förtroendevald',
            Role__c = 'Ordförande',
            StartDate__c = Date.today().addDays(-30)
        );
        insert newAssignment;
        
        // Get the Contact record for the person account
        Contact personContact = [SELECT Id FROM Contact WHERE AccountId = :personAccount.Id LIMIT 1];
        
        // Create member user
        User memberUser = createTestUser('User Empty Assoc', 'Akavia Member', personContact.Id);
        
        Test.startTest();
        System.runAs(memberUser) {
            Boolean exceptionThrown = false;
            try {
                MemberExportController.exportMembersToExcel(null, emptyAssociation.Id);
                System.assert(false, 'Expected exception was not thrown');
            } catch (AuraHandledException e) {
                exceptionThrown = true;
            }
            System.assert(exceptionThrown, 'Expected exception was not thrown');
        }
        Test.stopTest();
    }
    
    @isTest
    static void testEmployerIdPriorityOverAssociationId() {
        // Get test data
        Account employer = [SELECT Id FROM Account WHERE Name = 'Test Employer' LIMIT 1];
        Association__c association = [SELECT Id FROM Association__c WHERE Name = 'Test Association' LIMIT 1];
        Account personAccount = [SELECT Id FROM Account WHERE IsPersonAccount = true LIMIT 1];
        
        // Get the Contact record for the person account
        Contact personContact = [SELECT Id FROM Contact WHERE AccountId = :personAccount.Id LIMIT 1];
        
        // Create member user
        User memberUser = createTestUser('Priority User', 'Akavia Member', personContact.Id);
        String result;

        Test.startTest();
        System.runAs(memberUser) {
            // Pass both employerId and associationId - employerId should take priority
            result = MemberExportController.exportMembersToExcel(employer.Id, association.Id);
        }
        Test.stopTest();
        
        // Verify result is not empty (JSON data)
        System.assertNotEquals(null, result, 'Export result should not be null');
        System.assert(result.length() > 0, 'Export result should contain data');
        
        // The result should be for single employer, not all employers in association
        List<Object> parsedResult = (List<Object>) JSON.deserializeUntyped(result);
        System.assert(parsedResult.size() > 0, 'Parsed result should contain member data');
    }
    
    
    // @isTest
    // static void testExportMembersToExcelLargeDataSet() {
    //     // Create additional test data to test with more records
    //     Account employer = [SELECT Id FROM Account WHERE Name = 'Test Employer' LIMIT 1];
    //     Account workplace = [SELECT Id FROM Account WHERE Name = 'Test Workplace' LIMIT 1];
        
    //     List<Account> additionalPersonAccounts = new List<Account>();
    //     for (Integer i = 6; i <= 100; i++) {
    //         Account personAccount = new Account(
    //             FirstName = 'BulkTest' + i,
    //             LastName = 'BulkPerson' + i,
    //             PersonEmail = 'BulkTest' + i + '@example.com',
    //             PersonMobilePhone = '070' + String.valueOf(1000000 + i),
    //             MemberNumber__c = String.valueOf(19890 + i),
    //             CurrentEmployer__c = employer.Id,
    //             RecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('PersonAccount').getRecordTypeId()
    //         );
    //         additionalPersonAccounts.add(personAccount);
    //     }
    //     insert additionalPersonAccounts;
        
    //     List<Employment__c> additionalEmployments = new List<Employment__c>();
    //     for (Integer i = 0; i < additionalPersonAccounts.size(); i++) {
    //         Employment__c employment = new Employment__c(
    //             Person__c = additionalPersonAccounts[i].Id,
    //             Workplace__c = workplace.Id,
    //             StartDate__c = Date.today().addDays(-(i + 20))
    //         );
    //         additionalEmployments.add(employment);
    //     }
    //     insert additionalEmployments;
        
    //     Test.startTest();
    //     String result = MemberExportController.exportMembersToExcel(employer.Id);
    //     Test.stopTest();
        
    //     // Verify result is not empty (JSON data)
    //     System.assertNotEquals(null, result, 'Export result should not be null');
    //     System.assert(result.length() > 0, 'Export result should contain data');
        
    //     // Verify it's valid JSON
    //     List<Object> parsedResult = (List<Object>) JSON.deserializeUntyped(result);
    //     System.assert(parsedResult.size() > 0, 'Parsed result should contain member data');
    // }
    
    @isTest
    static void testValidateUserAccessAdminUser() {
        // Get test employer
        Account employer = [SELECT Id FROM Account WHERE Name = 'Test Employer' LIMIT 1];
        
        // Create admin user
        User adminUser = createTestUser('Admin User', 'System Administrator', null);
        
        Test.startTest();
        System.runAs(adminUser) {
            Boolean hasAccess = MemberExportController.validateAccess(employer.Id, null);
            System.assertEquals(true, hasAccess, 'Admin user should have access');
        }
        Test.stopTest();
    }
    
    @isTest
    static void testValidateUserAccessMemberWithValidAssignment() {
        // Get test data
        Account employer = [SELECT Id FROM Account WHERE Name = 'Test Employer' LIMIT 1];
        Account personAccount = [SELECT Id FROM Account WHERE IsPersonAccount = true LIMIT 1];
        
        // Get the Contact record for the person account
        Contact personContact = [SELECT Id FROM Contact WHERE AccountId = :personAccount.Id LIMIT 1];
        
        // Create member user with ContactId (required for portal users)
        User memberUser = createTestUser('Member User', 'Akavia Member', personContact.Id);
        
        Test.startTest();
        System.runAs(memberUser) {
            Boolean hasAccess = MemberExportController.validateAccess(employer.Id, null);
            System.assertEquals(true, hasAccess, 'Member with valid assignment should have access');
        }
        Test.stopTest();
    }
    
    @isTest
    static void testValidateUserAccessMemberWithoutAssignment() {
        // Get test employer
        Account employer = [SELECT Id FROM Account WHERE Name = 'Test Employer' LIMIT 1];
        
        // Get an existing person account and delete its assignment
        Account personAccount = [SELECT Id FROM Account WHERE IsPersonAccount = true LIMIT 1];
        Assignment__c assignment = [SELECT Id FROM Assignment__c WHERE Person__c = :personAccount.Id LIMIT 1];
        delete assignment;
        
        // Get the Contact record for the person account
        Contact personContact = [SELECT Id FROM Contact WHERE AccountId = :personAccount.Id LIMIT 1];
        
        // Create member user with ContactId (required for portal users)
        User memberUser = createTestUser('No Assignment User', 'Akavia Member', personContact.Id);
        
        Test.startTest();
        System.runAs(memberUser) {
            Boolean hasAccess = MemberExportController.validateAccess(employer.Id, null);
            System.assertEquals(false, hasAccess, 'Member without assignment should not have access');
        }
        Test.stopTest();
    }
    
    @isTest
    static void testValidateUserAccessMemberWithWrongAssignmentRole() {
        // Get test data
        Account employer = [SELECT Id FROM Account WHERE Name = 'Test Employer' LIMIT 1];
        Association__c association = [SELECT Id FROM Association__c LIMIT 1];
        
        // Get existing person account
        Account personAccount = [SELECT Id FROM Account WHERE IsPersonAccount = true LIMIT 1];
        
        // Get the Contact record for the person account
        Contact personContact = [SELECT Id FROM Contact WHERE AccountId = :personAccount.Id LIMIT 1];
        
        // Get existing assignment and update type and role to null
        Assignment__c assignment = [SELECT Id FROM Assignment__c WHERE Person__c = :personAccount.Id LIMIT 1];
        assignment.Type__c = null;
        assignment.Role__c = null;
        update assignment;
        
        // Create member user with ContactId (required for portal users)
        User memberUser = createTestUser('Wrong Role User', 'Akavia Member', personContact.Id);
        
        Test.startTest();
        System.runAs(memberUser) {
            Boolean hasAccess = MemberExportController.validateAccess(employer.Id, null);
            System.assertEquals(false, hasAccess, 'Member with wrong assignment role should not have access');
        }
        Test.stopTest();
    }
    
    @isTest
    static void testValidateUserAccessMemberWithWrongAssignmentType() {
        // Get test data
        Account employer = [SELECT Id FROM Account WHERE Name = 'Test Employer' LIMIT 1];
        Association__c association = [SELECT Id FROM Association__c LIMIT 1];
        
        // Get existing person account
        Account personAccount = [SELECT Id FROM Account WHERE IsPersonAccount = true LIMIT 1];
        
        // Get the Contact record for the person account
        Contact personContact = [SELECT Id FROM Contact WHERE AccountId = :personAccount.Id LIMIT 1];
        
        // Get existing assignment and update type
        Assignment__c assignment = [SELECT Id FROM Assignment__c WHERE Person__c = :personAccount.Id LIMIT 1];
        assignment.Type__c = null;
        assignment.Role__c = null;
        update assignment;
        
        // Create member user with ContactId (required for portal users)
        User memberUser = createTestUser('Wrong Type User', 'Akavia Member', personContact.Id);
        
        Test.startTest();
        System.runAs(memberUser) {
            Boolean hasAccess = MemberExportController.validateAccess(employer.Id, null);
            System.assertEquals(false, hasAccess, 'Member with wrong assignment type should not have access');
        }
        Test.stopTest();
    }
    
    @isTest
    static void testValidateUserAccessEmployerWithoutAssociation() {
        // Create employer without association
        Account employerWithoutAssociation = new Account(
            Name = 'Employer Without Association',
            RecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('Employer').getRecordTypeId()
        );
        insert employerWithoutAssociation;
        
        // Get test person account
        Account personAccount = [SELECT Id FROM Account WHERE IsPersonAccount = true LIMIT 1];
        
        // Get the Contact record for the person account
        Contact personContact = [SELECT Id FROM Contact WHERE AccountId = :personAccount.Id LIMIT 1];
        
        // Create member user with ContactId (required for portal users)
        User memberUser = createTestUser('Test User', 'Akavia Member', personContact.Id);
        
        Test.startTest();
        System.runAs(memberUser) {
            Boolean hasAccess = MemberExportController.validateAccess(employerWithoutAssociation.Id, null);
            System.assertEquals(false, hasAccess, 'Member should not have access to employer without association');
        }
        Test.stopTest();
    }
    
    @isTest
    static void testValidateUserAccessNonMemberProfile() {
        // Get test employer
        Account employer = [SELECT Id FROM Account WHERE Name = 'Test Employer' LIMIT 1];
        
        // Create user with non-member profile
        User nonMemberUser = createTestUser('Non Member User', 'Standard User', null);
        
        Test.startTest();
        System.runAs(nonMemberUser) {
            Boolean hasAccess = MemberExportController.validateAccess(employer.Id, null);
            System.assertEquals(false, hasAccess, 'Non-member user should not have access');
        }
        Test.stopTest();
    }
    
    @isTest
    static void testValidateUserAccessUserWithoutPersonAccount() {
        // Get test employer
        Account employer = [SELECT Id FROM Account WHERE Name = 'Test Employer' LIMIT 1];
        
        // Create a regular user (not portal user) to test the scenario
        User userWithoutPersonAccount = createTestUser('No Person Account User', 'Standard User', null);
        
        Test.startTest();
        System.runAs(userWithoutPersonAccount) {
            Boolean hasAccess = MemberExportController.validateAccess(employer.Id, null);
            System.assertEquals(false, hasAccess, 'User without person account should not have access');
        }
        Test.stopTest();
    }
    
    @isTest
    static void testDebugProfiles() {
        // This test method helps debug profile availability
        Test.startTest();
        debugAvailableProfiles();
        Test.stopTest();
    }
    
    // THis should not be neccessary due to already testing with deleted assignments.
    // @isTest
    // static void testExportMembersToExcelAccessDenied() {
    //     // Get test employer
    //     Account employer = [SELECT Id FROM Account WHERE Name = 'Test Employer' LIMIT 1];
        
    //     // Get an existing person account and delete its assignment
    //     Account personAccount = [SELECT Id FROM Account WHERE IsPersonAccount = true LIMIT 1];
        
    //     // Delete any existing assignments for this person account
    //     List<Assignment__c> assignments = [SELECT Id FROM Assignment__c WHERE Person__c = :personAccount.Id];
    //     delete assignments;
        
    //     // Get the Contact record for the person account
    //     Contact personContact = [SELECT Id FROM Contact WHERE AccountId = :personAccount.Id LIMIT 1];
    //     // Create member user without proper assignment (with ContactId for portal users)
    //     User memberUser = createTestUser('No Access User', 'Akavia Member', personContact.Id);
        
    //     Test.startTest();
    //     System.runAs(memberUser) {
    //         try {
    //             MemberExportController.exportMembersToExcel(employer.Id);
    //             System.assert(false, 'Expected exception was not thrown');
    //         } catch (AuraHandledException e) {
    //             System.assert(e.getMessage().contains('Access denied'), 'Expected access denied error message');
    //         }
    //     }
    //     Test.stopTest();
    // }
    
    /**
     * Helper method to debug available profiles
     */
    @TestVisible
    private static void debugAvailableProfiles() {
        try {
            List<Profile> profiles = [SELECT Id, Name FROM Profile ORDER BY Name];
            System.debug('Available profiles in org:');
            for (Profile p : profiles) {
                System.debug('Profile: ' + p.Name + ' (ID: ' + p.Id + ')');
            }
        } catch (Exception e) {
            System.debug('Error querying profiles: ' + e.getMessage());
        }
    }
    
    /**
     * Helper method to create test users
     * Handles both regular users and portal users (like Akavia Member)
     */
    private static User createTestUser(String lastName, String profileName, Id contactId) {
        Profile prof = [SELECT Id, UserType FROM Profile WHERE Name = :profileName LIMIT 1];
        
        User testUser = new User(
            Alias = 'TestUser',
            Email = 'testuser@example.com',
            EmailEncodingKey = 'UTF-8',
            LastName = lastName,
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = prof.Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            UserName = 'testuser' + System.currentTimeMillis() + '@example.com',
            IsActive = true,
            EmailPreferencesAutoBcc = false
        );
        
        // For portal users, ContactId is required
        if (prof.UserType == 'PowerPartner' || prof.UserType == 'PowerCustomerSuccess' || prof.UserType == 'CustomerSuccess' || prof.UserType == 'CSPLitePortal' || prof.UserType == 'CSPLitePortal') {
            if (contactId == null) {
                // If no ContactId provided for portal user, use a fallback profile
                Profile fallbackProfile = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
                testUser.ProfileId = fallbackProfile.Id;
                System.debug('Portal user profile requires ContactId, using Standard User profile instead');
            } else {
                testUser.ContactId = contactId;
            }
        } else if (contactId != null) {
            // For regular users, ContactId is optional but can be set if provided
            testUser.ContactId = contactId;
        }
        
        // Portal users require special handling - use System.runAs with admin user
        if (testUser.ProfileId == prof.Id && prof.UserType != 'Standard') {
            User adminUser = [SELECT Id FROM User WHERE Profile.Name IN ('System Administrator', 'Systemadministratör') AND IsActive = true LIMIT 1];
            System.runAs(adminUser) {
                insert testUser;
            }
        } else {
            insert testUser;
        }
        
        return testUser;
    }
}