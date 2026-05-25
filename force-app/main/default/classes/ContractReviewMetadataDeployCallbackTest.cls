@IsTest
private class ContractReviewMetadataDeployCallbackTest {
  @IsTest
  static void buildEvent_succeeded_statusIsSuccess() {
    ContractReviewMetadataDeployResult__e evt = ContractReviewMetadataDeployCallback.buildEvent(
      '0Af000000000001AAA',
      true,
      new List<String>()
    );

    System.assertEquals('0Af000000000001AAA', evt.JobId__c);
    System.assertEquals('Success', evt.Status__c);
    System.assertEquals(
      '',
      evt.ErrorMessage__c,
      'No error message expected on success'
    );
  }

  @IsTest
  static void buildEvent_failedWithProblems_statusIsFailedAndMessageJoined() {
    List<String> problems = new List<String>{
      'Component X failed',
      'Component Y failed'
    };

    ContractReviewMetadataDeployResult__e evt = ContractReviewMetadataDeployCallback.buildEvent(
      '0Af000000000002BBB',
      false,
      problems
    );

    System.assertEquals('Failed', evt.Status__c);
    System.assertEquals(
      'Component X failed; Component Y failed',
      evt.ErrorMessage__c
    );
  }

  @IsTest
  static void buildEvent_failedNullProblems_emptyErrorMessage() {
    ContractReviewMetadataDeployResult__e evt = ContractReviewMetadataDeployCallback.buildEvent(
      '0Af000000000003CCC',
      false,
      null
    );

    System.assertEquals('Failed', evt.Status__c);
    System.assertEquals('', evt.ErrorMessage__c);
  }

  @IsTest
  static void buildEvent_failedEmptyProblems_emptyErrorMessage() {
    ContractReviewMetadataDeployResult__e evt = ContractReviewMetadataDeployCallback.buildEvent(
      '0Af000000000004DDD',
      false,
      new List<String>()
    );

    System.assertEquals('Failed', evt.Status__c);
    System.assertEquals('', evt.ErrorMessage__c);
  }

  @IsTest
  static void buildEvent_succeededWithProblems_ignoresProblems() {
    List<String> problems = new List<String>{ 'Should be ignored' };

    ContractReviewMetadataDeployResult__e evt = ContractReviewMetadataDeployCallback.buildEvent(
      '0Af000000000005EEE',
      true,
      problems
    );

    System.assertEquals('Success', evt.Status__c);
    System.assertEquals(
      '',
      evt.ErrorMessage__c,
      'Problems should be ignored when succeeded is true'
    );
  }

  @IsTest
  static void handleResult_succeededDeploy_publishesSuccessEvent() {
    Metadata.DeployResult result = new Metadata.DeployResult();
    result.id = '0Af000000000006FFF';
    result.status = Metadata.DeployStatus.Succeeded;

    Metadata.DeployCallbackContext context = null;

    Test.startTest();
    ContractReviewMetadataDeployCallback callback = new ContractReviewMetadataDeployCallback();
    // context can be null — handleResult only uses result.id and result.status
    // The EventBus.publish call is a fire-and-forget; we just verify no exception
    callback.handleResult(result, context);
    Test.stopTest();
  }

  @IsTest
  static void handleResult_failedDeploy_publishesFailedEvent() {
    Metadata.DeployResult result = new Metadata.DeployResult();
    result.id = '0Af000000000007GGG';
    result.status = Metadata.DeployStatus.Failed;

    Test.startTest();
    ContractReviewMetadataDeployCallback callback = new ContractReviewMetadataDeployCallback();
    callback.handleResult(result, null);
    Test.stopTest();
  }
}