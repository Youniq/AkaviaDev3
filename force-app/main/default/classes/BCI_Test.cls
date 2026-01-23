/******************************
 * Test Class to cover:
 * - BCI_Utils.apxc
 * - BCI_HandlerInvocable.apxc
 * - BCI_PersonRespone.apxc
*******************************/

@isTest
public class BCI_Test {

    @isTest
    static void getSwedishPerson() {
        System.debug('*** BCI_Test getSwedishPerson() starting ***');

        Account emptyAcc = new Account();
        String ssn = '192606246697';
        String country = 'Sweden';
        Blob SE_NationalRegistrationAddress_ResponseBody = Blob.valueOf('{"persons":[{"person":{"gedi":"MC0D5C7D8254","legalId":{"socialSecurityNumber":"192606246697"},"protectedIdentity":false,"firstNames":["Åsa"],' +  
                                                                        '"preferredFirstName":"Åsa","familyName":"Åman","gender":"Female","dateOfBirth":"1926-06-24","yearOfBirth":1926,"directMarketingRestriction":false,' + 
                                                                        '"phoneList":[{"type":"Other","number":"+4608524865"}],"addressList":[{"type":"Postal","subType":"Domicile","streetName":"Lilla Bommens Torg",' + 
                                                                        '"streetNumber":"90","postalCode":"34255","city":"Växjö","country":"SE","fullAddressString":"Lilla Bommens Torg 90","formattedAddress":["Lilla Bommens Torg 90", ' + 
                                                                        '"34255 Växjö"]}],"relationshipList":[],"enrichment":{"purchasingPower":"High","phaseOfLife":"Established No Children","housingType":"Single Dwelling Building", ' + 
                                                                        '"education":"Academic","housingOwnership":"Owned"},"deregistered":false},"sourceList":[],"subscriptionState":{"subscribed":false},"memento":"eyJrZXkiOiJNQzBENUM3RDgyNTQiLCJ0eXBlIjoiZ2VkaSJ9"}]}');

        Map<String, HttpResponse> mockResponseMap = new Map<String, HttpResponse>();
        HttpResponse res = new HttpResponse();
        res.setStatus('OK');
        res.setStatusCode(200);
        res.setBodyAsBlob(SE_NationalRegistrationAddress_ResponseBody);

        Map<String, HttpResponse> responseByBodyContent = new Map<String, HttpResponse>{
            'callout:BisnodeBCI_Prod/person/search' + '?' + 'sourceCountry=' + 'SE' + '&' + 'legalId=' + ssn => res,
            'callout:BisnodeBCI_Test/person/search' + '?' + 'sourceCountry=' + 'SE' + '&' + 'legalId=' + ssn => res
        };

        EchoHttpMock.setTestMockResponse(404, 'Not Authorized', null, responseByBodyContent);

        BCI_HandlerInvocable.Request request = new BCI_HandlerInvocable.Request();
        request.account = emptyAcc;
        request.SSN = ssn;
        request.country = country;

        List<BCI_HandlerInvocable.Request> inputList = new List<BCI_HandlerInvocable.Request>();
        inputList.add(request);

        Test.StartTest();
        List<BCI_HandlerInvocable.Result> resultList = BCI_HandlerInvocable.populateInformation(inputList);
        Test.stopTest(); 

        BCI_HandlerInvocable.Result result = resultList[0];
        Account account = result.account;
        system.assert(result.message == null);
        system.assert(account.FirstName == 'Åsa');
        system.assert(account.LastName == 'Åman');
        system.assert(account.PersonMailingStreet == 'Lilla Bommens Torg 90');
        system.assert(account.PersonMailingCity == 'Växjö');
        system.assert(account.PersonMailingPostalCode == '34255');
        system.assert(account.PersonMailingCountry == 'Sweden');
    }

    @isTest
    static void getSwedishPerson_ProtectedIdentity(){
        System.debug('*** BCI_Test getSwedishPerson_ProtectedIdentity() starting ***');

        Account emptyAcc = new Account();
        String ssn = '192606246697';
        String country = 'Sweden';

        Blob SE_NationalRegistrationAddress_ResponseBody = Blob.valueOf('{"persons":[{"person":{"gedi":"MC0D5C7D8254","legalId":{"socialSecurityNumber":"192606246697"},"protectedIdentity":true,"firstNames":["Åsa"],' +  
                                                                        '"preferredFirstName":"Åsa","familyName":"Åman","gender":"Female","dateOfBirth":"1926-06-24","yearOfBirth":1926,"directMarketingRestriction":false,' + 
                                                                        '"phoneList":[{"type":"Other","number":"+4608524865"}],"addressList":[{"type":"Postal","subType":"Domicile","streetName":"Lilla Bommens Torg",' + 
                                                                        '"streetNumber":"90","postalCode":"34255","city":"Växjö","country":"SE","fullAddressString":"Lilla Bommens Torg 90","formattedAddress":["Lilla Bommens Torg 90", ' + 
                                                                        '"34255 Växjö"]}],"relationshipList":[],"enrichment":{"purchasingPower":"High","phaseOfLife":"Established No Children","housingType":"Single Dwelling Building", ' + 
                                                                        '"education":"Academic","housingOwnership":"Owned"},"deregistered":false},"sourceList":[],"subscriptionState":{"subscribed":false},"memento":"eyJrZXkiOiJNQzBENUM3RDgyNTQiLCJ0eXBlIjoiZ2VkaSJ9"}]}');

        Map<String, HttpResponse> mockResponseMap = new Map<String, HttpResponse>();
        HttpResponse NRA_Response = new HttpResponse();
        NRA_Response.setStatusCode(200);
        NRA_Response.setBodyAsBlob(SE_NationalRegistrationAddress_ResponseBody);

        Map<String, HttpResponse> responseByBodyContent = new Map<String, HttpResponse>{
            'callout:BisnodeBCI_Prod/person/search' + '?' + 'sourceCountry=' + 'SE' + '&' + 'legalId=' + ssn => NRA_Response,
            'callout:BisnodeBCI_Test/person/search' + '?' + 'sourceCountry=' + 'SE' + '&' + 'legalId=' + ssn => NRA_Response
        };

        EchoHttpMock.setTestMockResponse(404, 'Not Authorized', null, responseByBodyContent);

        BCI_HandlerInvocable.Request request = new BCI_HandlerInvocable.Request();
        request.account = emptyAcc;
        request.SSN = ssn;
        request.country = country;

        List<BCI_HandlerInvocable.Request> inputList = new List<BCI_HandlerInvocable.Request>();
        inputList.add(request);

        Test.StartTest();
        List<BCI_HandlerInvocable.Result> resultList = BCI_HandlerInvocable.populateInformation(inputList);
        Test.stopTest(); 

        BCI_HandlerInvocable.Result result = resultList[0];
        Account account = result.account;
        system.assert(result.message == 'Person has protected identity - no information can be retrieved');
        system.assert(result.account.ProtectedIdentity__c == true);
        system.assert(account.FirstName == null);
        system.assert(account.LastName == null);
        system.assert(account.PersonMailingStreet == null);
        system.assert(account.PersonMailingCity == null);
        system.assert(account.PersonMailingPostalCode == null);
        system.assert(account.PersonMailingCountry == null);
    }

    @isTest
    static void getSwedishPerson_Deceased(){
        System.debug('*** BCI_Test getSwedishPerson_Deceased() starting ***');

        Account emptyAcc = new Account();
        String ssn = '192606246697';
        String country = 'Sweden';

        Blob SE_NationalRegistrationAddress_ResponseBody = Blob.valueOf('{"persons":[{"person":{"gedi":"MC0D5C7D8254","legalId":{"socialSecurityNumber":"192606246697"},"protectedIdentity":false,"firstNames":["Åsa"],' +  
                                                                        '"preferredFirstName":"Åsa","familyName":"Åman","gender":"Female","dateOfBirth":"1926-06-24","yearOfBirth":1926,"directMarketingRestriction":false,' + 
                                                                        '"phoneList":[{"type":"Other","number":"+4608524865"}],"addressList":[{"type":"Postal","subType":"Domicile","streetName":"Lilla Bommens Torg",' + 
                                                                        '"streetNumber":"90","postalCode":"34255","city":"Växjö","country":"SE","fullAddressString":"Lilla Bommens Torg 90","formattedAddress":["Lilla Bommens Torg 90", ' + 
                                                                        '"34255 Växjö"]}],"relationshipList":[],"enrichment":{"purchasingPower":"High","phaseOfLife":"Established No Children","housingType":"Single Dwelling Building", ' + 
                                                                        '"education":"Academic","housingOwnership":"Owned"},"deceased":true,"deregistered":false},"sourceList":[],"subscriptionState":{"subscribed":false},"memento":"eyJrZXkiOiJNQzBENUM3RDgyNTQiLCJ0eXBlIjoiZ2VkaSJ9"}]}');

        Map<String, HttpResponse> mockResponseMap = new Map<String, HttpResponse>();
        HttpResponse NRA_Response = new HttpResponse();
        NRA_Response.setStatusCode(200);
        NRA_Response.setBodyAsBlob(SE_NationalRegistrationAddress_ResponseBody);

        Map<String, HttpResponse> responseByBodyContent = new Map<String, HttpResponse>{
            'callout:BisnodeBCI_Prod/person/search' + '?' + 'sourceCountry=' + 'SE' + '&' + 'legalId=' + ssn => NRA_Response,
            'callout:BisnodeBCI_Test/person/search' + '?' + 'sourceCountry=' + 'SE' + '&' + 'legalId=' + ssn => NRA_Response 
        };

        EchoHttpMock.setTestMockResponse(404, 'Not Authorized', null, responseByBodyContent);

        BCI_HandlerInvocable.Request request = new BCI_HandlerInvocable.Request();
        request.account = emptyAcc;
        request.SSN = ssn;
        request.country = country;

        List<BCI_HandlerInvocable.Request> inputList = new List<BCI_HandlerInvocable.Request>();
        inputList.add(request);

        Test.StartTest();
        List<BCI_HandlerInvocable.Result> resultList = BCI_HandlerInvocable.populateInformation(inputList);
        Test.stopTest(); 

        BCI_HandlerInvocable.Result result = resultList[0];
        Account account = result.account;
        system.assert(result.message == 'Person is registered as deceased');
        system.assert(result.account.Deceased__c == true);
        system.assert(account.FirstName == null);
        system.assert(account.LastName == null);
        system.assert(account.PersonMailingStreet == null);
        system.assert(account.PersonMailingCity == null);
        system.assert(account.PersonMailingPostalCode == null);
        system.assert(account.PersonMailingCountry == null);
    }

    @isTest
    static void getSwedishPerson_Deregistered(){
        System.debug('*** BCI_Test getSwedishPerson_Deregistered() starting ***');

        Account emptyAcc = new Account();
        String ssn = '192606246697';
        String country = 'Sweden';

        Blob SE_NationalRegistrationAddress_ResponseBody = Blob.valueOf('{"persons":[{"person":{"gedi":"MC0D5C7D8254","legalId":{"socialSecurityNumber":"192606246697"},"protectedIdentity":false,"firstNames":["Åsa"],' +  
                                                                        '"preferredFirstName":"Åsa","familyName":"Åman","gender":"Female","dateOfBirth":"1926-06-24","yearOfBirth":1926,"directMarketingRestriction":false,' + 
                                                                        '"phoneList":[{"type":"Other","number":"+4608524865"}],"addressList":[{"type":"Postal","subType":"Domicile","streetName":"Lilla Bommens Torg",' + 
                                                                        '"streetNumber":"90","postalCode":"34255","city":"Växjö","country":"SE","fullAddressString":"Lilla Bommens Torg 90","formattedAddress":["Lilla Bommens Torg 90", ' + 
                                                                        '"34255 Växjö"]}],"relationshipList":[],"enrichment":{"purchasingPower":"High","phaseOfLife":"Established No Children","housingType":"Single Dwelling Building", ' + 
                                                                        '"education":"Academic","housingOwnership":"Owned"},"deceased":false,"deregistered":true},"sourceList":[],"subscriptionState":{"subscribed":false},"memento":"eyJrZXkiOiJNQzBENUM3RDgyNTQiLCJ0eXBlIjoiZ2VkaSJ9"}]}');

        Map<String, HttpResponse> mockResponseMap = new Map<String, HttpResponse>();
        HttpResponse NRA_Response = new HttpResponse();
        NRA_Response.setStatusCode(200);
        NRA_Response.setBodyAsBlob(SE_NationalRegistrationAddress_ResponseBody);

        Map<String, HttpResponse> responseByBodyContent = new Map<String, HttpResponse>{
            'callout:BisnodeBCI_Prod/person/search' + '?' + 'sourceCountry=' + 'SE' + '&' + 'legalId=' + ssn => NRA_Response,
            'callout:BisnodeBCI_Test/person/search' + '?' + 'sourceCountry=' + 'SE' + '&' + 'legalId=' + ssn => NRA_Response 
        };

        EchoHttpMock.setTestMockResponse(404, 'Not Authorized', null, responseByBodyContent);

        BCI_HandlerInvocable.Request request = new BCI_HandlerInvocable.Request();
        request.account = emptyAcc;
        request.SSN = ssn;
        request.country = country;

        List<BCI_HandlerInvocable.Request> inputList = new List<BCI_HandlerInvocable.Request>();
        inputList.add(request);

        Test.StartTest();
        List<BCI_HandlerInvocable.Result> resultList = BCI_HandlerInvocable.populateInformation(inputList);
        Test.stopTest(); 

        BCI_HandlerInvocable.Result result = resultList[0];
        Account account = result.account;
        system.assert(result.message == 'Person is deregistred');
        system.assert(account.FirstName == null);
        system.assert(account.LastName == null);
        system.assert(account.PersonMailingStreet == null);
        system.assert(account.PersonMailingCity == null);
        system.assert(account.PersonMailingPostalCode == null);
        system.assert(account.PersonMailingCountry == null);
    }

    @isTest
    static void getSwedishPerson_NoResponse(){
        System.debug('*** BCI_Test getSwedishPerson_NoResponse() starting ***');

        Account emptyAcc = new Account();
        String ssn = '192606246697';
        String country = 'Sweden';
        Blob SE_NationalRegistrationAddress_ResponseBody = Blob.valueOf('{"persons":[{"person":{"gedi":"MC0D5C7D8254","legalId":{"socialSecurityNumber":"192606246697"},"protectedIdentity":false,"firstNames":["Åsa"],' +  
                                                                        '"preferredFirstName":"Åsa","familyName":"Åman","gender":"Female","dateOfBirth":"1926-06-24","yearOfBirth":1926,"directMarketingRestriction":false,' + 
                                                                        '"phoneList":[{"type":"Other","number":"+4608524865"}],"addressList":[{"type":"Visiting","subType":"Domicile","streetName":"Lilla Bommens Torg",' + 
                                                                        '"streetNumber":"90","postalCode":"34255","city":"Växjö","country":"SE","fullAddressString":"Lilla Bommens Torg 90","formattedAddress":["Lilla Bommens Torg 90", ' + 
                                                                        '"34255 Växjö"]}],"relationshipList":[],"enrichment":{"purchasingPower":"High","phaseOfLife":"Established No Children","housingType":"Single Dwelling Building", ' + 
                                                                        '"education":"Academic","housingOwnership":"Owned"},"deceased":false,"deregistered":false},"sourceList":[],"subscriptionState":{"subscribed":false},"memento":"eyJrZXkiOiJNQzBENUM3RDgyNTQiLCJ0eXBlIjoiZ2VkaSJ9"}]}');

        Map<String, HttpResponse> mockResponseMap = new Map<String, HttpResponse>();
        HttpResponse NRA_Response = new HttpResponse();
        NRA_Response.setStatusCode(400);
        NRA_Response.setBodyAsBlob(SE_NationalRegistrationAddress_ResponseBody);

        Map<String, HttpResponse> responseByBodyContent = new Map<String, HttpResponse>{
            'callout:BisnodeBCI_Prod/person/search' + '?' + 'sourceCountry=' + 'SE' + '&' + 'legalId=' + ssn => NRA_Response,
            'callout:BisnodeBCI_Test/person/search' + '?' + 'sourceCountry=' + 'SE' + '&' + 'legalId=' + ssn => NRA_Response
        };

        EchoHttpMock.setTestMockResponse(404, 'Not Authorized', null, responseByBodyContent);

        BCI_HandlerInvocable.Request request = new BCI_HandlerInvocable.Request();
        request.account = emptyAcc;
        request.SSN = ssn;
        request.country = country;

        List<BCI_HandlerInvocable.Request> inputList = new List<BCI_HandlerInvocable.Request>();
        inputList.add(request);

        Test.StartTest();
        List<BCI_HandlerInvocable.Result> resultList = BCI_HandlerInvocable.populateInformation(inputList);
        Test.stopTest(); 

        BCI_HandlerInvocable.Result result = resultList[0];
        Account account = result.account;
        if (result.message.contains('BCI Error Message:')) {
            system.assert(true);
        } else {
            system.assert(false);
        }
        system.assert(account.FirstName == null);
        system.assert(account.LastName == null);
        system.assert(account.PersonMailingStreet == null);
        system.assert(account.PersonMailingCity == null);
        system.assert(account.PersonMailingPostalCode == null);
        system.assert(account.PersonMailingCountry == null);
    }

    @isTest
    static void getSwedishPerson_StatusCode400(){
        System.debug('*** BCI_Test getSwedishPerson_StatusCode400() starting ***');

        Account emptyAcc = new Account();
        String ssn = '192606246697';
        String country = 'Sweden';

        Blob SE_NationalRegistrationAddress_ResponseBody = Blob.valueOf('{"persons":[{"person":{"gedi":"MC0D5C7D8254","legalId":{"socialSecurityNumber":"192606246697"},"protectedIdentity":false,"firstNames":["Åsa"],' +  
                                                                        '"preferredFirstName":"Åsa","familyName":"Åman","gender":"Female","dateOfBirth":"1926-06-24","yearOfBirth":1926,"directMarketingRestriction":false,' + 
                                                                        '"phoneList":[{"type":"Other","number":"+4608524865"}],"addressList":[{"type":"Visiting","subType":"Domicile","streetName":"Lilla Bommens Torg",' + 
                                                                        '"streetNumber":"90","postalCode":"34255","city":"Växjö","country":"SE","fullAddressString":"Lilla Bommens Torg 90","formattedAddress":["Lilla Bommens Torg 90", ' + 
                                                                        '"34255 Växjö"]}],"relationshipList":[],"enrichment":{"purchasingPower":"High","phaseOfLife":"Established No Children","housingType":"Single Dwelling Building", ' + 
                                                                        '"education":"Academic","housingOwnership":"Owned"},"deceased":false,"deregistered":false},"sourceList":[],"subscriptionState":{"subscribed":false},"memento":"eyJrZXkiOiJNQzBENUM3RDgyNTQiLCJ0eXBlIjoiZ2VkaSJ9"}]}');

        Map<String, HttpResponse> mockResponseMap = new Map<String, HttpResponse>();
        HttpResponse NRA_Response = new HttpResponse();
        NRA_Response.setStatusCode(400);
        NRA_Response.setBodyAsBlob(SE_NationalRegistrationAddress_ResponseBody);

        Map<String, HttpResponse> responseByBodyContent = new Map<String, HttpResponse>{
            'callout:BisnodeBCI_Prod/person/search' + '?' + 'sourceCountry=' + 'SE' + '&' + 'legalId=' + ssn => NRA_Response,
            'callout:BisnodeBCI_Test/person/search' + '?' + 'sourceCountry=' + 'SE' + '&' + 'legalId=' + ssn => NRA_Response   
        };

        EchoHttpMock.setTestMockResponse(404, 'Not Authorized', null, responseByBodyContent);

        BCI_HandlerInvocable.Request request = new BCI_HandlerInvocable.Request();
        request.account = emptyAcc;
        request.SSN = ssn;
        request.country = country;

        List<BCI_HandlerInvocable.Request> inputList = new List<BCI_HandlerInvocable.Request>();
        inputList.add(request);

        Test.StartTest();
        List<BCI_HandlerInvocable.Result> resultList = BCI_HandlerInvocable.populateInformation(inputList);
        Test.stopTest(); 

        BCI_HandlerInvocable.Result result = resultList[0];
        Account account = result.account;
        if (result.message.contains('BCI Error Message:')) {
            system.assert(true);
        } else {
            system.assert(false);
        }
        system.assert(account.FirstName == null);
        system.assert(account.LastName == null);
        system.assert(account.PersonMailingStreet == null);
        system.assert(account.PersonMailingCity == null);
        system.assert(account.PersonMailingPostalCode == null);
        system.assert(account.PersonMailingCountry == null);
    }

    @isTest
    static void getSwedishPerson_NoHit(){
        System.debug('*** BCI_Test getSwedishPerson_NoHit() starting ***');

        Account emptyAcc = new Account();
        String ssn = '192606246697';
        String country = 'Sweden';

        Blob SE_NationalRegistrationAddress_ResponseBody = Blob.valueOf('{"persons":[]}');

        Map<String, HttpResponse> mockResponseMap = new Map<String, HttpResponse>();

        HttpResponse NRA_Response = new HttpResponse();
        NRA_Response.setStatusCode(200);
        NRA_Response.setBodyAsBlob(SE_NationalRegistrationAddress_ResponseBody);

        Map<String, HttpResponse> responseByBodyContent = new Map<String, HttpResponse>{
            'callout:BisnodeBCI_Prod/person/search' + '?' + 'sourceCountry=' + 'SE' + '&' + 'legalId=' + ssn => NRA_Response,
            'callout:BisnodeBCI_Test/person/search' + '?' + 'sourceCountry=' + 'SE' + '&' + 'legalId=' + ssn => NRA_Response 
        };

        EchoHttpMock.setTestMockResponse(404, 'Not Authorized', null, responseByBodyContent);

        BCI_HandlerInvocable.Request request = new BCI_HandlerInvocable.Request();
        request.account = emptyAcc;
        request.SSN = ssn;
        request.country = country;

        List<BCI_HandlerInvocable.Request> inputList = new List<BCI_HandlerInvocable.Request>();
        inputList.add(request);

        Test.StartTest();
        List<BCI_HandlerInvocable.Result> resultList = BCI_HandlerInvocable.populateInformation(inputList);
        Test.stopTest(); 

        BCI_HandlerInvocable.Result result = resultList[0];
        Account account = result.account;
        if (result.message.contains('Person not found for')) {
            system.assert(true);
        } else {
            system.assert(false);
        }
        system.assert(account.FirstName == null);
        system.assert(account.LastName == null);
        system.assert(account.PersonMailingStreet == null);
        system.assert(account.PersonMailingCity == null);
        system.assert(account.PersonMailingPostalCode == null);
        system.assert(account.PersonMailingCountry == null);
    }

}