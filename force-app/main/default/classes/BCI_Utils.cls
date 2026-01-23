/*******************************************************************
* @author: Jenny Blomberg
* @date: 2022-10-28
* @description: Utils class that holds methods used by BCI Search implementation
*
********************************************************************/
public class BCI_Utils {

    public static final String GET = 'GET';


    /*****************
     * @description Wrapper Class to represent the response from BCI when we ask for person
     *********************/
    public class ResponseHolder {
        public BCI_PersonResponse Response = null;
        public String ErrorMessage = null;
    }

    /*****************
     * @description Method to perform callout and get person fom BCI
     * @paramer accessToken
     * @parameter ssn
     * @parameter country
     * @return ResponseHolder
     *********************/
    public static ResponseHolder getPerson(String ssn, String country) {
    
        ResponseHolder responseHolder = new ResponseHolder();

        Http http = new Http(); 
        HttpRequest request = new HttpRequest(); 
       	HttpResponse response = new HttpResponse();

        request = SparCallout.initGenericRequest(request);

        
        String sourceCountry;
        if (country == 'Sweden') sourceCountry = 'SE';

        // Add person search endpoint
        request.setEndpoint(request.getEndpoint() + '/person/search');
        // Add query parameters to the request
        request.setEndpoint(request.getEndpoint() + '?' + 'sourceCountry=' + sourceCountry + '&' + 'legalId=' + ssn.replace('-',''));
        request.setMethod(GET); 
        request.setTimeout(120000);

        String endpoint = request.getEndpoint();
        System.debug('request endpoint: ' + endpoint);

        try {
            System.debug(request);
            response = http.send(request);
        } catch (Exception e) {
           ApexLog.Error logError = new ApexLog.Error('BCI_Utils', 'getPerson', true, e);
           ApexLog.createLogDebug(logError);           
        }

        if(response.getStatusCode()==200 ||response.getStatusCode()==201 ){
            BCI_PersonResponse personResponse = BCI_PersonResponse.parse(response.getBody());
            responseHolder.Response = personResponse;
            return responseHolder;
        }else if (response.getStatusCode()!=200 && response.getStatusCode()!=201){
            system.debug(response.getStatusCode());
            system.debug(response.getBody());
            responseHolder.ErrorMessage = 'SSN lookup return error message (' + response.getBody() +'). Please enter information manually to continue.';
            return responseHolder;
        } 
  
        responseHolder.Response = BCI_PersonResponse.parse(response.getBody());

        return responseHolder;
    }
}