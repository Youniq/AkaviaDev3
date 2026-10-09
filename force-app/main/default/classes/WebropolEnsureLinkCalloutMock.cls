@IsTest
public class WebropolEnsureLinkCalloutMock implements HttpCalloutMock {
  private Integer getByEmailCalls = 0;
  private final String memberId;
  private final String link;

  public WebropolEnsureLinkCalloutMock(String memberId, String link) {
    this.memberId = memberId;
    this.link = link;
  }

  public HTTPResponse respond(HTTPRequest req) {
    HttpResponse res = new HttpResponse();
    String endpoint = req.getEndpoint() != null ? req.getEndpoint().toLowerCase() : '';
    if (endpoint.contains('/token') || endpoint.contains('webropol_api/token')) {
      res.setStatusCode(200);
      res.setBody(
        '{"access_token":"test-token","token_type":"bearer","expires_in":3600}'
      );
      res.setHeader('Content-Type', 'application/json');
      return res;
    }
    if (endpoint.contains('exportdemdatafile')) {
      res.setStatusCode(200);
      res.setBodyAsBlob(WebropolHttpCalloutMock.demDataTemplateXlsx());
      res.setHeader(
        'Content-Type',
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
      );
      return res;
    }
    if (endpoint.contains('importrecipientwithdemdata')) {
      res.setStatusCode(200);
      res.setBody(
        '{"RecipientsAdded":["new-recipient-id"],' +
          '"Message":"1 out of 1 recipients uploaded successfully",' +
          '"IsFailed":false,"IsScheduled":true}'
      );
      res.setHeader('Content-Type', 'application/json');
      return res;
    }
    if (
      endpoint.contains('/recipients/') &&
      !endpoint.contains('getbyemail')
    ) {
      res.setStatusCode(200);
      res.setBody(
        '[{"RecipientId":"new-recipient-id",' +
          '"PersonalLinkToSurvey":"' +
          link +
          '"}]'
      );
      res.setHeader('Content-Type', 'application/json');
      return res;
    }
    if (endpoint.contains('getbyemail')) {
      getByEmailCalls++;
      res.setStatusCode(200);
      res.setHeader('Content-Type', 'application/json');
      if (getByEmailCalls == 1) {
        res.setBody('[]');
        return res;
      }
      res.setBody(
        '[{"PersonalLinkToSurvey":"' +
          link +
          '","Fields":[{"FieldName":"1:1:MemberId","FieldValue":"' +
          memberId +
          '"}]}]'
      );
      return res;
    }
    if (
      endpoint.contains('/recipients') &&
      !endpoint.contains('getbyemail')
    ) {
      res.setStatusCode(201);
      res.setBody('{}');
      res.setHeader('Content-Type', 'application/json');
      return res;
    }
    res.setStatusCode(404);
    res.setBody('Unexpected endpoint: ' + req.getEndpoint());
    return res;
  }
}