@isTest
private class CompanyControllerTest {

  private static Map<String, HttpResponse> addMockTokenResponse(Map<String, HttpResponse> mockResponseMap){
    HttpResponse mockResponse = MockHttpResponseGenerator.getTokenResponse();
    mockResponseMap.put('callout:BisnodeLoginTest', mockResponse);
    return mockResponseMap;
  }
  
  @isTest
  static void testFetchCompany() {
    Test.setMock(
      HttpCalloutMock.class,
      new MockHttpResponseGenerator('getCompanies')
    );
    Test.startTest();
    CompanySearchResponse resp = CompanyController.fetchCompany(
      '1234',
      'Stockholm',
      'Customer',
      'Ryavägen', 
      'ST00',
      'TY10'
    );
    Test.stopTest();
  }

  @isTest
  static void testFetchCompanyByUrl() {
    Test.setMock(
      HttpCalloutMock.class,
      new MockHttpResponseGenerator('getCompanies')
    );
    Test.startTest();
    CompanySearchResponse resp = CompanyController.fetchCompanyByUrl(
      'www.fake.se'
    );
    Test.stopTest();
  }

  @isTest
  static void testDownloadCompany() {
    Test.setMock(
      HttpCalloutMock.class,
      new MockHttpResponseGenerator('getCompanyInfo')
    );
    Test.startTest();
    CompanyDetails resp = CompanyController.downloadCompany('12345', 'sv');
    Test.stopTest();
  }

  @isTest
  static void testCreateCompanyUpdate() {
    Map<String, HttpResponse> responseByBodyContent = new Map<String, HttpResponse>();
    responseByBodyContent = addMockTokenResponse(responseByBodyContent);
    HttpResponse defaultResponse = MockHttpResponseGenerator.getCompanyInfoResponse();
    
    test.setMock(
                HttpCalloutMock.class,
                new EchoHttpMock(defaultResponse, responseByBodyContent)
        );
    Test.startTest();
    CompanyDetails compInfo = CompanyController.downloadCompany('12345', 'sv');
    CompanyController.createCompanyUpdate(compInfo);
    CompanyController.upsertCompany(compInfo);
    Test.stopTest();
  }

  @isTest
  static void testFetchWorksite() {
    Test.setMock(
      HttpCalloutMock.class,
      new MockHttpResponseGenerator('getWorksites')
    );
    Test.startTest();
    WorksiteSearchResponse resp = CompanyController.fetchWorksite(
      '1234',
      '123456',
      'Customer',
      'Ryavägen',
      'Stockholm', 
      'ST00',
      'TY10'
    );
    Test.stopTest();
  }

  @isTest
  static void testFetchWorksitesByUrl() {
    Test.setMock(
      HttpCalloutMock.class,
      new MockHttpResponseGenerator('getWorksites')
    );
    Test.startTest();
    WorksiteSearchResponse resp = CompanyController.fetchWorksitesByUrl(
      'www.fake.se'
    );
    Test.stopTest();
  }

  @isTest
  static void testDownloadWorksite() {
    Test.setMock(
      HttpCalloutMock.class,
      new MockHttpResponseGenerator('getWorksiteInfo')
    );
    Test.startTest();
    WorksiteDetails resp = CompanyController.downloadWorksite('12345', 'sv');
    Test.stopTest();
  }

  @isTest
  static void testCreateWorksiteUpdate() {
    Map<String, HttpResponse> responseByBodyContent = new Map<String, HttpResponse>();
    responseByBodyContent = addMockTokenResponse(responseByBodyContent);
    HttpResponse defaultResponse = MockHttpResponseGenerator.getWorksiteInfoResponse();
    
    Test.setMock(
                HttpCalloutMock.class,
                new EchoHttpMock(defaultResponse, responseByBodyContent)
        );

    Test.startTest();
    WorksiteDetails worksiteInfo = CompanyController.downloadWorksite(
      '12345',
      'sv'
    );
    CompanyController.createWorksiteUpdate(worksiteInfo);
    CompanyController.upsertWorksite(worksiteInfo);
    Test.stopTest();
  }
}