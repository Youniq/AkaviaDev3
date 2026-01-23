/*******************************************************************
* @author: Jenny Blomberg
* @date: 2022-10-28
* @description: Invocable action to be used from flow to fetch address information
* from BCI. 
********************************************************************/
public class BCI_HandlerInvocable {

    public class Request {
        @InvocableVariable
        public Account account;

        @InvocableVariable
        public String SSN;

        @InvocableVariable
        public string country;
    }

    public class Result {
        @InvocableVariable(label='Records for Output' description='Accounts' required=true)
        public Account account;
        @InvocableVariable(label='BCI message' description='Message' required=false)
        public String message;
        public String addressType;
    }

    /****************************************************************
     * @author: Jenny Blomberg
     * @date: 2022-10-28
     * @param: List<Request>
     * @return List<Result>
     * @description: Invocable method to be used from flow to fetch address information
     * from BCI.
     * This main method holds the callout logic
    *****************************************************************/ 
    @InvocableMethod(label='Fetch person information from BCI' description='Input: if new account --> SSN, if existing account --> account')
    public static List<Result> populateInformation(List<Request> requests) {
  
        List<Result> results = new List<Result>();

        for (Request r: requests) {
            Result result = new Result();
            Account account = new Account();
            if (r.account != null) account = r.account;
            if (r.SSN !=null) account.SocialSecurityNumber__c = r.SSN;

            result.account = account;
            result = emptyMapping(result);        
            BCI_Utils.ResponseHolder responseHolder = new BCI_Utils.ResponseHolder();
            responseHolder = BCI_Utils.getPerson(r.ssn, r.country);

            if (responseHolder.ErrorMessage != null) {
                result.message = 'BCI Error Message: ' + responseHolder.ErrorMessage;
                results.add(result);
                return results;  
            } else {
                BCI_PersonResponse response = responseHolder.Response;
                result = handleResponse(result, response, r.country);
            }
            results.add(result);
        }
        
        return results;
    }

    /****************************************************************
     * @author: Jenny Blomberg
     * @date: 2022-10-28
     * @param: List<Request>
     * @return List<Result>
     * @description: Private method to handle response from BCI depending on if the response
     * indicates no hit, Deceased or Protected Identity. If non of the previous is true then we
     * move on to mapping the respons to our account. 
    *****************************************************************/ 
    @testVisible
    private static Result handleResponse(Result result, BCI_PersonResponse response, String country) {
        // Check for real response
        if (response == null) {
            result.message = 'BCI: something went wrong';
            return result;
        }

        // Check if BCI returned any hits
        if (response.persons.size() < 1) {
            result.message = 'Person not found for ' + result.account.SocialSecurityNumber__c;
            result.message = 'Person not found for ';
            return result;
        }

        // Check protectedIdentity
        if (response.persons[0].person.protectedIdentity == true) {
            result.message = 'Person has protected identity - no information can be retrieved';
           result.account.ProtectedIdentity__c = true;
            return result;
        }

        // Check deceased
        if(response.persons[0].person.deceased == true){
            result.message = 'Person is registered as deceased';
           result.account.Deceased__c = true;
            return result;   
        }

        // Check deregistration
        if (response.persons[0].person.deregistered == true) {
            result.message = 'Person is deregistred';
            return result;
        }

        result = mapResponse(result, response, country);
        return result;
    }

    /****************************************************************
     * @author: Jenny Blomberg
     * @date: 2022-10-28
     * @param: List<Request>
     * @return List<Result>
     * @description: Private method to map response from BCI to Account fields
    *****************************************************************/ 
    @testVisible
    private static Result mapResponse(Result result, BCI_PersonResponse response, String country) {
        
        String firstName = response.persons[0].person.preferredFirstName;

    	if (firstName == null) {
            firstName = String.join(response.persons[0].person.firstNames, ' ');
        }


        result.account.FirstName = firstName;
        result.account.LastName = response.persons[0].person.familyName;
        
        // Verify that we get an address
        if (response.persons[0].person.addressList.size() < 1) {
            result.message = 'No address was returned for that person';
            return result;
        }
        
        List<String> addressTypes = new List<String>();

        for (Integer i=0; i < response.persons[0].person.addressList.size(); i++) {
            addressTypes.add(response.persons[0].person.addressList[i].type);
        }

        Integer index = -1;
        if ((addressTypes.indexOf('Visiting') != -1) && country == 'Sweden') {
            index = addressTypes.indexOf('Visiting');
        } else if ((addressTypes.indexOf('Postal') != -1) && ( country == 'Sweden')) {
            index = addressTypes.indexOf('Postal');
        }

        if (index > -1) {
            result.account.PersonMailingStreet =  response.persons[0].person.addressList[index].fullAddressString;
            result.account.PersonMailingPostalCode = response.persons[0].person.addressList[index].postalCode;
            result.account.PersonMailingCity = response.persons[0].person.addressList[index].city;
            result.account.PersonMailingCountry = country;
            result.addressType = response.persons[0].person.addressList[index].type;
        } else {
            result.message = 'No valid address found for that person';
        }
        return result;
    }

    @testVisible
    private static Result emptyMapping(Result result){ 
        result.account.FirstName = null; 
        result.account.LastName = null; 
        result.account.PersonMailingStreet = null;
        result.account.PersonMailingCity = null;
        result.account.PersonMailingPostalCode = null;
        result.account.PersonMailingCountry = null;
        result.account.ProtectedIdentity__c = false;
        result.account.Deceased__c = false;

        return result;
    }

}