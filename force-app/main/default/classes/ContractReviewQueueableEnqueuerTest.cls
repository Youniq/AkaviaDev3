@IsTest
private class ContractReviewQueueableEnqueuerTest {

    private static User getTestUser() {
        return [
            SELECT Id
            FROM User
            WHERE Username = 'contractreviewtest@example.com.akavia'
            LIMIT 1
        ];
    }

    private static Id getTestContentDocumentId() {
        // Query via ContentDocumentLink on the test Case rather than directly
        // on ContentVersion, so the result is visible to the test user via
        // Case ownership regardless of file library sharing settings.
        Case c = [SELECT Id FROM Case WHERE Subject = 'Enqueuer Test Case' LIMIT 1];
        return [
            SELECT ContentDocumentId
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :c.Id
            LIMIT 1
        ].ContentDocumentId;
    }

    @TestSetup
    static void setup() {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User testUser = new User(
            Alias = 'crenqtst',
            Email = 'contractreviewtest@example.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'EnqueuerTester',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = p.Id,
            TimeZoneSidKey = 'Europe/Stockholm',
            UserName = 'contractreviewtest@example.com.akavia'
        );
        insert testUser;

        PermissionSet ps = [
            SELECT Id FROM PermissionSet WHERE Name = 'Contract_Review_PS' LIMIT 1
        ];
        insert new PermissionSetAssignment(
            AssigneeId = testUser.Id,
            PermissionSetId = ps.Id
        );

        // Non-setup DML (Case, ContractReview) must be in a System.runAs block to avoid
        // MIXED_DML with the setup-object DML above (User, PermissionSetAssignment).
        // The Case is created first so its Id is available for the ContentDocumentLink.
        Id enqueuerCaseId;
        System.runAs(testUser) {
            Case parentCase = new Case(Subject = 'Enqueuer Test Case');
            insert parentCase;
            enqueuerCaseId = parentCase.Id;

            ContractReview__c review = new ContractReview__c(
                Case__c = parentCase.Id,
                ContractReviewTemplateId__c = 'test-template-id'
            );
            insert review;
        }

        // ContentVersion is inserted in admin System.runAs context so that:
        //   (a) managed-package triggers (e.g. qsyd_FE.ContentDocumentTrigger) run with
        //       full field access and do not fail on insufficient permissions; and
        //   (b) the admin can create the ContentDocumentLink on the test Case, granting
        //       the test user visibility into the file via Case ownership.
        System.runAs(new User(Id = UserInfo.getUserId())) {
            ContentVersion cv = new ContentVersion(
                Title = 'EnqueuerTestFile',
                PathOnClient = 'EnqueuerTestFile.pdf',
                VersionData = Blob.valueOf('enqueuer test file content')
            );
            insert cv;
            Id enqueuerDocId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id].ContentDocumentId;

            insert new ContentDocumentLink(
                ContentDocumentId = enqueuerDocId,
                LinkedEntityId = enqueuerCaseId,
                ShareType = 'V'
            );
        }
    }

    @IsTest
    static void enqueue_setsProcessingAndEnqueuesJob() {
        User testUser = getTestUser();
        System.runAs(testUser) {
            ContractReview__c review = [SELECT Id, Case__c FROM ContractReview__c LIMIT 1];
            Id testDocId = getTestContentDocumentId();

            ContractReviewQueueableEnqueuer.EnqueueRequest req =
                new ContractReviewQueueableEnqueuer.EnqueueRequest();
            req.reviewId = review.Id;
            req.contentDocumentId = testDocId;

            Test.startTest();
            ContractReviewQueueableEnqueuer.enqueue(
                new List<ContractReviewQueueableEnqueuer.EnqueueRequest>{ req }
            );

            // Verify the enqueue set status to Processing before the queueable runs
            ContractReview__c beforeStop = [
                SELECT Status__c
                FROM ContractReview__c
                WHERE Id = :review.Id
            ];
            System.assertEquals('Processing', beforeStop.Status__c,
                'Status should be Processing after enqueue, before queueable runs');

            Test.stopTest();

            ContractReview__c updated = [
                SELECT Status__c
                FROM ContractReview__c
                WHERE Id = :review.Id
            ];
            // After Test.stopTest(), the Queueable will have run.
            // But the enqueuer itself sets Processing before enqueue.
            // The Queueable will fail (no real ConnectApi in test) so status may be Failure.
            // We verify enqueue didn't throw and the status was updated.
            System.assertNotEquals(null, updated.Status__c,
                'Status should have been set by enqueuer or queueable');
        }
    }

    @IsTest
    static void enqueue_throwsWhenProcessingReviewExists() {
        User testUser = getTestUser();
        System.runAs(testUser) {
            ContractReview__c review = [SELECT Id, Case__c FROM ContractReview__c LIMIT 1];

            // Set existing review to Processing
            review.Status__c = 'Processing';
            update review;

            // Create a second review on same Case
            ContractReview__c review2 = new ContractReview__c(
                Case__c = review.Case__c,
                ContractReviewTemplateId__c = 'test-template-id'
            );
            insert review2;

            ContractReviewQueueableEnqueuer.EnqueueRequest req =
                new ContractReviewQueueableEnqueuer.EnqueueRequest();
            req.reviewId = review2.Id;
            req.contentDocumentId = getTestContentDocumentId();

            try {
                ContractReviewQueueableEnqueuer.enqueue(
                    new List<ContractReviewQueueableEnqueuer.EnqueueRequest>{ req }
                );
                System.assert(false, 'Expected AuraHandledException');
            } catch (AuraHandledException e) {
                System.assert(
                    e.getMessage().contains('En granskning pågår redan'),
                    'Should contain duplicate guard message: ' + e.getMessage()
                );
            }
        }
    }

    @IsTest
    static void enqueue_handlesEmptyRequest() {
        // Should not throw
        ContractReviewQueueableEnqueuer.enqueue(
            new List<ContractReviewQueueableEnqueuer.EnqueueRequest>()
        );
        ContractReviewQueueableEnqueuer.enqueue(null);
    }

    @IsTest
    static void enqueue_fileTooLarge_throwsException() {
        User testUser = getTestUser();
        System.runAs(testUser) {
            ContractReview__c review = [SELECT Id, Case__c FROM ContractReview__c LIMIT 1];
            Id testDocId = getTestContentDocumentId();

            // Override threshold to 10 bytes so our normal test file exceeds it
            ContractReviewQueueableEnqueuer.MAX_FILE_SIZE_BYTES = 10;

            ContractReviewQueueableEnqueuer.EnqueueRequest req =
                new ContractReviewQueueableEnqueuer.EnqueueRequest();
            req.reviewId = review.Id;
            req.contentDocumentId = testDocId;

            Test.startTest();
            try {
                ContractReviewQueueableEnqueuer.enqueue(
                    new List<ContractReviewQueueableEnqueuer.EnqueueRequest>{ req }
                );
                System.assert(false, 'Expected AuraHandledException for oversized file');
            } catch (AuraHandledException e) {
                System.assert(
                    e.getMessage().contains('för stor'),
                    'Should contain size error message: ' + e.getMessage()
                );
            }
            Test.stopTest();
        }
    }
}