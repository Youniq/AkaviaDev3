
/**
 * @description       : Tests scheduled Marketing Cloud contact deletion
 *                      for Person Accounts and GDPR Leads.
 * @author            : Malin Nilsson (Stretch Customer AB)
 * @last modified on  : 2026-11-20
 */
@IsTest
public with sharing class ScheduleDeleteMcContactsTest {

    @TestSetup
    static void makeData() {

        TestDataFactorySetupParams params =
            new TestDataFactorySetupParams();

        params.numberOfAccounts = 2;

        TestDataFactory.setupBasicTestData();
        TestDataFactory.setupTestData(params);
    }

    // ============================================================
    // EXISTING SCHEDULE TEST
    // ============================================================

    @IsTest
    static void testScheduleIt() {

        Test.startTest();

        String jobId =
            ScheduleDeleteMcContacts.scheduleIt();

        CronTrigger ct = [
            SELECT Id,
                   CronExpression,
                   TimesTriggered,
                   NextFireTime
            FROM CronTrigger
            WHERE Id = :jobId
        ];

        System.assertEquals(
            0,
            ct.TimesTriggered,
            'Scheduled job should not have executed yet.'
        );

        System.assertEquals(
            '0 15 00 ? * *',
            ct.CronExpression,
            'Incorrect schedule expression.'
        );

        Test.stopTest();
    }

    // ============================================================
    // EXISTING PERSON ACCOUNT DELETION
    // ============================================================

    @IsTest
    static void testRunJob() {

        List<Account> accs = [
            SELECT Id,
                   SyncWithMc__c,
                   DeletedFromMc__c
            FROM Account
        ];

        for (Account acc : accs) {
            acc.SyncWithMc__c = false;
            acc.DeletedFromMc__c = false;
        }

        update accs;

        createDependentCustomSetting();

        Map<String, HttpResponse> responseByBodyContent =
            new Map<String, HttpResponse>();

        responseByBodyContent.put(
            'callout:MarketingCloudInteg',
            MockHttpResponseGenerator.getTokenResponse()
        );

        Test.setMock(
            HttpCalloutMock.class,
            new EchoHttpMock(
                getDeletedMcContactResponse(),
                responseByBodyContent
            )
        );

        Test.startTest();

        ScheduleDeleteMcContacts schedule =
            new ScheduleDeleteMcContacts();

        schedule.execute(null);

        Test.stopTest();

        for (Account a : [
            SELECT Id, DeletedFromMc__c
            FROM Account
            WHERE IsPersonAccount = true
        ]) {

            System.assertEquals(
                true,
                a.DeletedFromMc__c,
                'Person Account should be marked deleted from MC.'
            );
        }
    }

    @IsTest
    static void testFailRunJobFromBadCustomSetting() {

        List<Account> accs = [
            SELECT Id,
                   SyncWithMc__c,
                   DeletedFromMc__c
            FROM Account
        ];

        for (Account acc : accs) {
            acc.SyncWithMc__c = false;
            acc.DeletedFromMc__c = false;
        }

        update accs;

        Test.startTest();

        ScheduleDeleteMcContacts schedule =
            new ScheduleDeleteMcContacts();

        schedule.execute(null);

        Test.stopTest();

        List<Callout__c> callouts = [
            SELECT Id,
                   Status__c,
                   ErrorLog__c
            FROM Callout__c
        ];

        System.assert(
            !callouts.isEmpty(),
            'Expected a Callout record.'
        );

        for (Callout__c c : callouts) {

            System.assertEquals(
                'Failed',
                c.Status__c,
                'Callout should fail without MC settings.'
            );

            System.assertNotEquals(
                null,
                c.ErrorLog__c,
                'Error should be logged.'
            );
        }
    }

    // ============================================================
    // GDPR LEAD DELETION
    // ============================================================

    @IsTest
    static void testGdprDeletionSuccess() {

        createDependentCustomSetting();

        GDPR_Deletion_Queue__c queueRecord =
            createGdprQueueRecord(
                '00Q000000000001AAA',
                'Pending',
                true
            );

        Test.setMock(
            HttpCalloutMock.class,
            new GdprDeleteMock(200)
        );

        Test.startTest();

        Id jobId =
            ScheduleDeleteMcContacts.initDeleteGdprContacts();

        Test.stopTest();

        GDPR_Deletion_Queue__c result = [
            SELECT Id,
                   MarketingCloudStatus__c
            FROM GDPR_Deletion_Queue__c
            WHERE Id = :queueRecord.Id
        ];

        System.assertEquals(
            'Submitted',
            result.MarketingCloudStatus__c,
            'GDPR record should be marked Submitted.'
        );

        Callout__c callout = [
            SELECT Id,
                   JobId__c,
                   Type__c,
                   Status__c,
                   Request__c
            FROM Callout__c
            WHERE JobId__c = :jobId
            LIMIT 1
        ];

        System.assertEquals(
            'OK',
            callout.Status__c
        );

        System.assertEquals(
            'Marketing Cloud - Delete contacts',
            callout.Type__c
        );

        System.assert(
            callout.Request__c.contains(
                '00Q000000000001AAA'
            ),
            'Lead Id must be included in the MC request.'
        );
    }

    @IsTest
    static void testGdprDeletionFailure() {

        createDependentCustomSetting();

        GDPR_Deletion_Queue__c queueRecord =
            createGdprQueueRecord(
                '00Q000000000002AAA',
                'Pending',
                true
            );

        Test.setMock(
            HttpCalloutMock.class,
            new GdprDeleteMock(500)
        );

        Test.startTest();

        Id jobId =
            ScheduleDeleteMcContacts.initDeleteGdprContacts();

        Test.stopTest();

        GDPR_Deletion_Queue__c result = [
            SELECT MarketingCloudStatus__c,
                   ErrorMessage__c
            FROM GDPR_Deletion_Queue__c
            WHERE Id = :queueRecord.Id
        ];

        System.assertEquals(
            'Failed',
            result.MarketingCloudStatus__c
        );

        System.assertNotEquals(
            null,
            result.ErrorMessage__c
        );

        Callout__c callout = [
            SELECT Status__c, Code__c
            FROM Callout__c
            WHERE JobId__c = :jobId
            LIMIT 1
        ];

        System.assertEquals(
            'Failed',
            callout.Status__c
        );

        System.assertEquals(
            '500',
            callout.Code__c
        );
    }

    @IsTest
    static void testGdprDryRunNotDeleted() {

        createDependentCustomSetting();

        GDPR_Deletion_Queue__c queueRecord =
            createGdprQueueRecord(
                '00Q000000000003AAA',
                'DryRun',
                true
            );

        Test.setMock(
            HttpCalloutMock.class,
            new GdprDeleteMock(200)
        );

        Test.startTest();

        Id jobId =
            ScheduleDeleteMcContacts.initDeleteGdprContacts();

        Test.stopTest();

        GDPR_Deletion_Queue__c result = [
            SELECT MarketingCloudStatus__c
            FROM GDPR_Deletion_Queue__c
            WHERE Id = :queueRecord.Id
        ];

        System.assertEquals(
            'DryRun',
            result.MarketingCloudStatus__c,
            'DryRun records must never be submitted.'
        );

        Callout__c callout = [
            SELECT Status__c,
                   Request__c
            FROM Callout__c
            WHERE JobId__c = :jobId
            LIMIT 1
        ];

        System.assertEquals(
            'OK',
            callout.Status__c
        );

        System.assertEquals(
            null,
            callout.Request__c,
            'No API request should be sent for DryRun.'
        );
    }

    @IsTest
    static void testGdprNotMarkedForDeletion() {

        createDependentCustomSetting();

        GDPR_Deletion_Queue__c queueRecord =
            createGdprQueueRecord(
                '00Q000000000004AAA',
                'Pending',
                false
            );

        Test.setMock(
            HttpCalloutMock.class,
            new GdprDeleteMock(200)
        );

        Test.startTest();

        ScheduleDeleteMcContacts.initDeleteGdprContacts();

        Test.stopTest();

        GDPR_Deletion_Queue__c result = [
            SELECT MarketingCloudStatus__c
            FROM GDPR_Deletion_Queue__c
            WHERE Id = :queueRecord.Id
        ];

        System.assertEquals(
            'Pending',
            result.MarketingCloudStatus__c,
            'Records not marked for MC deletion must be ignored.'
        );
    }

    // ============================================================
    // TEST DATA
    // ============================================================

    private static GDPR_Deletion_Queue__c createGdprQueueRecord(
        String leadId,
        String mcStatus,
        Boolean deleteFromMc
    ) {

        GDPR_Deletion_Queue__c record =
            new GDPR_Deletion_Queue__c();

        record.LeadId__c = leadId;
        record.ExternalKey__c = leadId;
        record.Email__c = 'gdpr-test@example.com';
        record.MarketingCloudStatus__c = mcStatus;
        record.DeleteFromMarketingCloud__c = deleteFromMc;

        record.DeleteFromSalesforce__c = false;
        record.SalesforceStatus__c = 'Retained';
        record.DeletionReason__c = 'ApprovedAfter1Day';

        insert record;

        return record;
    }

    private static void createDependentCustomSetting() {

        McSetting__c setting =
            McSetting__c.getOrgDefaults();

        if (setting == null) {
            setting = new McSetting__c();
        }

        setting.ContactDeleteLimit__c = 10;

        upsert setting;
    }

    private static HttpResponse getDeletedMcContactResponse() {

        HttpResponse res = new HttpResponse();

        res.setHeader(
            'Content-Type',
            'application/json'
        );

        res.setBody(
            '{"operationInitiated":true,' +
            '"operationID":2,' +
            '"requestServiceMessageID":' +
            '"21d0d10d-a15a-413c-bc3e-8b43b185e551",' +
            '"resultMessages":[],' +
            '"serviceMessageID":' +
            '"acb87f67-ec49-42af-a0bb-987ac6451560"}'
        );

        res.setStatusCode(200);

        return res;
    }

    // ============================================================
    // GDPR HTTP MOCK
    // ============================================================

    private class GdprDeleteMock
        implements HttpCalloutMock {

        private Integer statusCode;

        GdprDeleteMock(Integer statusCode) {
            this.statusCode = statusCode;
        }

        public HttpResponse respond(HttpRequest request) {

            System.assertEquals(
                'POST',
                request.getMethod()
            );

            System.assert(
                request.getEndpoint().contains(
                    '/contacts/v1/contacts/actions/delete'
                ),
                'Incorrect Marketing Cloud endpoint.'
            );

            Map<String, Object> body =
                (Map<String, Object>)
                JSON.deserializeUntyped(
                    request.getBody()
                );

            System.assertEquals(
                'ContactAndAttributes',
                body.get('DeleteOperationType')
            );

            List<Object> values =
                (List<Object>)body.get('values');

            System.assert(
                !values.isEmpty(),
                'Contact keys must be supplied.'
            );

            HttpResponse response =
                new HttpResponse();

            response.setHeader(
                'Content-Type',
                'application/json'
            );

            response.setStatusCode(statusCode);

            if (
                statusCode == 200 ||
                statusCode == 201 ||
                statusCode == 202
            ) {

                response.setBody(
                    '{"operationInitiated":true,' +
                    '"operationID":12345}'
                );

            } else {

                response.setBody(
                    '{"message":"Simulated MC API error"}'
                );
            }

            return response;
        }
    }
}
