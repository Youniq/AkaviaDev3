@isTest
private class EmailAttachmentLinkHandlerTest {

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
        return [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :contentVersionId].ContentDocumentId;
    }

    private static EmailMessage createEmailMessage(Id caseId, String subject) {
        EmailMessage em = new EmailMessage(
            ParentId = caseId,
            Subject = subject,
            TextBody = 'Test email body',
            FromAddress = 'test@example.com',
            ToAddress = 'recipient@example.com',
            Status = '3'
        );
        insert em;
        return em;
    }

    @isTest
    static void test_CDLToEmailMessage_creates_CDLToCase() {
        Case c = new Case(Subject='Test', Status='New', Origin='Phone');
        insert c;

        EmailMessage em = createEmailMessage(c.Id, 'Email');

        Id docId = getContentDocumentId(createTestFile('F1').Id);

        Test.startTest();
        insert new ContentDocumentLink(
            ContentDocumentId = docId,
            LinkedEntityId = em.Id,
            ShareType = 'V',
            Visibility = 'AllUsers'
        );
        Test.stopTest();

        List<ContentDocumentLink> caseLinks = [
            SELECT Id
            FROM ContentDocumentLink
            WHERE ContentDocumentId = :docId
            AND LinkedEntityId = :c.Id
        ];
        System.assertEquals(1, caseLinks.size(), 'File should be linked to Case');
    }

    @isTest
    static void test_NoCaseParent_doesNotLink() {
        // Kontroll-case som INTE ska få filen
        Case control = new Case(Subject='Control', Status='New', Origin='Phone');
        insert control;

        Account a = new Account(Name='A');
        insert a;

        EmailMessage em = new EmailMessage(
            RelatedToId = a.Id, // not Case
            Subject = 'No case',
            TextBody = 'body',
            FromAddress = 'test@example.com',
            ToAddress = 'recipient@example.com',
            Status = '3'
        );
        insert em;

        Id docId = getContentDocumentId(createTestFile('F2').Id);

        Test.startTest();
        insert new ContentDocumentLink(
            ContentDocumentId = docId,
            LinkedEntityId = em.Id,
            ShareType = 'V',
            Visibility = 'AllUsers'
        );
        Test.stopTest();

        // Verifiera att ingen länk skapats till vårt kontroll-case
        List<ContentDocumentLink> linksToControlCase = [
            SELECT Id
            FROM ContentDocumentLink
            WHERE ContentDocumentId = :docId
            AND LinkedEntityId = :control.Id
        ];
        System.assertEquals(0, linksToControlCase.size(),
            'Should not link to Case when email is not related to Case');
    }

    @isTest
    static void test_Idempotent_noDuplicates() {
        Case c = new Case(Subject='Test', Status='New', Origin='Phone');
        insert c;

        EmailMessage em = createEmailMessage(c.Id, 'Email');

        Id docId = getContentDocumentId(createTestFile('F3').Id);

        ContentDocumentLink cdl = new ContentDocumentLink(
            ContentDocumentId = docId,
            LinkedEntityId = em.Id,
            ShareType = 'V',
            Visibility = 'AllUsers'
        );

        Test.startTest();
        insert cdl; // trigger creates link to Case
        // call again by inserting a second CDL to same email/doc is not allowed normally, so call handler explicitly once:
        EmailAttachmentLinkHandler.linkEmailFilesToCases(new List<ContentDocumentLink>{cdl});
        Test.stopTest();

        List<ContentDocumentLink> caseLinks = [
            SELECT Id
            FROM ContentDocumentLink
            WHERE ContentDocumentId = :docId
            AND LinkedEntityId = :c.Id
        ];
        System.assertEquals(1, caseLinks.size(), 'Should still be exactly 1 link to Case');
    }

    @isTest
    static void test_SameFileOnTwoEmails_linksToTwoCases() {
        Case c1 = new Case(Subject='C1', Status='New', Origin='Phone');
        Case c2 = new Case(Subject='C2', Status='New', Origin='Phone');
        insert new List<Case>{c1, c2};

        EmailMessage em1 = createEmailMessage(c1.Id, 'E1');
        EmailMessage em2 = createEmailMessage(c2.Id, 'E2');

        Id docId = getContentDocumentId(createTestFile('Shared').Id);

        Test.startTest();
        insert new List<ContentDocumentLink>{
            new ContentDocumentLink(ContentDocumentId=docId, LinkedEntityId=em1.Id, ShareType='V', Visibility='AllUsers'),
            new ContentDocumentLink(ContentDocumentId=docId, LinkedEntityId=em2.Id, ShareType='V', Visibility='AllUsers')
        };
        Test.stopTest();

        List<ContentDocumentLink> caseLinks = [
            SELECT Id, LinkedEntityId
            FROM ContentDocumentLink
            WHERE ContentDocumentId = :docId
            AND LinkedEntityId IN :new Set<Id>{c1.Id, c2.Id}
        ];
        System.assertEquals(2, caseLinks.size(), 'File should be linked to both Cases');
    }
}
