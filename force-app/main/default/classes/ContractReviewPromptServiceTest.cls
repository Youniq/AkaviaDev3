@IsTest
private class ContractReviewPromptServiceTest {

  private class MockInvoker extends ContractReviewPromptService.TemplateInvoker {
    public String capturedTemplateName;
    public ConnectApi.EinsteinPromptTemplateGenerationsInput capturedInput;
    public String mockResponse;
    public Boolean shouldThrow;

    MockInvoker(String mockResponse, Boolean shouldThrow) {
      this.mockResponse = mockResponse;
      this.shouldThrow = shouldThrow;
    }

    public override String invoke(
      String templateApiName,
      ConnectApi.EinsteinPromptTemplateGenerationsInput genInput
    ) {
      this.capturedTemplateName = templateApiName;
      this.capturedInput = genInput;
      if (this.shouldThrow) {
        throw new CalloutException('Simulated prompt failure');
      }
      return this.mockResponse;
    }
  }

  private static MockInvoker installMock(String response, Boolean shouldThrow) {
    MockInvoker mock = new MockInvoker(response, shouldThrow);
    ContractReviewPromptService.invoker = mock;
    return mock;
  }

  @IsTest
  static void generateContractReview_passesCorrectTemplateName() {
    MockInvoker mock = installMock('{"result":"ok"}', false);
    Id fakeRevId = '0AfUB00000000000AA';
    Id fakeDocId = '069000000000001AAA';

    Test.startTest();
    String result = ContractReviewPromptService.generateContractReview(
      fakeRevId, fakeDocId
    );
    Test.stopTest();

    System.assertEquals('ContractReviewPromptTemplate', mock.capturedTemplateName,
      'Should call the contract review template');
    System.assertEquals('{"result":"ok"}', result,
      'Should return the mock response');

    // Verify inputParams keys and values
    Map<String, ConnectApi.WrappedValue> params = mock.capturedInput.inputParams;
    System.assert(params.containsKey('Input:Document'),
      'Should contain Input:Document key');
    System.assert(params.containsKey('Input:ContractReview'),
      'Should contain Input:ContractReview key');
    Map<String, String> docMap = (Map<String, String>) params.get('Input:Document').value;
    System.assertEquals(String.valueOf(fakeDocId), docMap.get('id'),
      'Document id should match');
    Map<String, String> revMap = (Map<String, String>) params.get('Input:ContractReview').value;
    System.assertEquals(String.valueOf(fakeRevId), revMap.get('id'),
      'ContractReview id should match');
    System.assertEquals(false, mock.capturedInput.isPreview,
      'isPreview should be false');
    System.assertEquals('PromptTemplateGenerationsInvocable',
      mock.capturedInput.additionalConfig.applicationName,
      'applicationName should match');
  }

  @IsTest
  static void generateEmailDraft_passesCorrectTemplateName() {
    MockInvoker mock = installMock('<p>Draft email</p>', false);
    Id fakeCaseId = '500000000000001AAA';

    Test.startTest();
    String result = ContractReviewPromptService.generateEmailDraft(
      fakeCaseId, 'Output text', 'Svenska'
    );
    Test.stopTest();

    System.assertEquals('Contract_Review_Email_Draft', mock.capturedTemplateName,
      'Should call the email draft template');
    System.assertEquals('<p>Draft email</p>', result,
      'Should return the mock response');

    // Verify inputParams keys and values
    Map<String, ConnectApi.WrappedValue> params = mock.capturedInput.inputParams;
    System.assert(params.containsKey('Input:Case'),
      'Should contain Input:Case key');
    System.assert(params.containsKey('Input:Contract_Review_Output_Text'),
      'Should contain Input:Contract_Review_Output_Text key');
    System.assert(params.containsKey('Input:Language'),
      'Should contain Input:Language key');
    Map<String, String> caseMap = (Map<String, String>) params.get('Input:Case').value;
    System.assertEquals(String.valueOf(fakeCaseId), caseMap.get('id'),
      'Case id should match');
    System.assertEquals('Output text', (String) params.get('Input:Contract_Review_Output_Text').value,
      'Output text should match');
    System.assertEquals('Svenska', (String) params.get('Input:Language').value,
      'Language should match');
    System.assertEquals(false, mock.capturedInput.isPreview,
      'isPreview should be false');
    System.assertEquals('PromptTemplateGenerationsInvocable',
      mock.capturedInput.additionalConfig.applicationName,
      'applicationName should match');
  }

  @IsTest
  static void generateEmailDraft_propagatesException() {
    installMock(null, true);
    Id fakeCaseId = '500000000000001AAA';

    try {
      ContractReviewPromptService.generateEmailDraft(
        fakeCaseId, 'Output text', 'Svenska'
      );
      System.assert(false, 'Expected CalloutException');
    } catch (CalloutException e) {
      System.assert(
        e.getMessage().contains('Simulated prompt failure'),
        'Should propagate the exception message: ' + e.getMessage()
      );
    }
  }

  @IsTest
  static void generateFormContractReview_passesCorrectTemplateAndInputs() {
    MockInvoker mock = installMock('{"result":"form-ok"}', false);
    Id fakeRevId = '0AfUB00000000000AA';
    Id fakeDocId = '069000000000001AAA';

    Test.startTest();
    String result = ContractReviewPromptService.generateFormContractReview(
      fakeRevId, fakeDocId
    );
    Test.stopTest();

    System.assertEquals('ContractReview_Forms', mock.capturedTemplateName,
      'Should call the forms review template');
    System.assertEquals('{"result":"form-ok"}', result,
      'Should return the mock response');

    Map<String, ConnectApi.WrappedValue> params = mock.capturedInput.inputParams;
    System.assert(params.containsKey('Input:File'),
      'Should contain Input:File key');
    System.assert(params.containsKey('Input:ContractReview'),
      'Should contain Input:ContractReview key');
    Map<String, String> docMap = (Map<String, String>) params.get('Input:File').value;
    System.assertEquals(String.valueOf(fakeDocId), docMap.get('id'),
      'Document id should match');
    Map<String, String> revMap = (Map<String, String>) params.get('Input:ContractReview').value;
    System.assertEquals(String.valueOf(fakeRevId), revMap.get('id'),
      'ContractReview id should match');
  }

  @IsTest
  static void classifyContractType_returnsTrue() {
    installMock('true', false);
    Id fakeDocId = '069000000000001AAA';

    Test.startTest();
    Boolean result = ContractReviewPromptService.classifyContractType(fakeDocId);
    Test.stopTest();

    System.assertEquals(true, result, 'Should return true for "true" response');
  }

  @IsTest
  static void classifyContractType_returnsTrueForPaddedResponse() {
    installMock(' true\n', false);
    Id fakeDocId = '069000000000001AAA';

    Test.startTest();
    Boolean result = ContractReviewPromptService.classifyContractType(fakeDocId);
    Test.stopTest();

    System.assertEquals(true, result,
      'Should return true for whitespace-padded "true" response');
  }

  @IsTest
  static void classifyContractType_returnsFalse() {
    installMock('false', false);
    Id fakeDocId = '069000000000001AAA';

    Test.startTest();
    Boolean result = ContractReviewPromptService.classifyContractType(fakeDocId);
    Test.stopTest();

    System.assertEquals(false, result, 'Should return false for "false" response');
  }

  @IsTest
  static void classifyContractType_returnsFalseForMultiWordResponse() {
    installMock('true, this appears to be a form', false);
    Id fakeDocId = '069000000000001AAA';

    Test.startTest();
    Boolean result = ContractReviewPromptService.classifyContractType(fakeDocId);
    Test.stopTest();

    System.assertEquals(false, result,
      'Should return false for multi-word response even if it contains "true"');
  }

  @IsTest
  static void classifyContractType_returnsFalseForBlankResponse() {
    installMock('', false);
    Id fakeDocId = '069000000000001AAA';

    Test.startTest();
    Boolean result = ContractReviewPromptService.classifyContractType(fakeDocId);
    Test.stopTest();

    System.assertEquals(false, result,
      'Should return false for blank response');
  }

  @IsTest
  static void classifyContractType_propagatesException() {
    installMock(null, true);
    Id fakeDocId = '069000000000001AAA';

    try {
      ContractReviewPromptService.classifyContractType(fakeDocId);
      System.assert(false, 'Expected CalloutException');
    } catch (CalloutException e) {
      System.assert(
        e.getMessage().contains('Simulated prompt failure'),
        'Should propagate the exception message: ' + e.getMessage()
      );
    }
  }

  @IsTest
  static void classifyContractType_passesCorrectInputs() {
    MockInvoker mock = installMock('false', false);
    Id fakeDocId = '069000000000001AAA';

    Test.startTest();
    ContractReviewPromptService.classifyContractType(fakeDocId);
    Test.stopTest();

    System.assertEquals('Contract_Review_Contract_Type', mock.capturedTemplateName,
      'Should call the contract type template');
    Map<String, ConnectApi.WrappedValue> params = mock.capturedInput.inputParams;
    System.assertEquals(1, params.size(),
      'Should have exactly one input parameter');
    System.assert(params.containsKey('Input:File'),
      'Should contain Input:File key');
    Map<String, String> docMap = (Map<String, String>) params.get('Input:File').value;
    System.assertEquals(String.valueOf(fakeDocId), docMap.get('id'),
      'Document id should match');
  }
}