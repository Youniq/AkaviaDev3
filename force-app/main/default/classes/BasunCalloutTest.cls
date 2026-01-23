@isTest
private class BasunCalloutTest {
  @isTest
  static void testGetAccessToken() {
    Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator('token'));
    String res = BasunCallout.getAccessToken();
    System.assertEquals('8UT28QKGTiAhjNk5yJj', res);
  }

  private static Map<String, HttpResponse> addMockTokenResponse(Map<String, HttpResponse> mockResponseMap){
    HttpResponse mockResponse = MockHttpResponseGenerator.getTokenResponse();
    mockResponseMap.put('callout:BisnodeLoginTest', mockResponse);
    return mockResponseMap;
  }

  @isTest
  static void testGetCompanies() {

    Map<String, HttpResponse> responseByBodyContent = new Map<String, HttpResponse>();
    responseByBodyContent = addMockTokenResponse(responseByBodyContent);
    HttpResponse defaultResponse = MockHttpResponseGenerator.getCompnaniesResponse();
    
    test.setMock(
                HttpCalloutMock.class,
                new EchoHttpMock(defaultResponse, responseByBodyContent)
        );

    test.startTest();
      CompanySearchResponse res = BasunCallout.getCompanies(
        '123',
        'Stockholm',
        'Customer',
        'Ryavägen',
        'ST00',
        'TY10'
      );
    test.stopTest();
    System.assertEquals(10, res.hitsReturned);
  }

  @isTest
  static void testGetCompaniesByLink() {
    Map<String, HttpResponse> responseByBodyContent = new Map<String, HttpResponse>();
    responseByBodyContent = addMockTokenResponse(responseByBodyContent);
    HttpResponse defaultResponse = MockHttpResponseGenerator.getCompnaniesResponse();
    
    test.setMock(
                HttpCalloutMock.class,
                new EchoHttpMock(defaultResponse, responseByBodyContent)
        );
   
    Test.startTest();
      CompanySearchResponse res = BasunCallout.getCompaniesByLink('urlstring');
    Test.stopTest();
      
    System.assertEquals(10, res.hitsReturned);
  }

  @isTest
  static void testGetCompanyInfo() {

    Map<String, HttpResponse> responseByBodyContent = new Map<String, HttpResponse>();
    responseByBodyContent = addMockTokenResponse(responseByBodyContent);
    HttpResponse defaultResponse = MockHttpResponseGenerator.getCompanyInfoResponse();
    
    test.setMock(
                HttpCalloutMock.class,
                new EchoHttpMock(defaultResponse, responseByBodyContent)
        );
        
    Test.startTest();
    CompanyDetails res = BasunCallout.getCompanyInfo('12345678', 'sv');
    Test.stopTest();

    System.assertEquals('Stretch AB', res.name);
  }

  @isTest
  static void testsubscribeCompanies() {
    List<BasunCallout.CompnayChangesJSON> listParam = new List<BasunCallout.CompnayChangesJSON>();
    BasunCallout.CompnayChangesJSON ccJson = new BasunCallout.CompnayChangesJSON();
    ccJson.companyId = '123456';
    ccJson.since = '2015-02-13T12:05:16.565Z';
    listParam.add(ccJson);

    Map<String, HttpResponse> responseByBodyContent = new Map<String, HttpResponse>();
    responseByBodyContent = addMockTokenResponse(responseByBodyContent);
    HttpResponse defaultResponse = MockHttpResponseGenerator.subscribeCompanyResponse();
    
    Test.setMock(
                HttpCalloutMock.class,
                new EchoHttpMock(defaultResponse, responseByBodyContent)
        );
    Test.startTest();
    BasunCallout.subscribeCompanies(listParam, '7073O00001oGrTC'); // 7073O00001oGrTC resembles a fake jobId
    Test.stopTest();
  }

  @isTest
  static void testGetWorksites() {
    Map<String, HttpResponse> responseByBodyContent = new Map<String, HttpResponse>();
    responseByBodyContent = addMockTokenResponse(responseByBodyContent);
    HttpResponse defaultResponse = MockHttpResponseGenerator.getWorksitesResponse();
    
    Test.setMock(
                HttpCalloutMock.class,
                new EchoHttpMock(defaultResponse, responseByBodyContent)
        );
    Test.startTest();
    WorksiteSearchResponse res = BasunCallout.getWorksites(
      '123',
      '12356',
      'Customer',
      'Ryavägen',
      'Stockholm',
      'ST00',
      'TY10'
    );
    Test.stopTest();
    System.assertEquals(10, res.hitsReturned);
  }

  @isTest
  static void testGetWorksitesByLink() {
    Map<String, HttpResponse> responseByBodyContent = new Map<String, HttpResponse>();
    responseByBodyContent = addMockTokenResponse(responseByBodyContent);
    HttpResponse defaultResponse = MockHttpResponseGenerator.getWorksitesResponse();
    
    Test.setMock(
                HttpCalloutMock.class,
                new EchoHttpMock(defaultResponse, responseByBodyContent)
        );
    Test.startTest();
      WorksiteSearchResponse res = BasunCallout.getWorksitesByLink('urlstring');
    Test.stopTest();
    System.assertEquals(10, res.hitsReturned);
  }

  @isTest
  static void testGetWorksiteInfo() {
    Map<String, HttpResponse> responseByBodyContent = new Map<String, HttpResponse>();
    responseByBodyContent = addMockTokenResponse(responseByBodyContent);
    HttpResponse defaultResponse = MockHttpResponseGenerator.getWorksiteInfoResponse();
    
    Test.setMock(
                HttpCalloutMock.class,
                new EchoHttpMock(defaultResponse, responseByBodyContent)
        );

    Test.startTest();
    WorksiteDetails res = BasunCallout.getWorksiteInfo('12345678', 'sv');
    Test.stopTest();
    System.assertEquals('Stretch AB', res.name);
  }

  @isTest
  static void testsubscribeWorksites() {
    List<BasunCallout.WorksiteChangesJSON> listParam = new List<BasunCallout.WorksiteChangesJSON>();
    BasunCallout.WorksiteChangesJSON ccJson = new BasunCallout.WorksiteChangesJSON();
    ccJson.worksiteId = '123456';
    ccJson.since = '2015-02-13T12:05:16.565Z';
    listParam.add(ccJson);
    
    Map<String, HttpResponse> responseByBodyContent = new Map<String, HttpResponse>();
    responseByBodyContent = addMockTokenResponse(responseByBodyContent);
    HttpResponse defaultResponse = MockHttpResponseGenerator.subscribeWorksiteResponse();
    
    Test.setMock(
                HttpCalloutMock.class,
                new EchoHttpMock(defaultResponse, responseByBodyContent)
        );
    Test.startTest();
    BasunCallout.subscribeWorksites(listParam, '7073O00001oGrTD'); // 7073O00001oGrTD resembles a fake jobId
    Test.stopTest();
  }
}