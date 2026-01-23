@isTest
private class WorksiteBasunBatchableTest {
  
  private static Map<String, HttpResponse> addMockTokenResponse(Map<String, HttpResponse> mockResponseMap){
    HttpResponse mockResponse = MockHttpResponseGenerator.getTokenResponse();
    mockResponseMap.put('callout:BisnodeLoginTest', mockResponse);
    return mockResponseMap;
  }

  private static Map<String, HttpResponse> addMockSubscribeWorksiteResponse(Map<String, HttpResponse> mockResponseMap){
    HttpResponse mockResponse = MockHttpResponseGenerator.subscribeWorksiteResponse();
    mockResponseMap.put('callout:BisnodeBBC/worksites/changes', mockResponse);
    return mockResponseMap;
  }

  private static Map<String, HttpResponse> addMockSubscribeRemovedWorksiteResponse(Map<String, HttpResponse> mockResponseMap){
    HttpResponse mockResponse = MockHttpResponseGenerator.subscribeWorksiteRemovedResponse();
    mockResponseMap.put('callout:BisnodeBBC/worksites/changes', mockResponse);
    return mockResponseMap;
  }
  
  @testSetup
  static void setup() {
    System.debug('*** WorksiteBasunBatchableTest Setup() starting ***');

    TestDataFactorySetupParams setupParams = new TestDataFactorySetupParams();
    setupParams.numberOfWorkplaceAccounts = 100;
    TestDataFactory.setupTestData(setupParams);
  }

  @isTest
  static void testUpdateWorksite() {

    Map<String, HttpResponse> responseByBodyContent = new Map<String, HttpResponse>();
    responseByBodyContent = addMockTokenResponse(responseByBodyContent);
    responseByBodyContent = addMockSubscribeWorksiteResponse(responseByBodyContent);
    EchoHttpMock.setTestMockResponse(404, 'Not Authorized', null, responseByBodyContent);
    
    Test.startTest();
    WorksiteBasunBatchable c = new WorksiteBasunBatchable();
    Database.executeBatch(c);
    Test.stopTest();
  }

  @isTest
  static void testRemovedWorksite() {
    Map<String, HttpResponse> responseByBodyContent = new Map<String, HttpResponse>();
    responseByBodyContent = addMockSubscribeWorksiteResponse(responseByBodyContent);
    responseByBodyContent = addMockSubscribeRemovedWorksiteResponse(responseByBodyContent);
    EchoHttpMock.setTestMockResponse(404, 'Not Authorized', null, responseByBodyContent);
    Test.startTest();
    WorksiteBasunBatchable c = new WorksiteBasunBatchable();
    Database.executeBatch(c);
    Test.stopTest();
  }

  //Lets test the small methods as well.
}