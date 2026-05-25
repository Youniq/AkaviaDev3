@isTest
private class VoteraAccountServiceTest {
    @isTest static void testBulkEndpoint() {
        // Create test accounts
        Account a1 = new Account(Name='T A1'); insert a1;
        Account a2 = new Account(Name='T A2'); insert a2;

        // Prepare REST request payload
        String jsonBody = JSON.serialize(new Map<String,Object>{
            'ids' => new List<String>{a1.Id, a2.Id},
            'fields' => new List<String>{'Id','Name'}
        });

        // Simulate REST call
        RestRequest req = new RestRequest();
        req.requestUri = '/services/apexrest/accounts/bulk';
        req.httpMethod = 'POST';
        req.addHeader('Content-Type','application/json');
        req.requestBody = Blob.valueOf(jsonBody);
        RestContext.request = req;
        RestContext.response = new RestResponse();

        // Call
        Test.startTest();
        VoteraAccountService.doPost();
        Test.stopTest();

        // Assert response
        RestResponse res = RestContext.response;
        System.assertEquals(200, res.statusCode);
        Map<String,Object> resp = (Map<String,Object>) JSON.deserializeUntyped(res.responseBody.toString());
        System.assert(resp.containsKey('records'));
        List<Object> records = (List<Object>) resp.get('records');
        System.assert(records.size() == 2);
    }

    @isTest static void testUserIdMode(){
        // Create a standard internal user (cannot associate ContactId without portal licensing) -> expect NO_ACCOUNT.
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User u = new User(
            Alias='tuser', Email='tuser@example.com', EmailEncodingKey='UTF-8',
            LastName='Tester', LanguageLocaleKey='en_US', LocaleSidKey='en_US',
            TimeZoneSidKey='Europe/Paris', Username=System.now().getTime()+'@example.com',
            ProfileId=p.Id
        );
        insert u;

        String jsonBody = JSON.serialize(new Map<String,Object>{
            'ids' => new List<String>{u.Id},
            'fields' => new List<String>{'Id','Name'}
        });
        RestRequest req = new RestRequest();
        req.requestUri = '/services/apexrest/accounts/bulk';
        req.httpMethod = 'POST';
        req.addHeader('Content-Type','application/json');
        req.requestBody = Blob.valueOf(jsonBody);
        RestContext.request = req;
        RestContext.response = new RestResponse();
        Test.startTest();
        VoteraAccountService.doPost();
        Test.stopTest();
        RestResponse res = RestContext.response;
        System.assertEquals(200, res.statusCode);
        Map<String,Object> resp = (Map<String,Object>) JSON.deserializeUntyped(res.responseBody.toString());
        System.assertEquals('USER', resp.get('mode'));
        List<Object> records = (List<Object>) resp.get('records');
        System.assertEquals(1, records.size());
    Map<String,Object> rec = (Map<String,Object>) records[0];
    System.assertEquals(u.Id, (String) rec.get('UserId'));
    System.assertEquals('NO_ACCOUNT', (String) rec.get('error'));
    }

    @isTest static void testUserIdModeWithInjectedMapping(){
        // Create account
        Account a = new Account(Name='Mapped Acct'); insert a;
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User u = new User(
            Alias='tmap', Email='tmap@example.com', EmailEncodingKey='UTF-8',
            LastName='MapTester', LanguageLocaleKey='en_US', LocaleSidKey='en_US',
            TimeZoneSidKey='Europe/Paris', Username=System.now().getTime()+'map@example.com',
            ProfileId=p.Id
        );
        insert u;
        // Inject mapping
        VoteraAccountService.testUserToAccountOverride = new Map<Id, Id>{u.Id => a.Id};

        String jsonBody = JSON.serialize(new Map<String,Object>{
            'ids' => new List<String>{u.Id},
            'fields' => new List<String>{'Id','Name'}
        });
        RestRequest req = new RestRequest();
        req.requestUri = '/services/apexrest/accounts/bulk';
        req.httpMethod = 'POST';
        req.addHeader('Content-Type','application/json');
        req.requestBody = Blob.valueOf(jsonBody);
        RestContext.request = req;
        RestContext.response = new RestResponse();
        Test.startTest();
        VoteraAccountService.doPost();
        Test.stopTest();
        RestResponse res = RestContext.response;
        System.assertEquals(200, res.statusCode);
        Map<String,Object> resp = (Map<String,Object>) JSON.deserializeUntyped(res.responseBody.toString());
        System.assertEquals('USER', resp.get('mode'));
        List<Object> records = (List<Object>) resp.get('records');
        System.assertEquals(1, records.size());
        Map<String,Object> rec = (Map<String,Object>) records[0];
        System.assertEquals(u.Id, (String) rec.get('UserId'));
        System.assertEquals(a.Id, (String) rec.get('Id'));
        System.assertEquals('USER', (String) rec.get('SourceIdType'));
        System.assertEquals(u.Id, (String) rec.get('RequestedId'));
    }
}