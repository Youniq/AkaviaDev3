@isTest
private class RegisterutdragControllerTest {

    @isTest
    static void testGenerateRegisterutdrag_NoContact() {
        Case c = new Case(Subject = 'Controller Test', Origin = 'Phone', Status = 'New');
        insert c;

        RegisterutdragService.Result r = RegisterutdragController.generateRegisterutdrag(c.Id);
        System.assert(r != null);
        System.assert(!r.success, 'Case without Contact should not succeed');
    }

    @isTest
    static void testGenerateRegisterutdrag_WithContact() {
        Account acc = new Account(Name = 'Test Acc');
        insert acc;
        Contact con = new Contact(LastName = 'Test', Email = 't@example.com', AccountId = acc.Id);
        insert con;
        Case c = new Case(Subject = 'With Contact', Origin = 'Phone', Status = 'New', ContactId = con.Id);
        insert c;

        RegisterutdragService.Result r = RegisterutdragController.generateRegisterutdrag(c.Id);
        System.assert(r != null);
        System.assert(r.success, 'Should succeed with Contact: ' + r.message);
        System.assert(r.contentDocumentId != null, 'Should attach file');
    }

    @isTest
    static void testGenerateRegisterutdrag_NullCaseId() {
        RegisterutdragService.Result r = RegisterutdragController.generateRegisterutdrag(null);
        System.assert(r != null);
        System.assert(!r.success, 'Null caseId should not succeed');
    }
}