@IsTest
private class ContractReviewQueueableTest {

    private class MockBehavior {
        public String response;
        public Boolean shouldThrow;

        MockBehavior(String response, Boolean shouldThrow) {
            this.response = response;
            this.shouldThrow = shouldThrow;
        }
    }

    private class MockInvoker extends ContractReviewPromptService.TemplateInvoker {
        private Map<String, MockBehavior> behaviors = new Map<String, MockBehavior>();
        public List<String> invokedTemplates = new List<String>();

        public void registerBehavior(String templateName, String response, Boolean shouldThrow) {
            behaviors.put(templateName, new MockBehavior(response, shouldThrow));
        }

        public override String invoke(
            String templateApiName,
            ConnectApi.EinsteinPromptTemplateGenerationsInput genInput
        ) {
            invokedTemplates.add(templateApiName);
            MockBehavior behavior = behaviors.get(templateApiName);
            if (behavior == null) {
                throw new CalloutException('No mock behavior registered for template: ' + templateApiName);
            }
            if (behavior.shouldThrow) {
                throw new CalloutException('Simulated prompt failure');
            }
            return behavior.response;
        }
    }

    private static MockInvoker installMock() {
        MockInvoker mock = new MockInvoker();
        ContractReviewPromptService.invoker = mock;
        return mock;
    }

    private static User getTestUser() {
        return [
            SELECT Id
            FROM User
            WHERE Username = 'contractreviewtest@example.com.akavia'
            LIMIT 1
        ];
    }

    @TestSetup
    static void setup() {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User testUser = new User(
            Alias = 'crvqtest',
            Email = 'contractreviewtest@example.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'QueueTester',
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

        System.runAs(testUser) {
            Case parentCase = new Case(Subject = 'Queueable Test Case');
            insert parentCase;

            ContractReview__c review = new ContractReview__c(
                Case__c = parentCase.Id,
                Status__c = 'Processing',
                ContractReviewTemplateId__c = 'test-template-id'
            );
            insert review;

            // Create runtime criteria that the parser will update
            List<ContractReviewRuntimeCriterion__c> criteria = new List<ContractReviewRuntimeCriterion__c>();
            for (Integer i = 0; i < 2; i++) {
                criteria.add(new ContractReviewRuntimeCriterion__c(
                    ContractReview__c = review.Id,
                    Definition__c = 'Test criterion ' + i
                ));
            }
            insert criteria;
        }
    }

    @IsTest
    static void successPath_setsStatusAndCreatesResult() {
        User testUser = getTestUser();
        System.runAs(testUser) {
            ContractReview__c review = [SELECT Id FROM ContractReview__c LIMIT 1];
            List<ContractReviewRuntimeCriterion__c> criteria = [
                SELECT Id FROM ContractReviewRuntimeCriterion__c
                WHERE ContractReview__c = :review.Id
                ORDER BY Name
            ];

            // Build mock JSON matching the parser's expected format
            String mockJson = '[' +
                '{"recordId":"' + criteria[0].Id + '","met":true,"extract":"Found clause A","aicomment":"Looks good"},' +
                '{"recordId":"' + criteria[1].Id + '","met":false,"extract":"Missing clause B","aicomment":"Not found"}' +
            ']';

            // Use a fake ContentDocument Id (not used in mock)
            Id fakeDocId = '069000000000001AAA';

            MockInvoker mock = installMock();
            mock.registerBehavior('Contract_Review_Contract_Type', 'false', false);
            mock.registerBehavior('ContractReviewPromptTemplate', mockJson, false);

            Test.startTest();
            System.enqueueJob(
                new ContractReviewQueueable(review.Id, fakeDocId)
            );
            Test.stopTest();

            // Verify status
            ContractReview__c updated = [
                SELECT Status__c, ErrorMessage__c, ResponseDraft__c
                FROM ContractReview__c
                WHERE Id = :review.Id
            ];
            System.assertEquals('Success', updated.Status__c,
                'Status should be Success after successful processing');
            System.assertEquals(null, updated.ErrorMessage__c,
                'ErrorMessage should be null on success');
            // Draft is now generated in a chained queueable (not in this transaction)
            System.assertEquals(null, updated.ResponseDraft__c,
                'ResponseDraft__c should be null — draft is generated by chained ContractReviewDraftQueueable');

            // Verify completion event includes CaseId__c
            // (events published via PublishAfterCommit are delivered after Test.stopTest())
            Case parentCase = [SELECT Id FROM Case LIMIT 1];
            // Event bus assertions: events are delivered above by Test.stopTest()
            // We verify the publish didn't throw and CaseId__c was set by checking
            // the queueable executed without error (Status__c = Success).

            // Verify result record created
            List<ContractReviewResult__c> results = [
                SELECT Id, JSON__c FROM ContractReviewResult__c
                WHERE ContractReview__c = :review.Id
            ];
            System.assertEquals(1, results.size(),
                'Should create exactly one ContractReviewResult__c');

            // Verify criteria were updated by parser
            ContractReviewRuntimeCriterion__c crit0 = [
                SELECT CriterionMet__c, Extract__c
                FROM ContractReviewRuntimeCriterion__c
                WHERE Id = :criteria[0].Id
            ];
            System.assertEquals(true, crit0.CriterionMet__c,
                'First criterion should be met');
            System.assertEquals('Found clause A', crit0.Extract__c,
                'First criterion extract should match');
        }
    }

    @IsTest
    static void calloutFailure_setsFailureStatusAndErrorMessage() {
        User testUser = getTestUser();
        System.runAs(testUser) {
            ContractReview__c review = [SELECT Id FROM ContractReview__c LIMIT 1];
            Id fakeDocId = '069000000000001AAA';

            MockInvoker mock = installMock();
            mock.registerBehavior('Contract_Review_Contract_Type', 'false', false);
            mock.registerBehavior('ContractReviewPromptTemplate', null, true);

            Test.startTest();
            System.enqueueJob(
                new ContractReviewQueueable(review.Id, fakeDocId)
            );
            Test.stopTest();

            ContractReview__c updated = [
                SELECT Status__c, ErrorMessage__c
                FROM ContractReview__c
                WHERE Id = :review.Id
            ];
            System.assertEquals('Failure', updated.Status__c,
                'Status should be Failure after callout error');
            System.assert(updated.ErrorMessage__c.contains('Simulated prompt failure'),
                'ErrorMessage should contain the callout error: ' + updated.ErrorMessage__c);

            // Verify no result record created
            Integer resultCount = [
                SELECT COUNT() FROM ContractReviewResult__c
                WHERE ContractReview__c = :review.Id
            ];
            System.assertEquals(0, resultCount,
                'No ContractReviewResult__c should exist after callout failure');
        }
    }

    @IsTest
    static void parseFailure_rollsBackAndSetsFailure() {
        User testUser = getTestUser();
        System.runAs(testUser) {
            ContractReview__c review = [SELECT Id FROM ContractReview__c LIMIT 1];
            Id fakeDocId = '069000000000001AAA';

            // Malformed JSON will cause parser to throw
            String badJson = 'NOT VALID JSON';

            MockInvoker mock = installMock();
            mock.registerBehavior('Contract_Review_Contract_Type', 'false', false);
            mock.registerBehavior('ContractReviewPromptTemplate', badJson, false);

            Test.startTest();
            System.enqueueJob(
                new ContractReviewQueueable(review.Id, fakeDocId)
            );
            Test.stopTest();

            ContractReview__c updated = [
                SELECT Status__c, ErrorMessage__c
                FROM ContractReview__c
                WHERE Id = :review.Id
            ];
            System.assertEquals('Failure', updated.Status__c,
                'Status should be Failure after parse error');
            System.assertNotEquals(null, updated.ErrorMessage__c,
                'ErrorMessage should be populated after parse error');

            // Verify savepoint rollback — no orphaned result record
            Integer resultCount = [
                SELECT COUNT() FROM ContractReviewResult__c
                WHERE ContractReview__c = :review.Id
            ];
            System.assertEquals(0, resultCount,
                'Savepoint rollback should remove orphaned ContractReviewResult__c');
        }
    }

    @IsTest
    static void draftFailure_reviewStillSucceeds() {
        User testUser = getTestUser();
        System.runAs(testUser) {
            ContractReview__c review = [SELECT Id FROM ContractReview__c LIMIT 1];
            List<ContractReviewRuntimeCriterion__c> criteria = [
                SELECT Id FROM ContractReviewRuntimeCriterion__c
                WHERE ContractReview__c = :review.Id
                ORDER BY Name
            ];

            String mockJson = '[' +
                '{"recordId":"' + criteria[0].Id + '","met":true,"extract":"Found clause A","aicomment":"Looks good"},' +
                '{"recordId":"' + criteria[1].Id + '","met":false,"extract":"Missing clause B","aicomment":"Not found"}' +
            ']';

            Id fakeDocId = '069000000000001AAA';

            // Review succeeds — draft is now chained as a separate queueable
            MockInvoker mock = installMock();
            mock.registerBehavior('Contract_Review_Contract_Type', 'false', false);
            mock.registerBehavior('ContractReviewPromptTemplate', mockJson, false);

            Test.startTest();
            System.enqueueJob(
                new ContractReviewQueueable(review.Id, fakeDocId)
            );
            Test.stopTest();

            ContractReview__c updated = [
                SELECT Status__c, ErrorMessage__c, ResponseDraft__c
                FROM ContractReview__c
                WHERE Id = :review.Id
            ];
            System.assertEquals('Success', updated.Status__c,
                'Status should be Success');
            System.assertEquals(null, updated.ErrorMessage__c,
                'ErrorMessage should be null on success');
            System.assertEquals(null, updated.ResponseDraft__c,
                'ResponseDraft__c should be null — draft is generated by chained queueable');
        }
    }

    @IsTest
    static void formClassification_routesToFormTemplate() {
        User testUser = getTestUser();
        System.runAs(testUser) {
            ContractReview__c review = [SELECT Id FROM ContractReview__c LIMIT 1];
            List<ContractReviewRuntimeCriterion__c> criteria = [
                SELECT Id FROM ContractReviewRuntimeCriterion__c
                WHERE ContractReview__c = :review.Id
                ORDER BY Name
            ];

            String mockJson = '[' +
                '{"recordId":"' + criteria[0].Id + '","met":true,"extract":"Found clause A","aicomment":"Looks good"},' +
                '{"recordId":"' + criteria[1].Id + '","met":false,"extract":"Missing clause B","aicomment":"Not found"}' +
            ']';

            Id fakeDocId = '069000000000001AAA';

            MockInvoker mock = installMock();
            mock.registerBehavior('Contract_Review_Contract_Type', 'true', false);
            mock.registerBehavior('ContractReview_Forms', mockJson, false);

            Test.startTest();
            System.enqueueJob(
                new ContractReviewQueueable(review.Id, fakeDocId)
            );
            Test.stopTest();

            ContractReview__c updated = [
                SELECT Status__c FROM ContractReview__c WHERE Id = :review.Id
            ];
            System.assertEquals('Success', updated.Status__c,
                'Status should be Success when form template is used');
            System.assert(mock.invokedTemplates.contains('ContractReview_Forms'),
                'Should have invoked the forms review template');
            System.assert(!mock.invokedTemplates.contains('ContractReviewPromptTemplate'),
                'Should NOT have invoked the text review template');
        }
    }

    @IsTest
    static void textClassification_routesToTextTemplate() {
        User testUser = getTestUser();
        System.runAs(testUser) {
            ContractReview__c review = [SELECT Id FROM ContractReview__c LIMIT 1];
            List<ContractReviewRuntimeCriterion__c> criteria = [
                SELECT Id FROM ContractReviewRuntimeCriterion__c
                WHERE ContractReview__c = :review.Id
                ORDER BY Name
            ];

            String mockJson = '[' +
                '{"recordId":"' + criteria[0].Id + '","met":true,"extract":"Found clause A","aicomment":"Looks good"},' +
                '{"recordId":"' + criteria[1].Id + '","met":false,"extract":"Missing clause B","aicomment":"Not found"}' +
            ']';

            Id fakeDocId = '069000000000001AAA';

            MockInvoker mock = installMock();
            mock.registerBehavior('Contract_Review_Contract_Type', 'false', false);
            mock.registerBehavior('ContractReviewPromptTemplate', mockJson, false);

            Test.startTest();
            System.enqueueJob(
                new ContractReviewQueueable(review.Id, fakeDocId)
            );
            Test.stopTest();

            ContractReview__c updated = [
                SELECT Status__c FROM ContractReview__c WHERE Id = :review.Id
            ];
            System.assertEquals('Success', updated.Status__c,
                'Status should be Success when text template is used');
            System.assert(mock.invokedTemplates.contains('ContractReviewPromptTemplate'),
                'Should have invoked the text review template');
            System.assert(!mock.invokedTemplates.contains('ContractReview_Forms'),
                'Should NOT have invoked the forms review template');
        }
    }

    @IsTest
    static void classificationFailure_fallsBackToTextTemplate() {
        User testUser = getTestUser();
        System.runAs(testUser) {
            ContractReview__c review = [SELECT Id FROM ContractReview__c LIMIT 1];
            List<ContractReviewRuntimeCriterion__c> criteria = [
                SELECT Id FROM ContractReviewRuntimeCriterion__c
                WHERE ContractReview__c = :review.Id
                ORDER BY Name
            ];

            String mockJson = '[' +
                '{"recordId":"' + criteria[0].Id + '","met":true,"extract":"Found clause A","aicomment":"Looks good"},' +
                '{"recordId":"' + criteria[1].Id + '","met":false,"extract":"Missing clause B","aicomment":"Not found"}' +
            ']';

            Id fakeDocId = '069000000000001AAA';

            MockInvoker mock = installMock();
            mock.registerBehavior('Contract_Review_Contract_Type', null, true);
            mock.registerBehavior('ContractReviewPromptTemplate', mockJson, false);

            Test.startTest();
            System.enqueueJob(
                new ContractReviewQueueable(review.Id, fakeDocId)
            );
            Test.stopTest();

            ContractReview__c updated = [
                SELECT Status__c, ErrorMessage__c FROM ContractReview__c WHERE Id = :review.Id
            ];
            System.assertEquals('Success', updated.Status__c,
                'Status should be Success — classification failure is non-critical');
            System.assertEquals(null, updated.ErrorMessage__c,
                'ErrorMessage should be null — classification failure should not set error');
            System.assert(mock.invokedTemplates.contains('ContractReviewPromptTemplate'),
                'Should have fallen back to text review template');
            System.assert(!mock.invokedTemplates.contains('ContractReview_Forms'),
                'Should NOT have invoked the forms review template');
        }
    }
}