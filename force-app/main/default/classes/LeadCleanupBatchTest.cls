
@IsTest
private class LeadCleanupBatchTest {

    private static Integer sequence = 0;

    @TestSetup
    static void setupBillecta() {
        insert new Billecta__c(
            SetupOwnerId = UserInfo.getOrganizationId(),
            Creditor__c = 'TEST-CREDITOR'
        );
    }

    private class IntegrationCalloutMock
        implements HttpCalloutMock {

        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();

            res.setStatusCode(400);
            res.setHeader(
                'Content-Type',
                'application/json'
            );
            res.setBody(
                '{"message":"Mocked integration response"}'
            );

            return res;
        }
    }

    private static Lead createLead(Integer ageDays) {

        sequence++;

        Lead l = new Lead(
            FirstName = 'Test',
            LastName = 'Cleanup',
            Company = 'Test Company',
            Email = 'leadcleanup' + sequence + '@example.com',
            Status = 'New'
        );

        insert l;

        Test.setCreatedDate(
            l.Id,
            System.now().addDays(-ageDays)
        );

        return [
            SELECT Id, Email, CreatedDate
            FROM Lead
            WHERE Id = :l.Id
        ];
    }

    private static Application__c createApplication(
        Lead leadRecord,
        String decision,
        Date decisionDate
    ) {
        Application__c app = new Application__c(
            Lead__c = leadRecord.Id,
            PersonFirstName__c = 'Test',
            PersonLastName__c = 'Cleanup',
            Email__c = leadRecord.Email,
            Webstatus__c = 'Komplett ansökan',
            Decision__c = decision,
            DecisionDate__c = decisionDate
        );

        insert app;
        return app;
    }

    private static Boolean leadExists(Id leadId) {
        return [
            SELECT COUNT()
            FROM Lead
            WHERE Id = :leadId
        ] == 1;
    }

    private static GDPR_Deletion_Queue__c getQueue(Id leadId) {

        List<GDPR_Deletion_Queue__c> records = [
            SELECT
                Id,
                ExternalKey__c,
                LeadId__c,
                Email__c,
                LeadCreatedDate__c,
                DecisionDate__c,
                DeletionReason__c,
                DeleteFromSalesforce__c,
                DeleteFromMarketingCloud__c,
                SalesforceStatus__c,
                MarketingCloudStatus__c,
                ProcessedDate__c,
                ErrorMessage__c
            FROM GDPR_Deletion_Queue__c
            WHERE ExternalKey__c = :String.valueOf(leadId)
            LIMIT 1
        ];

        return records.isEmpty() ? null : records[0];
    }

    private static void runBatch(
        Boolean enabled,
        Boolean dryRun,
        Integer retentionDays
    ) {
        Test.setMock(
            HttpCalloutMock.class,
            new IntegrationCalloutMock()
        );

        Test.startTest();

        Database.executeBatch(
            new LeadCleanupBatch(
                enabled,
                dryRun,
                retentionDays
            ),
            100
        );

        Test.stopTest();
    }

    // ============================================
    // 1. Unapproved Lead older than 90 days
    // ============================================

    @IsTest
    static void testDeletesOldUnapprovedLead() {

        Lead l = createLead(120);

        runBatch(true, false, 90);

        System.assertEquals(false, leadExists(l.Id));

        GDPR_Deletion_Queue__c q = getQueue(l.Id);

        System.assertNotEquals(null, q);
        System.assertEquals(
            'Retention90Days',
            q.DeletionReason__c
        );
        System.assertEquals(true, q.DeleteFromSalesforce__c);
        System.assertEquals(true, q.DeleteFromMarketingCloud__c);
        System.assertEquals('Deleted', q.SalesforceStatus__c);
        System.assertEquals('Pending', q.MarketingCloudStatus__c);
        System.assertNotEquals(null, q.ProcessedDate__c);
    }

    // ============================================
    // 2. Unapproved Lead younger than 90 days
    // ============================================

    @IsTest
    static void testKeepsRecentUnapprovedLead() {

        Lead l = createLead(30);

        runBatch(true, false, 90);

        System.assertEquals(true, leadExists(l.Id));
        System.assertEquals(null, getQueue(l.Id));
    }

    // ============================================
    // 3. Dry-run writes queue, does not delete
    // ============================================

    @IsTest
    static void testDryRunCreatesQueueWithoutDeleting() {

        Lead l = createLead(120);

        runBatch(true, true, 90);

        System.assertEquals(true, leadExists(l.Id));

        GDPR_Deletion_Queue__c q = getQueue(l.Id);

        System.assertNotEquals(null, q);
        System.assertEquals('DryRun', q.SalesforceStatus__c);
        System.assertEquals('DryRun', q.MarketingCloudStatus__c);
        System.assertEquals(true, q.DeleteFromSalesforce__c);
        System.assertEquals(true, q.DeleteFromMarketingCloud__c);
        System.assertEquals(null, q.ProcessedDate__c);
    }

    // ============================================
    // 4. Approved on same calendar date
    // ============================================

    @IsTest
    static void testDeletesSameDayApprovedLead() {

        Lead l = createLead(5);

        createApplication(
            l,
            'Godkänd',
            l.CreatedDate.date()
        );

        runBatch(true, false, 90);

        System.assertEquals(false, leadExists(l.Id));

        GDPR_Deletion_Queue__c q = getQueue(l.Id);

        System.assertNotEquals(null, q);
        System.assertEquals(
            'ApprovedWithin1Day',
            q.DeletionReason__c
        );
        System.assertEquals(true, q.DeleteFromSalesforce__c);
        System.assertEquals(true, q.DeleteFromMarketingCloud__c);
        System.assertEquals('Deleted', q.SalesforceStatus__c);
    }

    // ============================================
    // 5. Approved following calendar date
    // ============================================

    @IsTest
    static void testDeletesNextDayApprovedLead() {

        Lead l = createLead(5);

        createApplication(
            l,
            'Godkänd',
            l.CreatedDate.date().addDays(1)
        );

        runBatch(true, false, 90);

        System.assertEquals(false, leadExists(l.Id));

        GDPR_Deletion_Queue__c q = getQueue(l.Id);

        System.assertNotEquals(null, q);
        System.assertEquals(
            'ApprovedWithin1Day',
            q.DeletionReason__c
        );
        System.assertEquals('Deleted', q.SalesforceStatus__c);
        System.assertEquals('Pending', q.MarketingCloudStatus__c);
    }

    // ============================================
    // 6. Approved two days later
    // ============================================

    @IsTest
    static void testRetainsLateApprovedLead() {

        Lead l = createLead(10);

        createApplication(
            l,
            'Godkänd',
            l.CreatedDate.date().addDays(2)
        );

        runBatch(true, false, 90);

        System.assertEquals(true, leadExists(l.Id));

        GDPR_Deletion_Queue__c q = getQueue(l.Id);

        System.assertNotEquals(null, q);
        System.assertEquals(
            'ApprovedAfter1Day',
            q.DeletionReason__c
        );
        System.assertEquals(false, q.DeleteFromSalesforce__c);
        System.assertEquals(true, q.DeleteFromMarketingCloud__c);
        System.assertEquals('Retained', q.SalesforceStatus__c);
        System.assertEquals('Pending', q.MarketingCloudStatus__c);
    }

    // ============================================
    // 7. Late approval older than 90 days
    // ============================================

    @IsTest
    static void testRetainsOldLateApprovedLead() {

        Lead l = createLead(120);

        createApplication(
            l,
            'Godkänd',
            l.CreatedDate.date().addDays(30)
        );

        runBatch(true, false, 90);

        System.assertEquals(
            true,
            leadExists(l.Id),
            'Late-approved Lead must survive 90-day cleanup.'
        );

        GDPR_Deletion_Queue__c q = getQueue(l.Id);

        System.assertEquals('Retained', q.SalesforceStatus__c);
        System.assertEquals(true, q.DeleteFromMarketingCloud__c);
    }

    // ============================================
    // 8. Missing approval date
    // ============================================

    @IsTest
    static void testMissingDecisionDatePreservesLead() {

        Lead l = createLead(120);

        createApplication(l, 'Godkänd', null);

        runBatch(true, false, 90);

        System.assertEquals(true, leadExists(l.Id));
        System.assertEquals(null, getQueue(l.Id));
    }

    // ============================================
    // 9. Multiple approved applications
    // ============================================

    @IsTest
    static void testLateApprovalTakesPrecedence() {

        Lead l = createLead(10);

        createApplication(
            l,
            'Godkänd',
            l.CreatedDate.date()
        );

        createApplication(
            l,
            'Godkänd',
            l.CreatedDate.date().addDays(5)
        );

        runBatch(true, false, 90);

        System.assertEquals(true, leadExists(l.Id));

        GDPR_Deletion_Queue__c q = getQueue(l.Id);

        System.assertEquals(
            'ApprovedAfter1Day',
            q.DeletionReason__c
        );
        System.assertEquals(false, q.DeleteFromSalesforce__c);
        System.assertEquals(true, q.DeleteFromMarketingCloud__c);
    }

    // ============================================
    // 10. Non-approved application
    // ============================================

    @IsTest
    static void testNonApprovedApplicationUsesRetention() {

        Lead l = createLead(120);

        createApplication(
            l,
            'Avslag',
            null
        );

        runBatch(true, false, 90);

        System.assertEquals(false, leadExists(l.Id));

        GDPR_Deletion_Queue__c q = getQueue(l.Id);

        System.assertEquals(
            'Retention90Days',
            q.DeletionReason__c
        );
    }

    // ============================================
    // 11. Dry-run late approval
    // ============================================

    @IsTest
    static void testDryRunLateApproval() {

        Lead l = createLead(10);

        createApplication(
            l,
            'Godkänd',
            l.CreatedDate.date().addDays(3)
        );

        runBatch(true, true, 90);

        System.assertEquals(true, leadExists(l.Id));

        GDPR_Deletion_Queue__c q = getQueue(l.Id);

        System.assertNotEquals(null, q);
        System.assertEquals(false, q.DeleteFromSalesforce__c);
        System.assertEquals(true, q.DeleteFromMarketingCloud__c);
        System.assertEquals('DryRun', q.MarketingCloudStatus__c);
    }

    // ============================================
    // 12. Disabled cleanup
    // ============================================

    @IsTest
    static void testDisabledCleanup() {

        Lead l = createLead(120);

        runBatch(false, false, 90);

        System.assertEquals(true, leadExists(l.Id));
        System.assertEquals(null, getQueue(l.Id));
    }

    // ============================================
    // 13. Custom retention period
    // ============================================

    @IsTest
    static void testCustomRetentionDays() {

        Lead l = createLead(100);

        runBatch(true, false, 120);

        System.assertEquals(true, leadExists(l.Id));
        System.assertEquals(null, getQueue(l.Id));
    }

    // ============================================
    // 14. Existing queue is updated, not duplicated
    // ============================================

    @IsTest
    static void testExistingQueueUpsert() {

        Lead l = createLead(120);

        insert new GDPR_Deletion_Queue__c(
            ExternalKey__c = String.valueOf(l.Id),
            LeadId__c = String.valueOf(l.Id),
            Email__c = l.Email,
            SalesforceStatus__c = 'DryRun',
            MarketingCloudStatus__c = 'DryRun'
        );

        runBatch(true, true, 90);

        System.assertEquals(
            1,
            [
                SELECT COUNT()
                FROM GDPR_Deletion_Queue__c
                WHERE ExternalKey__c = :String.valueOf(l.Id)
            ]
        );

        GDPR_Deletion_Queue__c q = getQueue(l.Id);

        System.assertEquals(
            'Retention90Days',
            q.DeletionReason__c
        );
        System.assertEquals('DryRun', q.SalesforceStatus__c);
    }

    // ============================================
    // 15. Existing MC Deleted must not be reset
    // ============================================

    @IsTest
    static void testCompletedMarketingCloudQueuePreserved() {

        Lead l = createLead(120);

        insert new GDPR_Deletion_Queue__c(
            ExternalKey__c = String.valueOf(l.Id),
            LeadId__c = String.valueOf(l.Id),
            Email__c = l.Email,
            SalesforceStatus__c = 'Retained',
            MarketingCloudStatus__c = 'Deleted'
        );

        runBatch(true, true, 90);

        GDPR_Deletion_Queue__c q = getQueue(l.Id);

        System.assertEquals(
            'Deleted',
            q.MarketingCloudStatus__c
        );
    }

    // ============================================
    // 16. Scheduled execution
    // ============================================

    @IsTest
    static void testScheduledExecution() {

        Test.startTest();

        String jobId = System.schedule(
            'Lead Cleanup Test',
            '0 30 2 * * ?',
            new LeadCleanupBatch()
        );

        Test.stopTest();

        System.assertNotEquals(null, jobId);
    }

    // ============================================
    // 17. Metadata constructor
    // ============================================

    @IsTest
    static void testMetadataConstructor() {

        LeadCleanupBatch batch = new LeadCleanupBatch();

        System.assertNotEquals(null, batch);
    }

    // ============================================
    // 18. Forced dry-run constructor
    // ============================================

    @IsTest
    static void testForcedDryRunConstructor() {

        LeadCleanupBatch batch = new LeadCleanupBatch(true);

        System.assertNotEquals(null, batch);
    }

    // ============================================
    // 19. Invalid retention disables cleanup
    // ============================================

    @IsTest
    static void testInvalidRetention() {

        Lead l = createLead(120);

        runBatch(true, false, 0);

        System.assertEquals(true, leadExists(l.Id));
        System.assertEquals(null, getQueue(l.Id));
    }

    // 20. Future approval must not authorize deletion.
    @IsTest
    static void testFutureApprovalIsSkipped() {
        Lead l = createLead(0);
        createApplication(l, 'Godkänd', Date.today().addDays(3));
        runBatch(true, false, 90);
        System.assertEquals(true, leadExists(l.Id));
        System.assertEquals(null, getQueue(l.Id));
    }

    // 21. An approval before the Lead creation date is invalid.
    @IsTest
    static void testApprovalBeforeLeadCreationIsSkipped() {
        Lead l = createLead(5);
        createApplication(l, 'Godkänd', l.CreatedDate.date().addDays(-1));
        runBatch(true, false, 90);
        System.assertEquals(true, leadExists(l.Id));
        System.assertEquals(null, getQueue(l.Id));
    }

    // 22. A completed MC deletion must not prevent SF deletion.
    @IsTest
    static void testCompletedMarketingCloudDoesNotBlockSalesforce() {
        Lead l = createLead(120);
        insert new GDPR_Deletion_Queue__c(
            ExternalKey__c = String.valueOf(l.Id),
            LeadId__c = String.valueOf(l.Id),
            Email__c = l.Email,
            SalesforceStatus__c = 'Retained',
            MarketingCloudStatus__c = 'Deleted'
        );

        runBatch(true, false, 90);
        System.assertEquals(false, leadExists(l.Id));
        GDPR_Deletion_Queue__c q = getQueue(l.Id);
        System.assertNotEquals(null, q);
        System.assertEquals('Deleted', q.SalesforceStatus__c);
        System.assertEquals('Deleted', q.MarketingCloudStatus__c);
    }

    // 23. An existing DryRun queue transitions to production statuses.
    @IsTest
    static void testExistingDryRunTransitionsToProduction() {
        Lead l = createLead(120);
        insert new GDPR_Deletion_Queue__c(
            ExternalKey__c = String.valueOf(l.Id),
            LeadId__c = String.valueOf(l.Id),
            Email__c = l.Email,
            SalesforceStatus__c = 'DryRun',
            MarketingCloudStatus__c = 'DryRun'
        );

        runBatch(true, false, 90);
        System.assertEquals(false, leadExists(l.Id));
        GDPR_Deletion_Queue__c q = getQueue(l.Id);
        System.assertEquals('Deleted', q.SalesforceStatus__c);
        System.assertEquals('Pending', q.MarketingCloudStatus__c);
        System.assertEquals(1, [
            SELECT COUNT() FROM GDPR_Deletion_Queue__c
            WHERE ExternalKey__c = :String.valueOf(l.Id)
        ]);
    }

    // 24. A later DryRun must preserve a completed MC deletion.
    @IsTest
    static void testDryRunPreservesCompletedMarketingCloud() {
        Lead l = createLead(120);
        insert new GDPR_Deletion_Queue__c(
            ExternalKey__c = String.valueOf(l.Id),
            LeadId__c = String.valueOf(l.Id),
            Email__c = l.Email,
            SalesforceStatus__c = 'Retained',
            MarketingCloudStatus__c = 'Deleted'
        );

        runBatch(true, true, 90);
        GDPR_Deletion_Queue__c q = getQueue(l.Id);
        System.assertEquals(true, leadExists(l.Id));
        System.assertEquals('Retained', q.SalesforceStatus__c);
        System.assertEquals('Deleted', q.MarketingCloudStatus__c);
    }

    // 25. Only the hardcoded GDPR-TEST- filter is accepted.
    @IsTest
    static void testRejectsUnsafeTestFilter() {
        Boolean rejected = false;
        try {
            new LeadCleanupBatch(true, 'OtherPrefix');
        } catch (LeadCleanupBatch.CleanupException e) {
            rejected = true;
        }
        System.assertEquals(true, rejected);
    }

    // 26. The explicit filtered constructor can be instantiated.
    @IsTest
    static void testFilteredConstructor() {
        LeadCleanupBatch batch = new LeadCleanupBatch(true, 'GDPR-TEST-');
        System.assertNotEquals(null, batch);
    }

    // 27. A pending application is currently subject to the 90-day rule.
    // Review this business rule before enabling production deletion.
    @IsTest
    static void testPendingApplicationUsesRetention() {
        Lead l = createLead(120);
        createApplication(l, 'Inväntar', null);
        runBatch(true, true, 90);
        System.assertEquals(true, leadExists(l.Id));
        GDPR_Deletion_Queue__c q = getQueue(l.Id);
        System.assertNotEquals(null, q);
        System.assertEquals('Retention90Days', q.DeletionReason__c);
        System.assertEquals('DryRun', q.SalesforceStatus__c);
    }

}
