/**
 * Admin-side service responsible for deploying Custom Metadata Type records
 * (templates, criteria, assignments) on behalf of the Avtalsgranskaren admin
 * LWC, and for polling the Tooling API when the platform-event ack is lost.
 *
 * Sharing: {@code without sharing} so the admin LWC can deploy regardless of
 * the running user's FLS on the MDT records. Access is gated upstream by the
 * {@code Contract_Review_Admin} permission set.
 *
 * Governor-limit notes:
 *   - {@link #deployBundledRecords} performs no SOQL/DML directly; it
 *     enqueues an asynchronous Metadata API deployment via
 *     {@code Metadata.Operations.enqueueDeployment}.
 *   - {@link #checkDeployStatus} performs 1 HTTP GET to the Tooling API
 *     and counts against the 100-callouts-per-transaction limit.
 */
public without sharing class ContractReviewMetadataService {
  /**
   * Indirection seam over {@code Metadata.Operations.enqueueDeployment} so
   * tests can verify the deployment payload without hitting the platform.
   * Subclass and override {@link #enqueue} in test code, then assign to
   * the {@code handler} static field below.
   */
  @TestVisible
  private virtual class DeploymentHandler {
    public virtual String enqueue(Metadata.DeployContainer container) {
      Id jobId = Metadata.Operations.enqueueDeployment(
        container,
        new ContractReviewMetadataDeployCallback()
      );
      return String.valueOf(jobId);
    }
  }

  @TestVisible
  private static DeploymentHandler handler = new DeploymentHandler();

  private static final Set<String> ALLOWED_METADATA_TYPES = new Set<String>{
    'ContractReviewTemplate__mdt',
    'ContractReviewCriterion__mdt',
    'ContractReviewTemplateAssignment__mdt'
  };

  /**
   * Translates a list of admin-LWC payload maps into a single
   * {@code Metadata.DeployContainer} and enqueues the asynchronous
   * Metadata API deployment. Validates that each payload references an
   * MDT type from the {@code ALLOWED_METADATA_TYPES} allow-list — this
   * is the primary security check.
   *
   * Governor-limit note: 1 async Metadata API deploy enqueued; no SOQL/DML.
   *
   * @param metadataRecords List of maps, each containing
   *                        {@code sObjectName}, {@code developerName},
   *                        {@code label}, and an optional {@code fields}
   *                        map of MDT field values.
   * @return The DeployRequest job Id (prefix {@code 0Af}) that the LWC
   *         can pass to {@link #checkDeployStatus} or correlate with the
   *         {@code ContractReviewMetadataDeployResult__e} platform event.
   * @throws AuraHandledException for empty input, blank required fields,
   *         or sObjectName outside the allow-list.
   */
  @AuraEnabled
  public static String deployBundledRecords(
    List<Map<String, Object>> metadataRecords
  ) {
    if (metadataRecords == null || metadataRecords.isEmpty()) {
      throw new AuraHandledException(
        'metadataRecords list cannot be null or empty.'
      );
    }
    try {
      Metadata.DeployContainer container = new Metadata.DeployContainer();

      for (Map<String, Object> recordMap : metadataRecords) {
        String sObjectName = (String) recordMap.get('sObjectName');
        String devName = (String) recordMap.get('developerName');
        String recordLabel = (String) recordMap.get('label');

        if (
          String.isBlank(sObjectName) ||
          !ALLOWED_METADATA_TYPES.contains(sObjectName)
        ) {
          throw new AuraHandledException(
            'Invalid metadata type: ' +
              sObjectName +
              '. Allowed types: ' +
              ALLOWED_METADATA_TYPES
          );
        }
        validateRequiredInputs(devName, recordLabel);

        Metadata.CustomMetadata record = new Metadata.CustomMetadata();
        record.fullName = sObjectName + '.' + devName;
        record.label = recordLabel;

        Object fieldsRaw = recordMap.get('fields');
        Map<String, Object> fields = fieldsRaw != null
          ? (Map<String, Object>) JSON.deserializeUntyped(
              JSON.serialize(fieldsRaw)
            )
          : null;
        if (fields != null) {
          for (String fieldName : fields.keySet()) {
            Metadata.CustomMetadataValue fieldValue = new Metadata.CustomMetadataValue();
            fieldValue.field = fieldName;
            fieldValue.value = fields.get(fieldName);
            record.values.add(fieldValue);
          }
        }

        container.addMetadata(record);
      }

      return handler.enqueue(container);
    } catch (AuraHandledException e) {
      throw e;
    } catch (Exception e) {
      throw new AuraHandledException(e.getMessage());
    }
  }

  private static final Pattern SFDC_ID_PATTERN = Pattern.compile(
    '^[a-zA-Z0-9]{15}([a-zA-Z0-9]{3})?$'
  );

  /**
   * Polling fallback when the {@code ContractReviewMetadataDeployResult__e}
   * platform event is missed (timeout or subscriber re-init).
   *
   * Issues a Tooling API SOQL via REST against the running org's domain
   * URL using the user's session token — there is no Named Credential.
   *
   * Governor-limit note: 1 HTTP callout. Callers should debounce.
   *
   * @param jobId The DeployRequest Id returned by {@link #deployBundledRecords}.
   *              Validated against the SFDC Id pattern before the callout.
   * @return Map containing {@code status} (e.g. {@code Succeeded},
   *         {@code InProgress}, {@code Failed}, {@code NotFound}) and
   *         {@code errorMessage} (empty string when none).
   * @throws AuraHandledException for blank/invalid jobId or HTTP failure.
   */
  @AuraEnabled
  public static Map<String, String> checkDeployStatus(String jobId) {
    if (String.isBlank(jobId)) {
      AuraHandledException e = new AuraHandledException('Job ID is required.');
      e.setMessage('Job ID is required.');
      throw e;
    }
    if (!SFDC_ID_PATTERN.matcher(jobId).matches()) {
      AuraHandledException e = new AuraHandledException(
        'Invalid Job ID format.'
      );
      e.setMessage('Invalid Job ID format.');
      throw e;
    }
    try {
      // Tooling API REST: single-row SELECT against DeployRequest. Bearer
      // token is the running user's session id — only admins reach this
      // class because the upstream LWC is gated by the admin permset.
      HttpRequest req = new HttpRequest();
      req.setEndpoint(
        Url.getOrgDomainUrl().toExternalForm() +
          '/services/data/v66.0/tooling/query/?q=' +
          EncodingUtil.urlEncode(
            'SELECT Id, Status, ErrorMessage FROM DeployRequest WHERE Id = \'' +
              String.escapeSingleQuotes(jobId) +
              '\' LIMIT 1',
            'UTF-8'
          )
      );
      req.setMethod('GET');
      req.setHeader('Authorization', 'Bearer ' + UserInfo.getSessionId());
      req.setHeader('Content-Type', 'application/json');

      HttpResponse res = new Http().send(req);
      Map<String, String> result = new Map<String, String>();

      if (res.getStatusCode() != 200) {
        result.put('status', 'NotFound');
        result.put(
          'errorMessage',
          'Unable to query deploy status (HTTP ' + res.getStatusCode() + ').'
        );
        return result;
      }

      Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(
        res.getBody()
      );
      List<Object> records = (List<Object>) body.get('records');

      if (records == null || records.isEmpty()) {
        result.put('status', 'NotFound');
        result.put('errorMessage', 'Deploy request not found.');
      } else {
        Map<String, Object> record = (Map<String, Object>) records[0];
        result.put('status', (String) record.get('Status'));
        String errMsg = (String) record.get('ErrorMessage');
        result.put('errorMessage', errMsg != null ? errMsg : '');
      }
      return result;
    } catch (AuraHandledException e) {
      throw e;
    } catch (Exception e) {
      AuraHandledException ex = new AuraHandledException(e.getMessage());
      ex.setMessage(e.getMessage());
      throw ex;
    }
  }

  private static void validateRequiredInputs(
    String developerName,
    String label
  ) {
    if (String.isBlank(developerName)) {
      throw new AuraHandledException(
        'Developer Name is required and cannot be blank.'
      );
    }
    if (String.isBlank(label)) {
      throw new AuraHandledException('Label is required and cannot be blank.');
    }
  }
}