@IsTest
public class WebropolRecipientPollCalloutMock implements HttpCalloutMock {
  private Integer getRecipientCalls = 0;

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
    if (
      endpoint.contains('/recipients/') &&
      !endpoint.contains('getbyemail')
    ) {
      getRecipientCalls++;
      res.setStatusCode(200);
      res.setHeader('Content-Type', 'application/json');
      if (getRecipientCalls == 1) {
        res.setBody('[]');
        return res;
      }
      res.setBody(
        '[{"RecipientId":"new-recipient-id",' +
          '"PersonalLinkToSurvey":"https://link.webropolsurveys.com/R/POLLED"}]'
      );
      return res;
    }
    res.setStatusCode(404);
    res.setBody('Unexpected endpoint: ' + req.getEndpoint());
    return res;
  }
}