@isTest
private class EmailFileToCaseBackfillBatchTest {

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

    private static EmailMessage createEmail(Id parentId) {
        EmailMessage em = new EmailMessage(
            ParentId = parentId,
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
    static void test_FileLinkedToEmail_createsLinkToCase() {
        Case c = new Case(Subject='Test', Status='New', Origin='Phone');
        insert c;

        EmailMessage em = createEmail(c.Id);
        Id docId = getDocId(createFile('F1').Id);

        insert new ContentDocumentLink(
            ContentDocumentId = docId,
            LinkedEntityId = em.Id,
            ShareType = 'V',
            Visibility = 'AllUsers'
        );

        Test.startTest();
        Database.executeBatch(new EmailFileToCaseBackfillBatch(), 200);
        Test.stopTest();

        List<ContentDocumentLink> links = [
            SELECT Id
            FROM ContentDocumentLink
            WHERE ContentDocumentId = :docId
            AND LinkedEntityId = :c.Id
        ];
        System.assertEquals(1, links.size(), 'File should be linked to Case');
    }

    @isTest
    static void test_FileLinkedToEmailWithoutCase_doesNothing() {
        Account a = new Account(Name='A');
        insert a;

        EmailMessage em = createEmail(a.Id);
        Id docId = getDocId(createFile('F2').Id);

        insert new ContentDocumentLink(
            ContentDocumentId = docId,
            LinkedEntityId = em.Id,
            ShareType = 'V',
            Visibility = 'AllUsers'
        );

        Test.startTest();
        Database.executeBatch(new EmailFileToCaseBackfillBatch(), 200);
        Test.stopTest();

        List<ContentDocumentLink> links = [
            SELECT Id
            FROM ContentDocumentLink
            WHERE ContentDocumentId = :docId
            AND LinkedEntityId LIKE '500%'
        ];
        System.assertEquals(0, links.size(), 'File should not be linked to Case');
    }
}
