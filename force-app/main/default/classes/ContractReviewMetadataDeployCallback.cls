/**
 * Receives the result of an asynchronous Metadata API deployment enqueued by
 * {@link ContractReviewMetadataService#deployBundledRecords} and republishes
 * it as the {@code ContractReviewMetadataDeployResult__e} platform event so
 * the admin LWC can react in real time without polling.
 *
 * Sharing: {@code without sharing} — callbacks run in a system context.
 *
 * Governor-limit notes:
 *   - 1 platform-event publish per call.
 *   - Exceptions are logged and swallowed; throwing from a callback can
 *     mask deployment results from the platform.
 */
public without sharing class ContractReviewMetadataDeployCallback implements Metadata.DeployCallback {
  /**
   * Implements {@code Metadata.DeployCallback}. Aggregates component
   * failure messages on failure and publishes a single result event.
   *
   * @param result  Outcome of the metadata deployment.
   * @param context Callback context (not used — see inline comment about
   *                why we prefer {@code result.id}).
   */
  public void handleResult(
    Metadata.DeployResult result,
    Metadata.DeployCallbackContext context
  ) {
    try {
      // Use result.id (DeployRequest Id, prefix 0Af) — matches what enqueueDeployment() returns.
      // context.getCallbackJobId() returns the AsyncApexJob Id (prefix 707), which is different.
      String jobId = String.valueOf(result.id);

      Boolean succeeded = (result.status == Metadata.DeployStatus.Succeeded);

      List<String> problems = new List<String>();
      if (
        !succeeded &&
        result.details != null &&
        result.details.componentFailures != null
      ) {
        for (
          Metadata.DeployMessage failure : result.details.componentFailures
        ) {
          if (String.isNotBlank(failure.problem)) {
            problems.add(failure.problem);
          }
        }
      }

      ContractReviewMetadataDeployResult__e evt = buildEvent(
        jobId,
        succeeded,
        problems
      );
      EventBus.publish(evt);
    } catch (Exception e) {
      System.debug(
        LoggingLevel.ERROR,
        'ContractReviewMetadataDeployCallback error: ' + e.getMessage()
      );
    }
  }

  /**
   * Builds the platform-event payload. Joins all component failure
   * problems with {@code '; '} so the admin LWC can surface them in a
   * single toast.
   */
  @TestVisible
  private static ContractReviewMetadataDeployResult__e buildEvent(
    String jobId,
    Boolean succeeded,
    List<String> problems
  ) {
    String errorMessage = '';
    if (!succeeded && problems != null && !problems.isEmpty()) {
      errorMessage = String.join(problems, '; ');
    }

    return new ContractReviewMetadataDeployResult__e(
      JobId__c = jobId,
      Status__c = succeeded ? 'Success' : 'Failed',
      ErrorMessage__c = errorMessage
    );
  }
}