@IsTest
private class NewBillectaAutogiroServiceTest {

    private class BillectaSuccessMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"SessionToken":"token123","SessionId":"session456"}');
            return res;
        }
    }

    private static void setupTestBillectaConfig() {
        NewBillectaBankAccountService.Config cfg = new NewBillectaBankAccountService.Config();
        cfg.baseEndpoint = 'https://apitest.billecta.com';
        cfg.creditorPublicId = '467fe7dd-529b-47cc-bc63-d840981a52aa';
        cfg.secureToken = 'secure-token-value';
        cfg.accountLookupBaseUrl = 'https://accountlookup.test.billecta.com';
        cfg.clientScriptUrl = 'https://accountlookup.test.billecta.com/js/client.js';
        NewBillectaBankAccountService.testConfig = cfg;
    }

    private static Id getPersonAccountRecordTypeId() {
        Map<String, Schema.RecordTypeInfo> rtByDevName =
            Account.SObjectType.getDescribe().getRecordTypeInfosByDeveloperName();

        if (rtByDevName != null && rtByDevName.containsKey('PersonAccount')) {
            return rtByDevName.get('PersonAccount').getRecordTypeId();
        }

        for (Schema.RecordTypeInfo rti : Account.SObjectType.getDescribe().getRecordTypeInfos()) {
            if (rti.isAvailable() && rti.getName() == 'Person Account') {
                return rti.getRecordTypeId();
            }
        }

        return null;
    }

    private static Account createPersonAccount() {
        Id personAccountRtId = getPersonAccountRecordTypeId();

        System.assertNotEquals(
            null,
            personAccountRtId,
            'No Person Account record type available in test context.'
        );

        Account pa = new Account(
            RecordTypeId = personAccountRtId,
            FirstName = 'Test',
            LastName = 'Person'
        );
        insert pa;

        return pa;
    }

    @IsTest
    static void testStartAutogiroChange() {
        setupTestBillectaConfig();
        Test.setMock(HttpCalloutMock.class, new BillectaSuccessMock());

        Account pa = createPersonAccount();

        Test.startTest();
        NewBillectaAutogiroService.StartAutogiroBankChangeResponse response =
            NewBillectaAutogiroService.startAutogiroChange(pa.Id, '740121-0674');
        Test.stopTest();

        System.assertEquals('token123', response.sessionToken);
        System.assertEquals('session456', response.sessionId);
        System.assertEquals('https://accountlookup.test.billecta.com', response.accountLookupBaseUrl);
        System.assertEquals('https://accountlookup.billecta.com/js/client.js', response.clientScriptUrl);
        System.assertNotEquals(null, response.autogiroChangeLogId);

        Autogiro_Change_Log__c logRec = [
            SELECT Account__c, Status__c, Billecta_Session_Id__c
            FROM Autogiro_Change_Log__c
            WHERE Id = :response.autogiroChangeLogId
        ];

        System.assertEquals(pa.Id, logRec.Account__c);
        System.assertEquals('Started', logRec.Status__c);
        System.assertEquals('session456', logRec.Billecta_Session_Id__c);
    }

    @IsTest
    static void testCompleteAutogiroChange() {
        Account pa = createPersonAccount();

        Autogiro_Change_Log__c logRec = new Autogiro_Change_Log__c(
            Account__c = pa.Id,
            Status__c = 'Started',
            Billecta_Session_Id__c = 'session456'
        );
        insert logRec;

        Test.startTest();
        Id updatedId = NewBillectaAutogiroService.completeAutogiroChange(
            logRec.Id,
            'Success',
            '8123',
            '1234567890',
            'SEB',
            'Skandinaviska Enskilda Banken'
        );
        Test.stopTest();

        System.assertEquals(logRec.Id, updatedId);

        Autogiro_Change_Log__c updatedLog = [
            SELECT Status__c, Session_State__c, Clearing_Number__c, Account_Number__c,
                   Bank_Code__c, Bank_Name__c, Completed_At__c
            FROM Autogiro_Change_Log__c
            WHERE Id = :logRec.Id
        ];

        System.assertEquals('Completed', updatedLog.Status__c);
        System.assertEquals('Success', updatedLog.Session_State__c);
        System.assertEquals('8123', updatedLog.Clearing_Number__c);
        System.assertEquals('1234567890', updatedLog.Account_Number__c);
        System.assertEquals('SEB', updatedLog.Bank_Code__c);
        System.assertEquals('Skandinaviska Enskilda Banken', updatedLog.Bank_Name__c);
        System.assertNotEquals(null, updatedLog.Completed_At__c);
    }

    @IsTest
    static void testFailAutogiroChange() {
        Account pa = createPersonAccount();

        Autogiro_Change_Log__c logRec = new Autogiro_Change_Log__c(
            Account__c = pa.Id,
            Status__c = 'Started',
            Billecta_Session_Id__c = 'session456'
        );
        insert logRec;

        Test.startTest();
        Id updatedId = NewBillectaAutogiroService.failAutogiroChange(
            logRec.Id,
            'Failed',
            'Failed',
            'Technical error'
        );
        Test.stopTest();

        System.assertEquals(logRec.Id, updatedId);

        Autogiro_Change_Log__c updatedLog = [
            SELECT Status__c, Session_State__c, Error_Message__c, Completed_At__c
            FROM Autogiro_Change_Log__c
            WHERE Id = :logRec.Id
        ];

        System.assertEquals('Failed', updatedLog.Status__c);
        System.assertEquals('Failed', updatedLog.Session_State__c);
        System.assertEquals('Technical error', updatedLog.Error_Message__c);
        System.assertNotEquals(null, updatedLog.Completed_At__c);
    }

    @IsTest
    static void testStartAutogiroChange_MissingAccountId() {
        Boolean exceptionThrown = false;

        Test.startTest();
        try {
            NewBillectaAutogiroService.startAutogiroChange(null, '740121-0674');
        } catch (AuraHandledException e) {
            exceptionThrown = true;
        }
        Test.stopTest();

        System.assertEquals(true, exceptionThrown);
    }

    @IsTest
    static void testCompleteAutogiroChange_MissingLogId() {
        Boolean exceptionThrown = false;

        Test.startTest();
        try {
            NewBillectaAutogiroService.completeAutogiroChange(
                null,
                'Success',
                '8123',
                '1234567890',
                'SEB',
                'Skandinaviska Enskilda Banken'
            );
        } catch (AuraHandledException e) {
            exceptionThrown = true;
        }
        Test.stopTest();

        System.assertEquals(true, exceptionThrown);
    }

    @IsTest
    static void testFailAutogiroChange_MissingLogId() {
        Boolean exceptionThrown = false;

        Test.startTest();
        try {
            NewBillectaAutogiroService.failAutogiroChange(
                null,
                'Failed',
                'Failed',
                'Technical error'
            );
        } catch (AuraHandledException e) {
            exceptionThrown = true;
        }
        Test.stopTest();

        System.assertEquals(true, exceptionThrown);
    }

    @IsTest
    static void testStartAutogiroChange_NotPersonAccount() {
        setupTestBillectaConfig();

        Account acc = new Account(Name = 'Business Account');
        insert acc;

        Boolean exceptionThrown = false;

        Test.startTest();
        try {
            NewBillectaAutogiroService.startAutogiroChange(acc.Id, '740121-0674');
        } catch (AuraHandledException e) {
            exceptionThrown = true;
        }
        Test.stopTest();

        System.assertEquals(true, exceptionThrown);
    }

    @IsTest
    static void testSaveSuccessfulLookup() {
        Account acc = new Account(Name = 'Lookup Test Account');
        insert acc;

        Test.startTest();
        Id recId = NewBillectaAutogiroService.saveSuccessfulLookup(
            acc.Id,
            'Success',
            '8123',
            '1234567890',
            'SEB',
            'Skandinaviska Enskilda Banken'
        );
        Test.stopTest();

        System.assertNotEquals(null, recId);

        Billecta_Bank_Account_Result__c rec = [
            SELECT Related_Record_Id__c,
                   Session_State__c,
                   Clearing_Number__c,
                   Account_Number__c,
                   Bank_Code__c,
                   Bank_Name__c,
                   Status__c,
                   Lookup_Timestamp__c
            FROM Billecta_Bank_Account_Result__c
            WHERE Id = :recId
        ];

        System.assertEquals(String.valueOf(acc.Id), rec.Related_Record_Id__c);
        System.assertEquals('Success', rec.Session_State__c);
        System.assertEquals('8123', rec.Clearing_Number__c);
        System.assertEquals('1234567890', rec.Account_Number__c);
        System.assertEquals('SEB', rec.Bank_Code__c);
        System.assertEquals('Skandinaviska Enskilda Banken', rec.Bank_Name__c);
        System.assertEquals('Success', rec.Status__c);
        System.assertNotEquals(null, rec.Lookup_Timestamp__c);
    }

    @IsTest
    static void testSaveFailedLookup() {
        Account acc = new Account(Name = 'Lookup Test Account');
        insert acc;

        Test.startTest();
        Id recId = NewBillectaAutogiroService.saveFailedLookup(
            acc.Id,
            'Failed',
            'Failed',
            'Technical error'
        );
        Test.stopTest();

        System.assertNotEquals(null, recId);

        Billecta_Bank_Account_Result__c rec = [
            SELECT Related_Record_Id__c,
                   Status__c,
                   Session_State__c,
                   Error_Message__c,
                   Lookup_Timestamp__c
            FROM Billecta_Bank_Account_Result__c
            WHERE Id = :recId
        ];

        System.assertEquals(String.valueOf(acc.Id), rec.Related_Record_Id__c);
        System.assertEquals('Failed', rec.Status__c);
        System.assertEquals('Failed', rec.Session_State__c);
        System.assertEquals('Technical error', rec.Error_Message__c);
        System.assertNotEquals(null, rec.Lookup_Timestamp__c);
    }
}