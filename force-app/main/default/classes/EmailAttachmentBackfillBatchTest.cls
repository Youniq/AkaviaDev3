@isTest
private class EmailAttachmentBackfillBatchTest {

    private static ContentVersion createFile(String name) {
        ContentVersion cv = new ContentVersion(
            Title = name,
            PathOnClient = name + '.txt',
            VersionData = Blob.valueOf('test'),
            IsMajorVersion = true
        );
        insert cv;
        return cv;
    }

    private static Id getDocId(Id versionId) {
        return [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :versionId]
            .ContentDocumentId;
    }

    // Case-only helper (ParentId must be Case)
    private static EmailMessage createEmailForCase(Id caseId) {
        EmailMessage em = new EmailMessage(
            ParentId = caseId,
            Subject = 'Test',
            TextBody = 'Body',
            FromAddress = 'a@test.com',
            ToAddress = 'b@test.com',
            Status = '3'
        );
        insert em;
        return em;
    }

    // Non-case helper (use RelatedToId)
    private static EmailMessage createEmailRelatedTo(Id relatedToId) {
        EmailMessage em = new EmailMessage(
            RelatedToId = relatedToId,
            Subject = 'Test',
            TextBody = 'Body',
            FromAddress = 'a@test.com',
            ToAddress = 'b@test.com',
            Status = '3'
        );
        insert em;
        return em;
    }

    @isTest
    static void test_Backfill_createsLinkToCase() {
        Case c = new Case(Subject='Test', Status='New', Origin='Phone');
        insert c;

        EmailMessage em = createEmailForCase(c.Id);
        Id docId = getDocId(createFile('F1').Id);

        insert new ContentDocumentLink(
            ContentDocumentId = docId,
            LinkedEntityId = em.Id,
            ShareType = 'V',
            Visibility = 'AllUsers'
        );

        Test.startTest();
        Database.executeBatch(new EmailAttachmentBackfillBatch(), 200);
        Test.stopTest();

        List<ContentDocumentLink> links = [
            SELECT Id
            FROM ContentDocumentLink
            WHERE ContentDocumentId = :docId
            AND LinkedEntityId = :c.Id
        ];
        System.assertEquals(1, links.size(), 'File should be linked to Case by batch');
    }

    @isTest
    static void test_Backfill_doesNotLink_whenNoCaseParent() {
        // Control Case (must not get the link)
        Case controlCase = new Case(Subject='Control', Status='New', Origin='Phone');
        insert controlCase;

        Account a = new Account(Name='A');
        insert a;

        // EmailMessage NOT related to Case
        EmailMessage em = createEmailRelatedTo(a.Id);

        Id docId = getDocId(createFile('F2').Id);

        insert new ContentDocumentLink(
            ContentDocumentId = docId,
            LinkedEntityId = em.Id,
            ShareType = 'V',
            Visibility = 'AllUsers'
        );

        Test.startTest();
        Database.executeBatch(new EmailAttachmentBackfillBatch(), 200);
        Test.stopTest();

        // Ensure no link was created to the control Case
        List<ContentDocumentLink> links = [
            SELECT Id
            FROM ContentDocumentLink
            WHERE ContentDocumentId = :docId
            AND LinkedEntityId = :controlCase.Id
        ];
        System.assertEquals(0, links.size(), 'File should not be linked to Case when EmailMessage is not on a Case');
    }
}
