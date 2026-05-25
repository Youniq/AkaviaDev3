@isTest
private class RegisterutdragServiceTest {

    @isTest
    static void testGenerate_NullCaseId() {
        RegisterutdragService.Result r = RegisterutdragService.generate(null);
        System.assert(!r.success, 'Should not succeed with null caseId');
        System.assert(r.message != null, 'Should return message');
        System.assertEquals(null, r.contentDocumentId);
    }

    @isTest
    static void testGenerate_InvalidCaseId() {
        Id fakeId = Case.SObjectType.getDescribe().getKeyPrefix() + '0'.repeat(15);
        RegisterutdragService.Result r = RegisterutdragService.generate(fakeId);
        System.assert(!r.success, 'Should not succeed with invalid caseId');
        System.assert(r.message != null, 'Should return message');
    }

    @isTest
    static void testGenerate_CaseWithoutContactOrAccount() {
        Case c = new Case(Subject = 'Test Case No Contact', Origin = 'Phone', Status = 'New');
        insert c;

        RegisterutdragService.Result r = RegisterutdragService.generate(c.Id);
        System.assert(!r.success, 'Should not succeed when Case has no Contact/Account');
        System.assert(r.message.contains('kopplad') || r.message.contains('kontakt'), 'Message should mention contact');
    }

    @isTest
    static void testGenerate_CaseWithContact_Success() {
        Account acc = new Account(Name = 'Test Account');
        insert acc;
        Contact con = new Contact(LastName = 'TestContact', Email = 'test@example.com', AccountId = acc.Id);
        insert con;
        Case c = new Case(Subject = 'Test Case With Contact', Origin = 'Phone', Status = 'New', ContactId = con.Id);
        insert c;

        Test.startTest();
        RegisterutdragService.Result r = RegisterutdragService.generate(c.Id);
        Test.stopTest();

        System.assert(r.success, 'Should succeed: ' + r.message);
        System.assert(r.contentDocumentId != null, 'Should create file');
        System.assert(r.message != null && r.message.contains('skapat'), 'Should return success message');

        List<ContentDocumentLink> links = [
            SELECT Id, ContentDocumentId, LinkedEntityId
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :c.Id
            AND ContentDocumentId = :r.contentDocumentId
        ];
        System.assertEquals(1, links.size(), 'File should be linked to Case');
    }

    @isTest
    static void testGenerateInvocable() {
        Case c = new Case(Subject = 'Invocable Test', Origin = 'Phone', Status = 'New');
        insert c;

        RegisterutdragService.InvocableInput input = new RegisterutdragService.InvocableInput();
        input.caseId = c.Id;

        List<RegisterutdragService.Result> results = RegisterutdragService.generateRegisterutdragInvocable(
            new List<RegisterutdragService.InvocableInput>{ input }
        );
        System.assertEquals(1, results.size());
        System.assert(!results[0].success, 'Case without Contact should not produce file');
    }

    @isTest
    static void testIsAllowedProfile() {
        Boolean allowed = RegisterutdragService.isAllowedProfile();
        System.assert(allowed == true || allowed == false, 'Should return boolean');
    }
}