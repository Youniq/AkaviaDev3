@IsTest
private class ContractReviewDraftQueueableTest {

    private class MockInvoker extends ContractReviewPromptService.TemplateInvoker {
        public String mockResponse;
        public Boolean shouldThrow;
        public String capturedTemplateName;

        MockInvoker(String mockResponse, Boolean shouldThrow) {
            this.mockResponse = mockResponse;
            this.shouldThrow = shouldThrow;
        }

        public override String invoke(
            String templateApiName,
            ConnectApi.EinsteinPromptTemplateGenerationsInput genInput
        ) {
            this.capturedTemplateName = templateApiName;
            if (this.shouldThrow) {
                throw new CalloutException('Simulated draft failure');
            }
            return this.mockResponse;
        }
    }

    private static MockInvoker installMock(String response, Boolean shouldThrow) {
        MockInvoker mock = new MockInvoker(response, shouldThrow);
        ContractReviewPromptService.invoker = mock;
        return mock;
    }

    private static User getTestUser() {
        return [
            SELECT Id
            FROM User
            WHERE Username = 'contractreviewdrafttest@example.com.akavia'
            LIMIT 1
        ];
    }

    @TestSetup
    static void setup() {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User testUser = new User(
            Alias = 'crdqtest',
            Email = 'contractreviewdrafttest@example.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'DraftTester',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = p.Id,
            TimeZoneSidKey = 'Europe/Stockholm',
            UserName = 'contractreviewdrafttest@example.com.akavia'
        );
        insert testUser;

        PermissionSet ps = [
            SELECT Id FROM PermissionSet WHERE Name = 'Contract_Review_PS' LIMIT 1
        ];
        insert new PermissionSetAssignment(
            AssigneeId = testUser.Id,
            PermissionSetId = ps.Id
        );

        System.runAs(testUser) {
            Case parentCase = new Case(Subject = 'Draft Queueable Test Case');
            insert parentCase;

            ContractReview__c review = new ContractReview__c(
                Case__c = parentCase.Id,
                Status__c = 'Success',
                ContractReviewTemplateId__c = 'test-template-id',
                Output_Sv__c = 'Swedish output text for draft',
                Output_Eng__c = 'English output text for draft'
            );
            insert review;
        }
    }

    @IsTest
    static void swedishDraft_success_populatesResponseDraft() {
        User testUser = getTestUser();
        System.runAs(testUser) {
            ContractReview__c review = [SELECT Id FROM ContractReview__c LIMIT 1];
            installMock('<p>Swedish draft HTML</p>', false);

            Test.startTest();
            System.enqueueJob(new ContractReviewDraftQueueable(review.Id, 'Svenska'));
            Test.stopTest();

            ContractReview__c updated = [
                SELECT ResponseDraft__c, ResponseDraft_Eng__c, Status__c
                FROM ContractReview__c
                WHERE Id = :review.Id
            ];
            System.assertEquals('Success', updated.Status__c,
                'Review status should remain Success');
            System.assertNotEquals(null, updated.ResponseDraft__c,
                'ResponseDraft__c should be populated');
            System.assert(updated.ResponseDraft__c.contains('Swedish draft HTML'),
                'ResponseDraft__c should contain mock HTML');
            System.assertEquals(null, updated.ResponseDraft_Eng__c,
                'ResponseDraft_Eng__c should remain null for Swedish draft');
        }
    }

    @IsTest
    static void englishDraft_success_populatesResponseDraftEng() {
        User testUser = getTestUser();
        System.runAs(testUser) {
            ContractReview__c review = [SELECT Id FROM ContractReview__c LIMIT 1];
            installMock('<p>English draft HTML</p>', false);

            Test.startTest();
            System.enqueueJob(new ContractReviewDraftQueueable(review.Id, 'English'));
            Test.stopTest();

            ContractReview__c updated = [
                SELECT ResponseDraft__c, ResponseDraft_Eng__c, Status__c
                FROM ContractReview__c
                WHERE Id = :review.Id
            ];
            System.assertEquals('Success', updated.Status__c,
                'Review status should remain Success');
            System.assertNotEquals(null, updated.ResponseDraft_Eng__c,
                'ResponseDraft_Eng__c should be populated');
            System.assert(updated.ResponseDraft_Eng__c.contains('English draft HTML'),
                'ResponseDraft_Eng__c should contain mock HTML');
            System.assertEquals(null, updated.ResponseDraft__c,
                'ResponseDraft__c should remain null for English draft');
        }
    }

    @IsTest
    static void draftFailure_reviewStatusUnchanged() {
        User testUser = getTestUser();
        System.runAs(testUser) {
            ContractReview__c review = [SELECT Id FROM ContractReview__c LIMIT 1];
            installMock(null, true);

            Test.startTest();
            System.enqueueJob(new ContractReviewDraftQueueable(review.Id, 'Svenska'));
            Test.stopTest();

            ContractReview__c updated = [
                SELECT ResponseDraft__c, Status__c, ErrorMessage__c
                FROM ContractReview__c
                WHERE Id = :review.Id
            ];
            System.assertEquals('Success', updated.Status__c,
                'Review status should remain Success even when draft fails');
            System.assertEquals(null, updated.ResponseDraft__c,
                'ResponseDraft__c should remain null when draft generation fails');
            System.assertEquals(null, updated.ErrorMessage__c,
                'Review ErrorMessage__c should not be affected by draft failure');
        }
    }

    @IsTest
    static void blankOutputText_publishesFailedEvent() {
        User testUser = getTestUser();
        System.runAs(testUser) {
            ContractReview__c review = [SELECT Id FROM ContractReview__c LIMIT 1];
            // Clear the English output so it's blank
            update new ContractReview__c(Id = review.Id, Output_Eng__c = null);

            installMock('<p>Should not be called</p>', false);

            Test.startTest();
            System.enqueueJob(new ContractReviewDraftQueueable(review.Id, 'English'));
            Test.stopTest();

            ContractReview__c updated = [
                SELECT ResponseDraft_Eng__c, Status__c
                FROM ContractReview__c
                WHERE Id = :review.Id
            ];
            System.assertEquals('Success', updated.Status__c,
                'Review status should remain Success');
            System.assertEquals(null, updated.ResponseDraft_Eng__c,
                'ResponseDraft_Eng__c should remain null when output text is blank');
        }
    }

    @IsTest
    static void emptyPromptResponse_publishesFailedEvent() {
        User testUser = getTestUser();
        System.runAs(testUser) {
            ContractReview__c review = [SELECT Id FROM ContractReview__c LIMIT 1];
            installMock('', false);

            Test.startTest();
            System.enqueueJob(new ContractReviewDraftQueueable(review.Id, 'Svenska'));
            Test.stopTest();

            ContractReview__c updated = [
                SELECT ResponseDraft__c, Status__c
                FROM ContractReview__c
                WHERE Id = :review.Id
            ];
            System.assertEquals('Success', updated.Status__c,
                'Review status should remain Success');
            System.assertEquals(null, updated.ResponseDraft__c,
                'ResponseDraft__c should remain null when prompt returns empty');
        }
    }

    @IsTest
    static void invalidLanguage_throwsException() {
        try {
            new ContractReviewDraftQueueable(null, 'French');
            System.assert(false, 'Expected IllegalArgumentException');
        } catch (IllegalArgumentException e) {
            System.assert(e.getMessage().contains('Unsupported language'),
                'Should contain expected message: ' + e.getMessage());
        }
    }
}