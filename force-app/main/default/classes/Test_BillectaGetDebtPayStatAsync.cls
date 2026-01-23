/******************************
 * Test Class to cover:
 * 
 * 
 * @Author Jenny Blomberg
 * 2020-12-xx
*******************************/

@isTest
public class Test_BillectaGetDebtPayStatAsync {
    
    @testSetup
    static void setup(){}
    
    public class MockHttpResponseGeneratorBillecta implements HttpCalloutMock {
        // Implement this interface method
        public HTTPResponse respond(HTTPRequest request) {
            HttpResponse response = new HttpResponse();
            response.setHeader('Content-Type', 'application/json');
            response.setBody('[{"Balance_c": 0.0,"OverdueAmount_c": 0.0,"ReminderStatus_c": 0,"LatestPaymentDate_c": "","PaymentMethod_c": "BG","DistributionMethod_c": "E-faktura","AutogiroApprovalStatus_c": "","BillectaID_c": "testId-01"},"HasError":false,"ErrorMessage":null}]');
            response.setStatusCode(200);
            return response;
        }
    }

}