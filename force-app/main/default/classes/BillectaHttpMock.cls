
@IsTest
public class BillectaHttpMock implements HttpCalloutMock {

    private Integer statusCode;
    private String responseBody;

    public BillectaHttpMock(
        Integer statusCode,
        String responseBody
    ) {
        this.statusCode = statusCode;
        this.responseBody = responseBody;
    }

    public HttpResponse respond(HttpRequest request) {

        HttpResponse response = new HttpResponse();

        response.setStatusCode(statusCode);
        response.setHeader(
            'Content-Type',
            'application/json'
        );
        response.setBody(responseBody);

        return response;
    }
}
