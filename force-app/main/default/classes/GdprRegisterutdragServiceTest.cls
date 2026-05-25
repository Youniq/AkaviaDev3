@isTest
private class GdprRegisterutdragServiceTest {

    @TestSetup
    static void makeData() {
        TestDataFactory.setupBasicTestData();
        TestDataFactorySetupParams params = new TestDataFactorySetupParams();
        params.numberOfAccounts = 1;
        params.numberOfCases = 1;
        params.numberOfCaseFiles = 1;
        params.numberOfCaseFeedItems = 1;
        TestDataFactory.setupTestData(params);
    }

    private static Account getPersonAccount() {
        return [
            SELECT Id, IsPersonAccount, PersonContactId
            FROM Account
            WHERE IsPersonAccount = TRUE
            LIMIT 1
        ];
    }

    private static void addEmailAndCallTask(Account person) {
        List<Case> cases = [
            SELECT Id
            FROM Case
            WHERE AccountId = :person.Id
            LIMIT 1
        ];
        if (cases.isEmpty()) {
            return;
        }

        insert new EmailMessage(
            ParentId = cases[0].Id,
            Subject = 'Testämne',
            TextBody = 'E-posttext',
            FromAddress = 'from@test.akavia.se',
            ToAddress = 'to@test.akavia.se',
            Incoming = true,
            Status = '3'
        );

        if (person.PersonContactId != null) {
            insert new Task(
                WhoId = person.PersonContactId,
                Subject = 'Telefonsamtal',
                Type = 'Call',
                TaskSubtype = 'Call',
                Status = 'Completed',
                Description = 'Samtalsanteckning'
            );
        }
    }

    @isTest
    static void testGenerateForAccount_NullAccountId() {
        GdprRegisterutdragService.Result r = GdprRegisterutdragService.generateForAccount(null);
        System.assertEquals(false, r.success, 'Null accountId should fail');
        System.assert(r.message.contains('saknas'), 'Expected missing id message: ' + r.message);
    }

    @isTest
    static void testGenerateForAccount_NotPersonAccount() {
        Id employerRtId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName()
            .get('Employer')
            .getRecordTypeId();
        Account employer = new Account(
            Name = 'GDPR Test Employer',
            RecordTypeId = employerRtId
        );
        insert employer;

        GdprRegisterutdragService.Result r = GdprRegisterutdragService.generateForAccount(employer.Id);
        System.assertEquals(false, r.success, 'Employer account should not succeed');
        System.assert(r.message.contains('personkonto'), 'Expected person account message: ' + r.message);
    }

    @isTest
    static void testGenerateForAccount_Csv_Success() {
        Account person = getPersonAccount();
        addEmailAndCallTask(person);

        Test.startTest();
        GdprRegisterutdragService.Result r = GdprRegisterutdragService.generateForAccount(person.Id);
        Test.stopTest();

        System.assertEquals(true, r.success, 'CSV extract should succeed: ' + r.message);
        System.assertNotEquals(null, r.contentDocumentId, 'Should create extract file');
        System.assert(
            String.isNotBlank(r.extractFileName) && r.extractFileName.endsWith('.csv'),
            'Extract should be CSV: ' + r.extractFileName
        );
        System.assert(String.isNotBlank(r.detailMessage), 'Detail message should be set');
        System.assert(r.detailMessage.contains('Utdragsfil'), 'Detail should list extract file');
        System.assert(r.detailMessage.contains('ContentDocumentId (utdrag)'), 'Detail should include extract id');

        List<ContentDocumentLink> links = [
            SELECT Id
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :person.Id
              AND ContentDocumentId = :r.contentDocumentId
        ];
        System.assertEquals(1, links.size(), 'Extract should be linked to person account');
    }

    @isTest
    static void testGenerateForAccountWithFormat_Xls_Success() {
        Account person = getPersonAccount();

        Test.startTest();
        GdprRegisterutdragService.Result r = GdprRegisterutdragService.generateForAccountWithFormat(
            person.Id,
            'XLS'
        );
        Test.stopTest();

        System.assertEquals(true, r.success, 'XLS extract should succeed: ' + r.message);
        System.assert(
            String.isNotBlank(r.extractFileName) && r.extractFileName.endsWith('.xls'),
            'Extract should be XLS: ' + r.extractFileName
        );
    }

    @isTest
    static void testGenerateForAccountWithFormat_XlsxAndXml() {
        Account person = getPersonAccount();

        Test.startTest();
        GdprRegisterutdragService.Result xlsx = GdprRegisterutdragService.generateForAccountWithFormat(
            person.Id,
            'XLSX'
        );
        GdprRegisterutdragService.Result xml = GdprRegisterutdragService.generateForAccountWithFormat(
            person.Id,
            'XML'
        );
        GdprRegisterutdragService.Result defaultFmt = GdprRegisterutdragService.generateForAccountWithFormat(
            person.Id,
            null
        );
        Test.stopTest();

        System.assertEquals(true, xlsx.success, xlsx.message);
        System.assert(xlsx.extractFileName.endsWith('.xlsx'), xlsx.extractFileName);
        System.assertEquals(true, xml.success, xml.message);
        System.assert(xml.extractFileName.endsWith('.xml'), xml.extractFileName);
        System.assertEquals(true, defaultFmt.success, defaultFmt.message);
        System.assert(defaultFmt.extractFileName.endsWith('.csv'), defaultFmt.extractFileName);
    }

    @isTest
    static void testGenerateForAccount_WithCaseFiles_CreatesZip() {
        Account person = getPersonAccount();

        Test.startTest();
        GdprRegisterutdragService.Result r = GdprRegisterutdragService.generateForAccount(person.Id);
        Test.stopTest();

        System.assertEquals(true, r.success, 'Should succeed: ' + r.message);
        System.assertEquals('CREATED', r.zipStatus, 'Zip should be created when case has files');
        System.assertNotEquals(null, r.zipContentDocumentId, 'Zip ContentDocument should exist');
        System.assert(r.zipEntryCount != null && r.zipEntryCount > 0, 'Zip should contain files');
        System.assert(
            r.detailMessage.contains('ContentDocumentId (zip)'),
            'Detail should include zip id'
        );

        List<ContentDocumentLink> zipLinks = [
            SELECT Id
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :person.Id
              AND ContentDocumentId = :r.zipContentDocumentId
        ];
        System.assertEquals(1, zipLinks.size(), 'Zip should be linked to person account');
    }

    @isTest
    static void testGenerateForAccount_ZipDuplicateFileNames() {
        Account person = getPersonAccount();
        Case c = [SELECT Id FROM Case WHERE AccountId = :person.Id LIMIT 1];

        ContentVersion dupA = new ContentVersion(
            Title = 'SammaFil',
            PathOnClient = 'SammaFil.txt',
            VersionData = Blob.valueOf('A'),
            IsMajorVersion = true
        );
        ContentVersion dupB = new ContentVersion(
            Title = 'SammaFil',
            PathOnClient = 'SammaFil.txt',
            VersionData = Blob.valueOf('B'),
            IsMajorVersion = true
        );
        insert new List<ContentVersion>{ dupA, dupB };

        Set<Id> docIds = new Set<Id>();
        for (ContentVersion cv : [
            SELECT ContentDocumentId
            FROM ContentVersion
            WHERE Id IN :new List<Id>{ dupA.Id, dupB.Id }
        ]) {
            docIds.add(cv.ContentDocumentId);
        }

        List<ContentDocumentLink> links = new List<ContentDocumentLink>();
        for (Id docId : docIds) {
            links.add(
                new ContentDocumentLink(
                    ContentDocumentId = docId,
                    LinkedEntityId = c.Id,
                    ShareType = 'V',
                    Visibility = 'AllUsers'
                )
            );
        }
        insert links;

        Test.startTest();
        GdprRegisterutdragService.Result r = GdprRegisterutdragService.generateForAccount(person.Id);
        Test.stopTest();

        System.assertEquals(true, r.success, r.message);
        System.assertEquals('CREATED', r.zipStatus, 'Zip should handle duplicate names');
        System.assert(r.zipEntryCount >= 2, 'Zip should include duplicate-named files');
    }

    @isTest
    static void testGenerateForAccount_NoCaseAttachments_ZipNone() {
        Account person = getPersonAccount();
        delete [SELECT Id FROM Case WHERE AccountId = :person.Id];

        Test.startTest();
        GdprRegisterutdragService.Result r = GdprRegisterutdragService.generateForAccount(person.Id);
        Test.stopTest();

        System.assertEquals(true, r.success, r.message);
        System.assert(
            r.zipStatus == null || r.zipStatus == 'NONE',
            'No case files should not create zip'
        );
    }

    @isTest
    static void testGenerateForAccount_ExtractContentSections() {
        Account person = getPersonAccount();
        addEmailAndCallTask(person);

        Test.startTest();
        GdprRegisterutdragService.Result r = GdprRegisterutdragService.generateForAccount(person.Id);
        Test.stopTest();

        System.assertEquals(true, r.success, r.message);

        ContentVersion cv = [
            SELECT VersionData
            FROM ContentVersion
            WHERE ContentDocumentId = :r.contentDocumentId
              AND IsLatest = TRUE
            LIMIT 1
        ];
        String body = cv.VersionData.toString();
        System.assert(body.contains('=== Person ==='), 'Should include person section');
        System.assert(body.contains('e-postmeddelande'), 'Should list email on case');
        System.assert(body.contains('Telefonlogg'), 'Should include call task as phone log');
        System.assert(body.contains('GDPR') && body.contains('Leverans'), 'Should include delivery section');
    }
}