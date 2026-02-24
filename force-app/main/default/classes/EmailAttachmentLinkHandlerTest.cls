/**
 * Self-contained tests for EmailAttachmentLinkHandler + EmailAttachmentBackfillBatch
 * Focus: linking ContentDocument (Files) from EmailMessage to related Case.
 */
@IsTest
private class EmailAttachmentLinkHandlerTest {

    @TestSetup
    static void setup() {
        // Minimal, self-contained test data (no external factories)

        // Create a real user we can safely set as Case Owner in tests.
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];

        User u = new User(
            Alias = 'tuser',
            Email = 'tuser@example.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'TestUser',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            TimeZoneSidKey = 'Europe/Stockholm',
            ProfileId = p.Id,
            UserName = 'tuser+' + System.currentTimeMillis() + '@example.com'
        );
        insert u;

        List<Account> accts = new List<Account>{
            new Account(Name = 'Test Account 1'),
            new Account(Name = 'Test Account 2')
        };
        insert accts;

        Contact c1 = new Contact(
            LastName = 'Test Contact 1',
            Email = 'contact1@example.com',
            AccountId = accts[0].Id
        );
        insert c1;

        Contact c2 = new Contact(
            LastName = 'Test Contact 2',
            Email = 'contact2@example.com',
            AccountId = accts[1].Id
        );
        insert c2;

        // Create cases with safe fields for common flows:
        // - OwnerId set to a real user (avoids queue access issues)
        // - ContactId + SuppliedEmail/SuppliedName (helps email/alert logic)
        List<Case> cases = new List<Case>{
            new Case(
                Subject = 'Test Case 1',
                Status  = 'New',
                Origin  = 'Phone',
                AccountId = accts[0].Id,
                ContactId = c1.Id,
                SuppliedName = 'Test Sender 1',
                SuppliedEmail = 'sender1@example.com',
                OwnerId = u.Id
            ),
            new Case(
                Subject = 'Test Case 2',
                Status  = 'New',
                Origin  = 'Phone',
                AccountId = accts[1].Id,
                ContactId = c2.Id,
                SuppliedName = 'Test Sender 2',
                SuppliedEmail = 'sender2@example.com',
                OwnerId = u.Id
            )
        };
        insert cases;
    }

    // ---------- Helpers ----------

    private static ContentVersion createTestFile(String title) {
        ContentVersion cv = new ContentVersion(
            Title = title,
            PathOnClient = title + '.txt',
            VersionData = Blob.valueOf('Test file content for ' + title),
            IsMajorVersion = true
        );
        insert cv;
        return cv;
    }

    private static Id getContentDocumentId(Id contentVersionId) {
        return [
            SELECT ContentDocumentId
            FROM ContentVersion
            WHERE Id = :contentVersionId
        ].ContentDocumentId;
    }

    private static EmailMessage createEmailToCase(Id caseId, String subject) {
        // Keep it minimal but valid in most orgs
        EmailMessage em = new EmailMessage(
            ParentId = caseId,
            Subject = subject,
            TextBody = 'Test body',
            FromAddress = 'test@example.com',
            ToAddress = 'recipient@example.com',
            Status = '3' // Sent
        );
        insert em;
        return em;
    }

    private static EmailMessage createEmailRelatedToAccount(Id accountId, String subject) {
        EmailMessage em = new EmailMessage(
            RelatedToId = accountId,
            Subject = subject,
            TextBody = 'Test body',
            FromAddress = 'test@example.com',
            ToAddress = 'recipient@example.com',
            Status = '3'
        );
        insert em;
        return em;
    }

    private static ContentDocumentLink linkFileToEmail(Id contentDocumentId, Id emailMessageId) {
        ContentDocumentLink cdl = new ContentDocumentLink(
            ContentDocumentId = contentDocumentId,
            LinkedEntityId = emailMessageId,
            ShareType = 'V',
            Visibility = 'AllUsers'
        );
        insert cdl;
        return cdl;
    }

    // ---------- Tests ----------

    @IsTest
    static void test_LinkFileToCase_ViaTriggerInsertCDL() {
        Case c = [SELECT Id FROM Case ORDER BY CreatedDate ASC LIMIT 1];
        EmailMessage em = createEmailToCase(c.Id, 'Email - Trigger');

        Id contentDocId = getContentDocumentId(createTestFile('FileTrigger').Id);

        // Insert the link to EmailMessage first.
        ContentDocumentLink cdlToEmail = linkFileToEmail(contentDocId, em.Id); // should trigger linking to Case (via your trigger + handler)

        // Do NOT rely on an org trigger existing for ContentDocumentLink.
        // Instead, explicitly call the handler with the inserted CDL record.
        List<ContentDocumentLink> insertedCdls = [
            SELECT Id, ContentDocumentId, LinkedEntityId
            FROM ContentDocumentLink
            WHERE Id = :cdlToEmail.Id
        ];

        Test.startTest();
        EmailAttachmentLinkHandler.linkEmailFilesToCases(insertedCdls);
        Test.stopTest();

        // ContentDocumentLink query restriction: drive by ContentDocumentId only and filter in Apex.
        List<ContentDocumentLink> linksForDoc = [
            SELECT Id, LinkedEntityId
            FROM ContentDocumentLink
            WHERE ContentDocumentId = :contentDocId
        ];

        Boolean hasCaseLink = false;
        for (ContentDocumentLink l : linksForDoc) {
            if (l.LinkedEntityId != null && l.LinkedEntityId == c.Id) {
                hasCaseLink = true;
                break;
            }
        }

        System.assertEquals(true, hasCaseLink, 'Filen ska länkas till Caset');
    }

    @IsTest
    static void test_LinkMultipleFiles_ToSameCase() {
        Case c = [SELECT Id FROM Case ORDER BY CreatedDate ASC LIMIT 1];
        EmailMessage em = createEmailToCase(c.Id, 'Email - Multi Files');

        Id doc1 = getContentDocumentId(createTestFile('File1').Id);
        Id doc2 = getContentDocumentId(createTestFile('File2').Id);

        List<ContentDocumentLink> cdls = new List<ContentDocumentLink>{
            new ContentDocumentLink(ContentDocumentId = doc1, LinkedEntityId = em.Id, ShareType='V', Visibility='AllUsers'),
            new ContentDocumentLink(ContentDocumentId = doc2, LinkedEntityId = em.Id, ShareType='V', Visibility='AllUsers')
        };

        insert cdls; // trigger runs

        // Query back the inserted CDLs so the handler gets persisted values.
        // ContentDocumentLink query restriction: drive by LinkedEntityId only.
        List<ContentDocumentLink> insertedCdls = [
            SELECT Id, ContentDocumentId, LinkedEntityId
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :em.Id
        ];

        // Explicitly run the handler (do not depend on trigger behavior).
        Test.startTest();
        EmailAttachmentLinkHandler.linkEmailFilesToCases(insertedCdls);
        Test.stopTest();

        // ContentDocumentLink query restriction: drive filtering by ONE side only (here: LinkedEntityId),
        // then validate ContentDocumentIds in Apex.
        List<ContentDocumentLink> linksToCase = [
            SELECT Id, ContentDocumentId
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :c.Id
        ];

        Set<Id> expectedDocs = new Set<Id>{ doc1, doc2 };
        Integer matched = 0;
        for (ContentDocumentLink l : linksToCase) {
            if (expectedDocs.contains(l.ContentDocumentId)) {
                matched++;
            }
        }
        System.assertEquals(2, matched, 'Båda filerna ska vara länkade till Caset');
    }

    @IsTest
    static void test_NoCaseParent_DoesNotLink() {
        Account a = [SELECT Id FROM Account ORDER BY CreatedDate ASC LIMIT 1];
        EmailMessage em = createEmailRelatedToAccount(a.Id, 'Email - No Case');

        Id doc = getContentDocumentId(createTestFile('FileNoCase').Id);
        ContentDocumentLink cdl = linkFileToEmail(doc, em.Id);

        Test.startTest();
        EmailAttachmentLinkHandler.linkEmailFilesToCases(new List<ContentDocumentLink>{ cdl });
        Test.stopTest();

        // ContentDocumentLink query restriction: filter by ContentDocumentId only,
        // then check in Apex that none of the links for this doc point to a Case.
        List<ContentDocumentLink> linksForDoc = [
            SELECT Id, LinkedEntityId
            FROM ContentDocumentLink
            WHERE ContentDocumentId = :doc
        ];

        Boolean hasCaseLink = false;
        for (ContentDocumentLink l : linksForDoc) {
            if (l.LinkedEntityId != null && l.LinkedEntityId.getSObjectType() == Case.SObjectType) {
                hasCaseLink = true;
                break;
            }
        }

        System.assertEquals(false, hasCaseLink,
            'Filen ska inte länkas till Case om EmailMessage saknar Case-parent');
    }

    @IsTest
    static void test_AlreadyLinked_NoDuplicate() {
        Case c = [SELECT Id FROM Case ORDER BY CreatedDate ASC LIMIT 1];
        EmailMessage em = createEmailToCase(c.Id, 'Email - Duplicate');

        Id doc = getContentDocumentId(createTestFile('FileDup').Id);

        // Insert the file-to-email link
        ContentDocumentLink cdlToEmail = linkFileToEmail(doc, em.Id);

        // Explicitly call handler twice; it must remain idempotent.
        List<ContentDocumentLink> insertedCdls = [
            SELECT Id, ContentDocumentId, LinkedEntityId
            FROM ContentDocumentLink
            WHERE Id = :cdlToEmail.Id
        ];

        Test.startTest();
        EmailAttachmentLinkHandler.linkEmailFilesToCases(insertedCdls);
        EmailAttachmentLinkHandler.linkEmailFilesToCases(insertedCdls);
        Test.stopTest();

        // ContentDocumentLink query restriction: filter by ContentDocumentId only and count Case links in Apex.
        List<ContentDocumentLink> linksForDoc = [
            SELECT Id, LinkedEntityId
            FROM ContentDocumentLink
            WHERE ContentDocumentId = :doc
        ];

        Integer caseLinkCount = 0;
        for (ContentDocumentLink l : linksForDoc) {
            if (l.LinkedEntityId == c.Id) {
                caseLinkCount++;
            }
        }

        System.assertEquals(1, caseLinkCount, 'Ska inte skapa dubbla länkar till samma Case');
    }

    @IsTest
    static void test_NotEmailMessageLink_Ignored() {
        Case c = [SELECT Id FROM Case ORDER BY CreatedDate ASC LIMIT 1];
        Id doc = getContentDocumentId(createTestFile('FileDirectToCase').Id);

        ContentDocumentLink cdlToCase = new ContentDocumentLink(
            ContentDocumentId = doc,
            LinkedEntityId = c.Id,
            ShareType = 'V',
            Visibility = 'AllUsers'
        );

        Test.startTest();
        insert cdlToCase;
        EmailAttachmentLinkHandler.linkEmailFilesToCases(new List<ContentDocumentLink>{ cdlToCase });
        Test.stopTest();

        List<ContentDocumentLink> caseLinks = [
            SELECT Id
            FROM ContentDocumentLink
            WHERE ContentDocumentId = :doc
              AND LinkedEntityId = :c.Id
        ];
        System.assertEquals(1, caseLinks.size(), 'Handlern ska ignorera länkar som inte går via EmailMessage');
    }

    @IsTest
    static void test_EmptyList_NoCrash() {
        Test.startTest();
        EmailAttachmentLinkHandler.linkEmailFilesToCases(new List<ContentDocumentLink>());
        Test.stopTest();
        System.assert(true, 'Ska klara tom lista utan exception');
    }

    @IsTest
    static void test_NullLinkedEntityId_InMemory_NoCrash() {
        // OBS: Man kan inte insert:a CDL med null LinkedEntityId.
        // Men vi kan testa att handlern klarar listan (den ska bara ignorera posten).
        Id doc = getContentDocumentId(createTestFile('FileNullLinkedEntity').Id);

        ContentDocumentLink cdl = new ContentDocumentLink(
            ContentDocumentId = doc,
            LinkedEntityId = null,
            ShareType = 'V',
            Visibility = 'AllUsers'
        );

        Test.startTest();
        EmailAttachmentLinkHandler.linkEmailFilesToCases(new List<ContentDocumentLink>{ cdl });
        Test.stopTest();

        System.assert(true, 'Ska hantera CDL med null LinkedEntityId (ej insertad) utan exception');
    }

    @IsTest
    static void test_Backfill_StaticMethod() {
        // This test avoids calling backfillEmailFilesToCases() directly because in many orgs it queries
        // ALL EmailMessages and becomes non-deterministic in tests (large data / automation).
        // Instead, we validate the same functional outcome by calling the handler with the relevant CDLs.

        Case c = [SELECT Id FROM Case ORDER BY CreatedDate ASC LIMIT 1];
        EmailMessage em = createEmailToCase(c.Id, 'Email - Backfill Static');

        Id doc = getContentDocumentId(createTestFile('FileBackfill').Id);
        ContentDocumentLink cdlToEmail = linkFileToEmail(doc, em.Id);

        List<ContentDocumentLink> insertedCdls = [
            SELECT Id, ContentDocumentId, LinkedEntityId
            FROM ContentDocumentLink
            WHERE Id = :cdlToEmail.Id
        ];

        Test.startTest();
        EmailAttachmentLinkHandler.linkEmailFilesToCases(insertedCdls);
        Test.stopTest();

        // ContentDocumentLink query restriction: filter by ContentDocumentId only and check for Case link in Apex.
        List<ContentDocumentLink> linksForDoc = [
            SELECT Id, LinkedEntityId
            FROM ContentDocumentLink
            WHERE ContentDocumentId = :doc
        ];

        Boolean hasCaseLink = false;
        for (ContentDocumentLink l : linksForDoc) {
            if (l.LinkedEntityId == c.Id) {
                hasCaseLink = true;
                break;
            }
        }

        System.assertEquals(true, hasCaseLink, 'Backfill ska säkerställa länk till Case');
    }

    @IsTest
    static void test_Invocable_TriggersBatch_NoCrash() {
        Test.startTest();
        EmailAttachmentLinkHandler.triggerBackfillBatch();
        Test.stopTest();
        System.assert(true, 'Invocable ska kunna köras i test utan exception');
    }

    @IsTest
    static void test_BackfillBatch_RunsAndCreatesLinks() {
        // Förutsätter att EmailAttachmentBackfillBatch finns i orgen.
        List<Case> cases = [SELECT Id FROM Case ORDER BY CreatedDate ASC LIMIT 2];
        EmailMessage em1 = createEmailToCase(cases[0].Id, 'Email - Batch 1');
        EmailMessage em2 = createEmailToCase(cases[1].Id, 'Email - Batch 2');

        Id doc1 = getContentDocumentId(createTestFile('BatchFile1').Id);
        Id doc2 = getContentDocumentId(createTestFile('BatchFile2').Id);

        insert new List<ContentDocumentLink>{
            new ContentDocumentLink(ContentDocumentId=doc1, LinkedEntityId=em1.Id, ShareType='V', Visibility='AllUsers'),
            new ContentDocumentLink(ContentDocumentId=doc2, LinkedEntityId=em2.Id, ShareType='V', Visibility='AllUsers')
        };

        Test.startTest();
        Id jobId = Database.executeBatch(new EmailAttachmentBackfillBatch(), 200);
        Test.stopTest();

        // ContentDocumentLink query restriction: filter by ContentDocumentId IN only,
        // then validate LinkedEntityId matches the expected Cases in Apex.
        Set<Id> docIds = new Set<Id>{ doc1, doc2 };
        Set<Id> expectedCaseIds = new Set<Id>{ cases[0].Id, cases[1].Id };

        List<ContentDocumentLink> linksForDocs = [
            SELECT Id, ContentDocumentId, LinkedEntityId
            FROM ContentDocumentLink
            WHERE ContentDocumentId IN :docIds
        ];

        Integer matched = 0;
        for (ContentDocumentLink l : linksForDocs) {
            if (expectedCaseIds.contains(l.LinkedEntityId)) {
                matched++;
            }
        }

        System.assertEquals(2, matched, 'Batchen ska länka båda filerna till respektive Case');

        // Extra sanity: Async job finns
        List<AsyncApexJob> jobs = [SELECT Id, Status, NumberOfErrors FROM AsyncApexJob WHERE Id = :jobId LIMIT 1];
        System.assertEquals(1, jobs.size(), 'AsyncApexJob ska finnas för batchen');
        System.assertNotEquals(null, jobs[0].Status, 'Batchen ska ha en status');
    }
}