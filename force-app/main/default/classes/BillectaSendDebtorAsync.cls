/**
 * @description       : 
 * @author            : Malin Nilsson (Stretch Customer AB)
 * @group             : 
 * @last modified on  : 2025-07-03
 * @last modified by  : Malin Nilsson (Stretch Customer AB)
**/
public class BillectaSendDebtorAsync implements Queueable, Database.AllowsCallouts {
	private 	Account 	acc				        {get;set;}
    private 	Boolean 	updatePaymentMethod		{get;set;}
    private 	String 		BillectaId 		        {get;set;}
    
    public BillectaSendDebtorAsync(Account acc, Boolean updatePaymentMethod) {
        this.acc = acc;
        this.updatePaymentMethod = updatePaymentMethod;
    }
    
   	
    public void execute(QueueableContext context) {
            Callout__c currentCallout = [Select Id, Status__c, sentOn__c, Duration__c, Response__c, Account__c,
                                         jobId__c, errorLog__c, extraMessage__c From Callout__c Where jobId__c=:context.getJobId()];

            if(currentCallout.extraMessage__c == null){
                currentCallout.extraMessage__c = updatePaymentMethod ? 'Update Contact and Payment Method' : 'Update Contact Details Only';
            }
        
            // Update account with only relevant fields populated to avoid another trigger picking up other billecta triggered field existing on this.acc
            Account accToUpdate = new Account(Id = this.acc.Id); 
   
            /******FIRST WE CREATE/UPDATE DEBTOR*****/
            Long start = System.now().getTime();
            currentCallout = sendToBillecta(currentCallout);
            
            if(currentCallout.errorLog__c==null)currentCallout.status__c = 'OK';
            
            currentCallout.sentOn__c = System.now();
            currentCallout.Duration__c = system.now().getTime()-start;
          
            
            /******SECOND WE ATTACH BILLECTAID TO OUR ACCOUNT *****/
            if(this.acc.BillectaID__c == null && currentCallout.status__c == 'OK'){
                try{   
                    BillectaCreateDebtor.CreatedView jsonResponse = BillectaCreateDebtor.parse(currentCallout.Response__c);
                    BillectaId = jsonResponse.PublicId;

                    this.acc.BillectaID__c = BillectaId; // add billectaID here to ensure all checks in this class compile correctly
                    accToUpdate.BillectaID__c = BillectaId; 
                    update accToUpdate;
                }catch(Exception e){
                    currentCallout = setFailedCalloutValues(currentCallout, e);
                    update currentCallout;
                }
            } 
            else if(this.acc.BillectaID__c != null && currentCallout.status__c == 'OK'){
                
                try{
                    accToUpdate.BillectaMarkedForUpdate__c = null;

                    String sentPMDetails = '';
                    if(this.updatePaymentMethod == true){
                        sentPMDetails = this.acc.PaymentMethod__c + ' : ' + this.acc.DistributionMethod__c;
                    }

                    // If we've sent kivra as default delivery method to billecta, we need to update the account with the correct distribution method
                    if(this.updatePaymentMethod && billectaUtils.isDefaultDeliveryMethodKivra(this.acc) && this.acc.DistributionMethod__c != 'Kivra'){
                        accToUpdate.DistributionMethod__c = 'Kivra';
                        sentPMDetails = this.acc.PaymentMethod__c + ' : Default to Kivra'; // indicate that we've sent kivra as default delivery method to billecta to avoid triggering the callout again
                    }

                    accToUpdate.LatestSentPMDetails_Billecta__c = sentPMDetails;
                    update accToUpdate;
                }catch(Exception e){
                    currentCallout = setFailedCalloutValues(currentCallout, e);
                    update currentCallout;
                }
            } 
           	
            /******THIRD WE UPDATE ACCOUNT AND CALLOUT*****/
            update currentCallout;
        
    }
    
    
    public Callout__c sendToBillecta(Callout__c co){
     	Blob jsonPayload;	
        System.debug('*** sendPayload START ***');
        // MAlin
		// Billecta__c credentials = [SELECT Id, Base64__c, Creditor__c, EndPoint__c FROM Billecta__c];   
		Billecta__c credentials = [SELECT Id, Creditor__c FROM Billecta__c];   

		
        Http http = new Http(); 
        HttpRequest request = new HttpRequest(); 
       	HttpResponse response = new HttpResponse();

        request = BillectaUtils.initBillectaRequest(request);
        if(this.acc.BillectaID__c == null){
            jsonPayload = BillectaEncodeJSON.encodeCreateDebtor(this.acc, credentials.Creditor__c);
            request = BillectaUtils.CreateDebtor(request, jsonPayload);
            

        }else if(this.acc.BillectaID__c != null){

            /**** IF UPDATE WE NEED TO FIRST FETCH THE CURRENT DEBTOR ****/
            request = BillectaUtils.GetDebtor(request, this.acc.BillectaID__c);
            try{
                response = http.send(request);
            }catch(Exception e){
                co = setFailedCalloutValues(co, e);
            }

            if(response.getStatusCode()==200 ||response.getStatusCode()==201 ) {

                co.Response__c = 'RESPONSE GET DEBTOR: ' + response.getBody() + 'END GET DEBTOR *******   RESPONSE UPDATE DEBTOR:  ';
                /** NOW WE NEED TO ADD OUR CHANGES TO DEBTOR **/

                BillectaCreateDebtor.DebtorView currentDebtor = BillectaCreateDebtor.parseDebtor(response.getBody());
                jsonPayload = BillectaEncodeJSON.encodeUpdateDebtor(this.acc, currentDebtor, this.updatePaymentMethod);

                 /** TIME TO UPDATE DEBTOR **/
                request = new HttpRequest(); 
                request = BillectaUtils.initBillectaRequest(request);
                request = BillectaUtils.UpdateDebtor(request, jsonPayload);
            
            }else if (response.getStatusCode()!=200 && response.getStatusCode()!=201){
                co.Status__c = 'Failed';
                co.errorLog__c = co.errorLog__c+'<--APEX*****Billecta-->'+response.getBody();
		        co.path__c = request.getEndpoint();
                return co;
            }            
        }
		
		co.request__c = jsonPayload.toString();
		co.path__c = request.getEndpoint();
		
		System.debug('Request: ' + request); 
        System.debug('Body: ' + request.getBody()); 
		try{
            
            response = http.send(request);
        }catch(Exception e){
             // Debug the headers sent in the request
            System.debug('Request Header SecureToken: ' + request.getHeader('SecureToken'));
            co = setFailedCalloutValues(co, e);
        }    
        
        if(response.getStatusCode()==200 ||response.getStatusCode()==201 ){
            co.Status__c = 'OK';
        } 
        else if (response.getStatusCode()!=200 && response.getStatusCode()!=201){
            co.Status__c = 'Failed';
            co.errorLog__c = co.errorLog__c+'<--APEX*****Billecta-->'+response.getBody();
        } 
            
        System.debug('Response Code: ' + response.getStatusCode());
        System.debug('Response Body: ' + response.getBody());
        if(co.Response__c != null){
            co.Response__c = co.Response__c + response.getBody();
        }else{
            co.Response__c = response.getBody();
        }
        
        return co;
		
		}
    
    public Callout__c setFailedCalloutValues(Callout__c c, Exception e){
        c.Status__c = 'Failed';
        c.errorLog__c = e.getStackTraceString().replace('\n',' / ')+' - '+e.getMessage();
        ApexLog.Error logError = new ApexLog.Error('BillectaSendDebtorAsync', 'execute', true, e);
        ApexLog.createLogDebug(logError);
        return c;
    }

}