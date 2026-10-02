/**
 * @description Test class for BulkEmailController
 * @author AI Assistant
 * @group Bulk Email
 * @last modified on 2024-01-15
 * @last modified by AI Assistant
**/
@isTest
public class BulkEmailControllerTest {
    
    /**
     * Helper method to create recipient map matching RecipientWrapper structure
     * 
     * Note: We use Map<String, Object> instead of RecipientWrapper directly because:
     * - LWC-to-Apex serialization has issues with custom wrapper classes
     * - When RecipientWrapper objects are passed from LWC, all properties arrive as null
     * - Map<String, Object> serializes/deserializes reliably across the platform boundary
     * - This matches the actual implementation used in the BulkEmailController.sendBulkEmail method
     */
    private static Map<String, Object> createRecipientMap(String id, String name, String email, 
                                                          String firstName, String lastName, String workplace) {
        Map<String, Object> recipient = new Map<String, Object>();
        recipient.put('id', id);
        recipient.put('name', name);
        recipient.put('email', email);
        recipient.put('firstName', firstName);
        recipient.put('lastName', lastName);
        recipient.put('workplace', workplace);
        return recipient;
    }
    
    @TestSetup
    static void setupTestData() {
        // Setup basic test data
        TestDataFactory.setupBasicTestData();
        
        // Create test data using TestDataFactory
        TestDataFactorySetupParams params = new TestDataFactorySetupParams();
        params.numberOfEmployerAccounts = 1;
        params.numberOfWorkplaceAccounts = 1;
        params.numberOfAccounts = 5; // Create 5 person accounts (employees)
        params.addEmploymentsToMembers = true;
        
        TestDataFactory.setupTestData(params);
        
    }
    
    @isTest
    static void testGetActiveEmployees() {
        // Get test data - get employer account (parent of workplace)
        Account employer = [SELECT Id FROM Account WHERE Name LIKE 'Employer%' LIMIT 1];
        
        Test.startTest();
        BulkEmailController.PaginatedResult result = BulkEmailController.getActiveEmployeesPaginated(employer.Id, 25, 1, null);
        List<BulkEmailController.RecipientWrapper> employees = result.records;
        Test.stopTest();
        
        // Assertions
        System.assertEquals(5, employees.size(), 'Should return 5 active employees');
        
        for (BulkEmailController.RecipientWrapper employee : employees) {
            System.assertNotEquals(null, employee.id, 'Employee ID should not be null');
            System.assertNotEquals(null, employee.name, 'Employee name should not be null');
            System.assertNotEquals(null, employee.email, 'Employee email should not be null');
            System.assert(employee.email.contains('@test.akavia.se'), 'Employee email should contain test domain');
            System.assertNotEquals(null, employee.firstName, 'Employee firstName should not be null');
            System.assertNotEquals(null, employee.lastName, 'Employee lastName should not be null');
            System.assertNotEquals(null, employee.workplace, 'Employee workplace should not be null');
        }
    }
    
    @isTest
    static void testGetActiveEmployeesWithNoEmployments() {
        delete [SELECT Id FROM Account WHERE IsPersonAccount = true]; // must not have any employees in the system
        
        Account emptyEmployer = [SELECT Id FROM Account WHERE Name LIKE 'Employer%' LIMIT 1];
        
        Test.startTest();
        BulkEmailController.PaginatedResult result = BulkEmailController.getActiveEmployeesPaginated(emptyEmployer.Id, 25, 1, null);
        List<BulkEmailController.RecipientWrapper> employees = result.records;
        Test.stopTest();
        
        // Assertions
        System.assertEquals(0, employees.size(), 'Should return 0 employees for employer with no employments');
    }
    
    
    @isTest
    static void testSendBulkEmailSuccess() {
        // Get test data
        Account employer = [SELECT Id FROM Account WHERE Name LIKE 'Employer%' LIMIT 1];
        List<Account> employees = [SELECT Id, Name, PersonEmail, FirstName, LastName FROM Account WHERE FirstName LIKE 'First%'];
        
        // Create recipient data matching RecipientWrapper structure
        List<Map<String, Object>> recipients = new List<Map<String, Object>>();
        for (Account employee : employees) {
            recipients.add(createRecipientMap(
                employee.Id,
                employee.Name,
                employee.PersonEmail,
                employee.FirstName,
                employee.LastName,
                'Test Workplace (Started: ' + Date.today() + ')'
            ));
        }
        
        Test.startTest();
        BulkEmailController.EmailResult result = BulkEmailController.sendBulkEmail(
            employer.Id,
            recipients,
            'Test Subject',
            'Test Body',
            null  // No attachments
        );
        Test.stopTest();
        
        // Assertions
        System.assertEquals(true, result.success, 'Email should be sent successfully');
        System.assertEquals(null, result.error, 'Error should be null for successful send');
        
        // Verify Task records were created for each recipient
        List<Task> tasks = [SELECT Id, WhatId, Subject, Description FROM Task];
        System.assertEquals(5, tasks.size(), 'Should create 5 Task records for recipients');
        
        for (Task task : tasks) {
            System.assertNotEquals(null, task.WhatId, 'Task should be linked to recipient');
        }
    }
    
    // @isTest
    // static void testSendBulkEmailWithAttachments() {
    //     // Get test data
    //     Account employer = [SELECT Id FROM Account WHERE Name LIKE 'Employer%' LIMIT 1];
    //     List<Account> employees = [SELECT Id, Name, PersonEmail, FirstName, LastName FROM Account WHERE FirstName LIKE 'First%'];
        
    //     // Create test content document using TestDataFactory
    //     TestDataFactorySetupParams params = new TestDataFactorySetupParams();
    //     params.numberOfContentVersions = 1;
    //     TestDataFactory.setupTestData(params);
        
    //     ContentVersion cv = [SELECT ContentDocumentId FROM ContentVersion LIMIT 1];
    //     List<String> attachmentIds = new List<String>{cv.ContentDocumentId};
        
    //     // Create recipient data matching RecipientWrapper structure
    //     List<Map<String, Object>> recipients = new List<Map<String, Object>>();
    //     for (Account employee : employees) {
    //         recipients.add(createRecipientMap(
    //             employee.Id,
    //             employee.Name,
    //             employee.PersonEmail,
    //             employee.FirstName,
    //             employee.LastName,
    //             'Test Workplace (Started: ' + Date.today() + ')'
    //         ));
    //     }
        
    //     Test.startTest();
    //     BulkEmailController.EmailResult result = BulkEmailController.sendBulkEmail(
    //         employer.Id,
    //         recipients,
    //         'Test Subject with Attachment',
    //         'Test Body with Attachment',
    //         attachmentIds
    //     );
    //     Test.stopTest();
        
    //     // Assertions
    //     System.assertEquals(true, result.success, 'Email with attachment should be sent successfully');
        
    //     // Verify Task records contain attachment information
    //     List<Task> tasks = [SELECT Id, Description FROM Task];
    //     System.assertEquals(5, tasks.size(), 'Should create 5 Task records');
    // }
    
    @isTest
    static void testSendBulkEmailValidationErrors() {
        // Get test data
        Account employer = [SELECT Id FROM Account WHERE Name LIKE 'Employer%' LIMIT 1];
        
        Test.startTest();

        // Test with no recipients
        Boolean noRecipientsExceptionCaught = false;
        try {
            BulkEmailController.sendBulkEmail(employer.Id, null, 'Test Subject', 'Test Body', null);
        } catch (Exception e) {
            noRecipientsExceptionCaught = true;
        }
        System.assertEquals(true, noRecipientsExceptionCaught, 'Should throw exception for no recipients');
        
        // Test with empty subject
        Boolean emptySubjectExceptionCaught = false;
        try {
            BulkEmailController.sendBulkEmail(employer.Id, new List<Map<String, Object>>(), '', 'Test Body', null);
        } catch (Exception e) {
            emptySubjectExceptionCaught = true;
        }
        System.assertEquals(true, emptySubjectExceptionCaught, 'Should throw exception for empty subject');
        
        // Test with empty body
        Boolean emptyBodyExceptionCaught = false;
        try {
            BulkEmailController.sendBulkEmail(employer.Id, new List<Map<String, Object>>(), 'Test Subject', '', null);
        } catch (Exception e) {
            emptyBodyExceptionCaught = true;
        }
        System.assertEquals(true, emptyBodyExceptionCaught, 'Should throw exception for empty body');
        
        Test.stopTest();
    }
    
    @isTest
    static void testSendBulkEmailWithInvalidRecipients() {
        // Get test data
        Account employer = [SELECT Id FROM Account WHERE Name LIKE 'Employer%' LIMIT 1];
        
        // Create invalid recipient data
        List<Map<String, Object>> invalidRecipients = new List<Map<String, Object>>();
        invalidRecipients.add(createRecipientMap(
            'invalid-id',
            'Invalid Name',
            null,
            'Invalid',
            'Name',
            'Invalid Info'
        ));
        
        Test.startTest();
        Boolean invalidRecipientsExceptionCaught = false;
        try {
            BulkEmailController.sendBulkEmail(
                employer.Id,
                invalidRecipients,
                'Test Subject',
                'Test Body',
                null
            );
        } catch (Exception e) {
            invalidRecipientsExceptionCaught = true;
        }
        System.assertEquals(true, invalidRecipientsExceptionCaught, 'Should throw exception for invalid recipients');
        Test.stopTest();
    }
    
    @isTest
    static void testSendBulkEmailWithManyRecipients() {
        // Create additional test data for chunking test
        TestDataFactorySetupParams params = new TestDataFactorySetupParams();
        //params.numberOfEmployerAccounts = 1;
        //params.numberOfWorkplaceAccounts = 1;
        delete [SELECT Id FROM Account WHERE IsPersonAccount = true]; // avoiding duplicate value errors
        params.numberOfAccounts = 200; // Create 200 person accounts to test chunking
        params.addEmploymentsToMembers = true;
        
        TestDataFactory.setupTestData(params);
        
        // Get test data
        Account employer = [SELECT Id FROM Account WHERE Name LIKE 'Employer%' ORDER BY CreatedDate DESC LIMIT 1];
        List<Account> employees = [SELECT Id, Name, PersonEmail, FirstName, LastName FROM Account WHERE FirstName LIKE 'First%' LIMIT 200];
        
        // Create recipient data matching RecipientWrapper structure
        List<Map<String, Object>> recipients = new List<Map<String, Object>>();
        for (Account employee : employees) {
            recipients.add(createRecipientMap(
                employee.Id,
                employee.Name,
                employee.PersonEmail,
                employee.FirstName,
                employee.LastName,
                'Test Workplace (Started: ' + Date.today() + ')'
            ));
        }
        
        Test.startTest();
        BulkEmailController.EmailResult result = BulkEmailController.sendBulkEmail(
            employer.Id,
            recipients,
            'Test Subject with Many Recipients',
            'Test Body with Many Recipients',
            null
        );
        Test.stopTest();
        
        // Assertions
        System.assertEquals(true, result.success, 'Email should be sent successfully even with many recipients');
        
        List<BulkEmailSend__c> bulkEmailSends = [SELECT Id FROM BulkEmailSend__c];

        System.debug('bulkEmailSends.size(): ' + bulkEmailSends.size());    
        // 1 bulkEmailSend takes up to 250 recipients, so we should have 1 record for 200 recipients
        System.assertEquals(1, bulkEmailSends.size(), 'Should create 1 BulkEmailSend__c record for all recipients');

        // Verify Task records were created for all recipients
        List<Task> tasks = [SELECT Id FROM Task];
        System.assertEquals(200, tasks.size(), 'Should create 200 Task records for all recipients');
    }
    
    @isTest
    static void testSendBulkEmailWithEmptyRecipientData() {
        // Get test data
        Account employer = [SELECT Id FROM Account WHERE Name LIKE 'Employer%' LIMIT 1];
        
        // Create recipient data with null/empty values
        List<Map<String, Object>> recipients = new List<Map<String, Object>>();
        recipients.add(createRecipientMap(
            '',
            '',
            '',
            '',
            '',
            ''
        ));
        
        Test.startTest();
        Boolean emptyRecipientDataExceptionCaught = false;
        try {
            BulkEmailController.sendBulkEmail(
                employer.Id,
                recipients,
                'Test Subject',
                'Test Body',
                null
            );
        } catch (Exception e) {
            emptyRecipientDataExceptionCaught = true;
        }
        System.assertEquals(true, emptyRecipientDataExceptionCaught, 'Should throw exception for empty recipient data');
        Test.stopTest();
    }
    
    
    @isTest
    static void testResendBulkEmailSuccess() {
        // Get test data
        Account employer = [SELECT Id FROM Account WHERE Name LIKE 'Employer%' LIMIT 1];
        List<Account> employees = [SELECT Id, PersonEmail FROM Account WHERE FirstName LIKE 'First%' LIMIT 3];
        
        // Create a BulkEmailSend__c record with failed recipients
        String groupId = 'BESG-TEST-' + System.now().getTime();
        BulkEmailSend__c bulkEmailSend = new BulkEmailSend__c(
            BulkEmailSendGroupId__c = groupId,
            BatchSequence__c = 1,
            Status__c = 'Failed',
            AccountId__c = employer.Id,
            Subject__c = 'Test Subject',
            Body__c = 'Test Body',
            TotalRecipients__c = 3,
            SuccessfulSends__c = 0,
            FailedSends__c = 3,
            CanResend__c = true,
            RemainingBatches__c = JSON.serialize(new List<String>{employees[0].Id, employees[1].Id, employees[2].Id})
        );
        insert bulkEmailSend;
        
        Test.startTest();
        List<String> bulkEmailSendIds = new List<String>{bulkEmailSend.Id};
        List<BulkEmailController.EmailResult> results = BulkEmailController.resendBulkEmailInvocable(bulkEmailSendIds);
        Test.stopTest();
        
        // Assertions
        System.assertEquals(true, results[0].success, 'Resend should be successful');
        System.assertNotEquals(null, results[0].bulkEmailSendId, 'Should return new BulkEmailSend__c ID');
        
        // Verify original record is updated to 'Resent' status
        BulkEmailSend__c updatedRecord = [SELECT Id, Status__c, CanResend__c, RemainingBatches__c 
                                          FROM BulkEmailSend__c WHERE Id = :bulkEmailSend.Id];
        System.assertEquals('Resent', updatedRecord.Status__c, 'Original record should be marked as Resent');
        System.assertEquals(false, updatedRecord.CanResend__c, 'Original record should not be resendable');
        System.assertEquals(null, updatedRecord.RemainingBatches__c, 'RemainingBatches__c should be cleared');
        
        // Verify new BulkEmailSend__c records were created for resend
        List<BulkEmailSend__c> resendRecords = [
            SELECT Id, BulkEmailSendGroupId__c, ParentBulkEmailSendId__c, Status__c 
            FROM BulkEmailSend__c 
            WHERE BulkEmailSendGroupId__c LIKE :groupId + '-RESEND-%'
            ORDER BY BatchSequence__c ASC
        ];
        System.assert(resendRecords.size() > 0, 'Should create new BulkEmailSend__c records for resend');
        System.assertEquals(bulkEmailSend.Id, resendRecords[0].ParentBulkEmailSendId__c, 
                           'First resend record should link to original record');
    }
    
    @isTest
    static void testResendBulkEmailWithCanResendFalse() {
        // Get test data
        Account employer = [SELECT Id FROM Account WHERE Name LIKE 'Employer%' LIMIT 1];
        
        // Create a BulkEmailSend__c record with CanResend__c = false
        String groupId = 'BESG-TEST-' + System.now().getTime();
        BulkEmailSend__c bulkEmailSend = new BulkEmailSend__c(
            BulkEmailSendGroupId__c = groupId,
            BatchSequence__c = 1,
            Status__c = 'Completed',
            AccountId__c = employer.Id,
            Subject__c = 'Test Subject',
            Body__c = 'Test Body',
            CanResend__c = false
        );
        insert bulkEmailSend;

        Test.startTest();

        List<String> bulkEmailSendIds = new List<String>{bulkEmailSend.Id};
        List<BulkEmailController.EmailResult> results = BulkEmailController.resendBulkEmailInvocable(bulkEmailSendIds);

        Test.stopTest();
        
        // Assertions
        System.assertEquals(false, results[0].success, 'Should throw exception when CanResend__c is false');
        System.debug('results[0].message(): ' + results[0].message);
    }
    
    @isTest
    static void testResendBulkEmailWithEmptyRemainingBatches() {
        // Get test data
        Account employer = [SELECT Id FROM Account WHERE Name LIKE 'Employer%' LIMIT 1];
        
        // Create a BulkEmailSend__c record with empty RemainingBatches__c
        String groupId = 'BESG-TEST-' + System.now().getTime();
        BulkEmailSend__c bulkEmailSend = new BulkEmailSend__c(
            BulkEmailSendGroupId__c = groupId,
            BatchSequence__c = 1,
            Status__c = 'Failed',
            AccountId__c = employer.Id,
            Subject__c = 'Test Subject',
            Body__c = 'Test Body',
            CanResend__c = true,
            RemainingBatches__c = null
        );
        insert bulkEmailSend;
        
        Test.startTest();
        List<String> bulkEmailSendIds = new List<String>{bulkEmailSend.Id};
        List<BulkEmailController.EmailResult> results = BulkEmailController.resendBulkEmailInvocable(bulkEmailSendIds);
   
        Test.stopTest();
        
        // Assertions
        System.assertEquals(false, results[0].success, 'Should throw exception when RemainingBatches__c is empty');
        System.debug('results[0].message(): ' + results[0].message);
    }
    
    @isTest
    static void testResendBulkEmailWithInvalidId() {
        Test.startTest();
        List<String> bulkEmailSendIds = new List<String>{'invalid-id'};
        List<BulkEmailController.EmailResult> results = BulkEmailController.resendBulkEmailInvocable(bulkEmailSendIds);
   
        Test.stopTest();
        
        // Assertions
        System.assertEquals(false, results[0].success, 'Should throw exception for invalid ID');
        System.debug('results[0].message(): ' + results[0].message);
    }
    
    @isTest
    static void testResendBulkEmailWithNoValidRecipients() {
        // Get test data
        Account employer = [SELECT Id FROM Account WHERE Name LIKE 'Employer%' LIMIT 1];
        
        // Create a BulkEmailSend__c record with invalid Account IDs in RemainingBatches__c
        String groupId = 'BESG-TEST-' + System.now().getTime();
        BulkEmailSend__c bulkEmailSend = new BulkEmailSend__c(
            BulkEmailSendGroupId__c = groupId,
            BatchSequence__c = 1,
            Status__c = 'Failed',
            AccountId__c = employer.Id,
            Subject__c = 'Test Subject',
            Body__c = 'Test Body',
            CanResend__c = true,
            RemainingBatches__c = JSON.serialize(new List<String>{'001000000000000AAA', '001000000000000BBB'})
        );
        insert bulkEmailSend;
        
        Test.startTest();
   
             List<String> bulkEmailSendIds = new List<String>{bulkEmailSend.Id};
             List<BulkEmailController.EmailResult> results = BulkEmailController.resendBulkEmailInvocable(bulkEmailSendIds);
        
        Test.stopTest();
        
        // Assertions
        System.assertEquals(false, results[0].success, 'Should throw exception when no valid recipients found');
        System.debug('results[0].message(): ' + results[0].message);
    }
    
    @isTest
    static void testResendBulkEmailWithMultipleRelatedRecords() {
        // Get test data
        Account employer = [SELECT Id FROM Account WHERE Name LIKE 'Employer%' LIMIT 1];
        List<Account> employees = [SELECT Id, PersonEmail FROM Account WHERE FirstName LIKE 'First%' LIMIT 3];
        
        // Create multiple BulkEmailSend__c records with same BulkEmailSendGroupId__c
        String groupId = 'BESG-TEST-' + System.now().getTime();
        List<BulkEmailSend__c> bulkEmailSends = new List<BulkEmailSend__c>();
        
        BulkEmailSend__c record1 = new BulkEmailSend__c(
            BulkEmailSendGroupId__c = groupId,
            BatchSequence__c = 1,
            Status__c = 'Failed',
            AccountId__c = employer.Id,
            Subject__c = 'Test Subject',
            Body__c = 'Test Body',
            CanResend__c = true,
            RemainingBatches__c = JSON.serialize(new List<String>{employees[0].Id})
        );
        bulkEmailSends.add(record1);
        
        BulkEmailSend__c record2 = new BulkEmailSend__c(
            BulkEmailSendGroupId__c = groupId,
            BatchSequence__c = 2,
            Status__c = 'Failed',
            AccountId__c = employer.Id,
            Subject__c = 'Test Subject',
            Body__c = 'Test Body',
            CanResend__c = true,
            RemainingBatches__c = JSON.serialize(new List<String>{employees[1].Id, employees[2].Id})
        );
        bulkEmailSends.add(record2);
        
        insert bulkEmailSends;
        
        Test.startTest();
            List<String> bulkEmailSendIds = new List<String>{record1.Id};
             List<BulkEmailController.EmailResult> results = BulkEmailController.resendBulkEmailInvocable(bulkEmailSendIds);
        Test.stopTest();
        
        // Assertions
        System.assertEquals(true, results[0].success, 'Resend should be successful');
        
        // Verify all related records are updated to 'Resent' status
        List<BulkEmailSend__c> updatedRecords = [
            SELECT Id, Status__c, CanResend__c, RemainingBatches__c 
            FROM BulkEmailSend__c 
            WHERE BulkEmailSendGroupId__c = :groupId
            ORDER BY BatchSequence__c ASC
        ];
        
        for (BulkEmailSend__c record : updatedRecords) {
            System.assertEquals('Resent', record.Status__c, 'All related records should be marked as Resent');
            System.assertEquals(false, record.CanResend__c, 'All related records should not be resendable');
            System.assertEquals(null, record.RemainingBatches__c, 'RemainingBatches__c should be cleared');
        }
        
        // Verify new BulkEmailSend__c records were created with all failed recipients
        List<BulkEmailSend__c> resendRecords = [
            SELECT Id, BulkEmailSendGroupId__c 
            FROM BulkEmailSend__c 
            WHERE BulkEmailSendGroupId__c LIKE :groupId + '-RESEND-%'
        ];
        System.assert(resendRecords.size() > 0, 'Should create new BulkEmailSend__c records for resend');
    }
}