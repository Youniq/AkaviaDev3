/**
 * REST för akavia.se/loneenkat – hämta eller skapa personlig Webropol-länk.
 *
 * POST /services/apexrest/webropol/v1/personal-link
 * Body: { "accountId": "001...", "settingsDeveloperName": "Default", "createIfMissing": true }
 *   eller: { "memberId": "851288", "email": "medlem@example.com", "createIfMissing": true }
 *
 * 200 = personalLink klar. 202 = respondenten förbereds i Webropol; anropa igen
 * efter Retry-After sekunder (samma body) tills 200 eller fel.
 */
@RestResource(urlMapping='/webropol/v1/personal-link')
global with sharing class WebropolSurveyRestResource {
  @TestVisible
  static final Integer RETRY_AFTER_SECONDS = 5;

  global class RequestBody {
    public String accountId;
    public String memberId;
    public String email;
    public String settingsDeveloperName;
    public Boolean createIfMissing;
  }

  @HttpPost
  global static void postPersonalLink() {
    RestRequest req = RestContext.request;
    RestResponse res = RestContext.response;

    String payload = req.requestBody != null ? req.requestBody.toString() : null;
    if (String.isBlank(payload)) {
      writeError(res, 400, 'Request body saknas');
      return;
    }

    RequestBody body;
    try {
      body = (RequestBody) JSON.deserialize(payload, RequestBody.class);
    } catch (Exception ex) {
      writeError(res, 400, 'Ogiltig JSON');
      return;
    }

    String settingsName = String.isBlank(body.settingsDeveloperName)
      ? 'Default'
      : body.settingsDeveloperName.trim();
    Boolean createIfMissing = body.createIfMissing != false;

    WebropolSurveyService.LinkResult result;
    try {
      if (String.isNotBlank(body.accountId)) {
        Id accountId = parseAccountId(body.accountId);
        if (accountId == null) {
          writeError(res, 400, 'Ogiltigt accountId');
          return;
        }
        result = WebropolSurveyService.ensurePersonalLinkForAccount(
          accountId,
          settingsName,
          createIfMissing
        );
      } else if (
        String.isNotBlank(body.memberId) &&
        String.isNotBlank(body.email)
      ) {
        result = WebropolSurveyService.ensurePersonalLink(
          settingsName,
          body.memberId.trim(),
          body.email.trim(),
          createIfMissing
        );
      } else {
        writeError(
          res,
          400,
          'Ange accountId eller memberId + email'
        );
        return;
      }
    } catch (Exception ex) {
      writeError(res, 500, ex.getMessage());
      return;
    }

    if (result.createdRecipient == null) {
      result.createdRecipient = false;
    }
    if (result.pending == true) {
      res.addHeader('Retry-After', String.valueOf(RETRY_AFTER_SECONDS));
    }
    writeResult(res, statusForResult(result), result);
  }

  @TestVisible
  private static Id parseAccountId(String accountIdValue) {
    try {
      return (Id) accountIdValue.trim();
    } catch (Exception ex) {
      return null;
    }
  }

  @TestVisible
  private static Integer statusForResult(
    WebropolSurveyService.LinkResult result
  ) {
    if (result == null) {
      return 500;
    }
    if (result.success == true) {
      return 200;
    }
    if (result.pending == true) {
      return 202;
    }
    String msg = result.message == null ? '' : result.message.toLowerCase();
    if (
      msg.contains('e-post') ||
      msg.contains('medlemsnummer') ||
      msg.contains('account id saknas') ||
      msg.contains('ogiltigt accountid') ||
      msg.contains('ange accountid')
    ) {
      return 400;
    }
    if (
      msg.contains('kunde inte skapa respondent') ||
      msg.contains('webropol token') ||
      msg.contains('webropol-anrop misslyckades') ||
      msg.contains('getbyemail misslyckades')
    ) {
      return 502;
    }
    return 404;
  }

  private static void writeResult(
    RestResponse res,
    Integer statusCode,
    WebropolSurveyService.LinkResult result
  ) {
    res.statusCode = statusCode;
    res.addHeader('Content-Type', 'application/json');
    res.responseBody = Blob.valueOf(JSON.serialize(result));
  }

  private static void writeError(
    RestResponse res,
    Integer statusCode,
    String message
  ) {
    WebropolSurveyService.LinkResult err = new WebropolSurveyService.LinkResult();
    err.success = false;
    err.message = message;
    err.createdRecipient = false;
    writeResult(res, statusCode, err);
  }
}