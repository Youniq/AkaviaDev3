@IsTest
public class WebropolAddRecipientFailCalloutMock implements HttpCalloutMock {
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
    if (endpoint.contains('getbyemail')) {
      res.setStatusCode(200);
      res.setBody('[]');
      res.setHeader('Content-Type', 'application/json');
      return res;
    }
    if (
      endpoint.contains('/recipients') &&
      !endpoint.contains('getbyemail')
    ) {
      res.setStatusCode(400);
      res.setBody('{"error":"bad request"}');
      res.setHeader('Content-Type', 'application/json');
      return res;
    }
    res.setStatusCode(404);
    res.setBody('Unexpected endpoint: ' + req.getEndpoint());
    return res;
  }
}