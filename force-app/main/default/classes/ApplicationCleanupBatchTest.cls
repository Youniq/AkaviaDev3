
@IsTest
private class LeadCleanupBatchTest {

    private static final String STARTED = 'Påbörjad ansökan';
    private static final String COMPLETE = 'Komplett ansökan';

    private static Integer sequence = 0;

    private static String nextEmail() {
        sequence++;
        return 'leadcleanup' + sequence + '@example.com';
    }

    private static Lead createLead(
        String status,
        Integer ageDays
    ) {
        Lead l = new Lead(
            FirstName = 'Test',
            LastName = 'Cleanup',
            Company = 'Test Company',
            Email = nextEmail(),
            Status = status
        );

        insert l;

        Test.setCreatedDate(
            l.Id,
            System.now().addDays(-ageDays)
        );

        return [
            SELECT Id, CreatedDate, Status, Email
            FROM Lead
            WHERE Id = :l.Id
        ];
    }

    private static Account createPerson() {

        Schema.RecordTypeInfo rt =
            Schema.SObjectType.Account
                .getRecordTypeInfosByDeveloperName()
                .get('PersonAccount');

        System.assertNotEquals(
            null,
            rt,
            'PersonAccount Record Type saknas.'
        );

        Account person = new Account(
            RecordTypeId = rt.getRecordTypeId(),
            FirstName = 'Test',
            LastName = 'Medlem',
            PersonEmail = nextEmail()
        );

        insert person;
        return person;
    }

    private static Application__c createApplication(
        Lead l,
        Account person,
        String status
    ) {
        Application__c app = new Application__c(
            Lead__c = l.Id,
            Person__c = person == null ? null : person.Id,
            PersonFirstName__c = 'Test',
            PersonLastName__c = 'Medlem',
            Email__c = l.Email,
            Webstatus__c = status
        );

        insert app;
        return app;
    }

    private static Membership__c createMembership(
        Account person,
        Integer ageDays
    ) {
        Membership__c membership = new Membership__c(
            Person__c = person.Id,
            StartDate__c = Date.today().addDays(-ageDays)
        );

        insert membership;

        Test.setCreatedDate(
            membership.Id,
            System.now().addDays(-ageDays)
        );

        return membership;
    }

    private static Boolean leadExists(Id leadId) {
        return [
            SELECT COUNT()
            FROM Lead
            WHERE Id = :leadId
        ] == 1;
    }

    private static void runBatch(Boolean dryRun) {
        Test.startTest();

        Database.executeBatch(
            new LeadCleanupBatch(dryRun),
            100
        );

        Test.stopTest();
    }

    // 1. Okonverterat Lead äldre än 90 dagar.
    @IsTest
    static void testDeletesOldUnconvertedLead() {

        Lead l = createLead('New', 120);

        runBatch(false);

        System.assertEquals(
            false,
            leadExists(l.Id),
            'Lead äldre än 90 dagar ska raderas.'
        );
    }

    // 2. Okonverterat Lead yngre än 90 dagar.
    @IsTest
    static void testKeepsRecentUnconvertedLead() {

        Lead l = createLead('New', 30);

        runBatch(false);

        System.assertEquals(
            true,
            leadExists(l.Id),
            'Lead yngre än 90 dagar ska behållas.'
        );
    }

    // 3. Dry-run får inte radera.
    @IsTest
    static void testDryRunDoesNotDelete() {

        Lead l = createLead('New', 120);

        runBatch(true);

        System.assertEquals(
            true,
            leadExists(l.Id),
            'Dry-run får inte radera Lead.'
        );
    }

    // 4. Medlem skapad samma dag som Lead,
    // och mer än 24 timmar har passerat.
    @IsTest
    static void testDeletesSameDayConvertedLead() {

        Lead l = createLead('Completed', 5);
        Account person = createPerson();

        createApplication(l, person, COMPLETE);
        createMembership(person, 5);

        runBatch(false);

        System.assertEquals(
            false,
            leadExists(l.Id),
            'Lead ska raderas efter medlemsregistrering.'
        );

        System.assertEquals(
            1,
            [
                SELECT COUNT()
                FROM Membership__c
                WHERE Person__c = :person.Id
            ],
            'Medlemskapet får inte raderas.'
        );

        System.assertEquals(
            1,
            [
                SELECT COUNT()
                FROM Account
                WHERE Id = :person.Id
            ],
            'Person Account får inte raderas.'
        );
    }

    // 5. Medlemskapet är yngre än 24 timmar.
    @IsTest
    static void testKeepsRecentlyConvertedLead() {

        Lead l = createLead('Completed', 0);
        Account person = createPerson();

        createApplication(l, person, COMPLETE);
        createMembership(person, 0);

        runBatch(false);

        System.assertEquals(
            true,
            leadExists(l.Id),
            'Lead får inte raderas före 24 timmar.'
        );
    }

    // 6. Medlemskapet skapades en annan dag.
    @IsTest
    static void testKeepsDifferentDayConversion() {

        Lead l = createLead('Completed', 10);
        Account person = createPerson();

        createApplication(l, person, COMPLETE);
        createMembership(person, 5);

        runBatch(false);

        System.assertEquals(
            true,
            leadExists(l.Id),
            'Konvertering annan dag ska behållas.'
        );
    }

    // 7. Flera ansökningar kopplade till samma Lead.
    @IsTest
    static void testMultipleApplications() {

        Lead l = createLead('Completed', 5);
        Account person = createPerson();

        createApplication(l, null, STARTED);
        createApplication(l, person, COMPLETE);
        createMembership(person, 5);

        runBatch(false);

        System.assertEquals(
            false,
            leadExists(l.Id),
            'Samtliga ansökningar ska kontrolleras.'
        );
    }

    // 8. Komplett ansökan utan Person-koppling.
    @IsTest
    static void testKeepsIncompletePersonLink() {

        Lead l = createLead('Completed', 120);

        createApplication(l, null, COMPLETE);

        runBatch(false);

        System.assertEquals(
            true,
            leadExists(l.Id),
            'Lead med oklar personkoppling ska behållas.'
        );
    }

    // 9. Inga matchande Leads.
    @IsTest
    static void testNoMatchingRecords() {

        Test.startTest();

        Id jobId = Database.executeBatch(
            new LeadCleanupBatch(false),
            100
        );

        Test.stopTest();

        AsyncApexJob job = [
            SELECT Status, NumberOfErrors
            FROM AsyncApexJob
            WHERE Id = :jobId
        ];

        System.assertEquals(
            'Completed',
            job.Status
        );

        System.assertEquals(
            0,
            job.NumberOfErrors
        );
    }

    // 10. Felhantering vid radering.
    @IsTest
    static void testDeleteFailureHandling() {

        Lead l = createLead('New', 120);

        delete l;

        Test.startTest();

        new LeadCleanupBatch(false).execute(
            null,
            new List<SObject>{ l }
        );

        Test.stopTest();
    }

    // 11. Schemaläggning.
    @IsTest
    static void testScheduledExecution() {

        Test.startTest();

        String jobId = System.schedule(
            'Lead Cleanup Test',
            '0 30 2 * * ?',
            new LeadCleanupBatch(false)
        );

        Test.stopTest();

        System.assertNotEquals(
            null,
            jobId,
            'Schemaläggningen ska lyckas.'
        );
    }
}
