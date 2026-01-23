/**
 * @description       : 
 * @author            : Malin Nilsson (Stretch Customer AB)
 * @group             : 
 * @last modified on  : 2024-12-16
 * @last modified by  : Malin Nilsson (Stretch Customer AB)
**/
public class BillectaSwishHelper {
    @AuraEnabled public String Status {get;set;}
    @AuraEnabled public String errorMessage {get;set;}
    @AuraEnabled public Invoice__c theInvoice {get;set;}
    
    @AuraEnabled 
    public static BillectaSwishHelper initData(String recordId){
        System.debug('Hätma data');
        BillectaSwishHelper obj = new BillectaSwishHelper();
        obj.theInvoice = [SELECT Id, Swish_Phone__c, BillectaID__c FROM Invoice__c WHERE ID =:recordId];
        
        return obj;
        
    }
    
    @AuraEnabled
    public Static String initSwishPayment(BillectaSwishHelper currentObj){
        
        BillectaSwishHelper obj = currentObj;        
        Http http = new Http(); 
        HttpRequest request = new HttpRequest();
        HttpResponse response = new HttpResponse();
		
        request = BillectaUtils.initBillectaRequest(request);
        request = BillectaUtils.SwishPaymentRequest(request, obj.theInvoice.BillectaID__c, obj.theInvoice.Swish_Phone__c);
        
        try{
            response = http.send(request);
            BillectaSwish.CreatedView jsonResponse;
            
            if(response.getStatusCode()==200 ||response.getStatusCode()==201 ){
                jsonResponse = BillectaSwish.parse(response.getBody());
                if(jsonresponse.PublicId != null){
                    return jsonresponse.PublicId;
                }

            } 
            else if (response.getStatusCode()!=200 && response.getStatusCode()!=201){
                obj.Status = 'Failed with message : ';
                obj.errorMessage = obj.errorMessage +'<--APEX*****'+'Billecta'+'-->'+response.getBody();
                throw new CalloutException(obj.errorMessage);
            }
         }catch(Exception e){
            obj.Status = 'Failed';
            obj.ErrorMessage = e.getMessage();

            ApexLog.Error logError = new ApexLog.Error('BillectaSwishHelper', 'initSwishPayment', true, e);
            ApexLog.createLogDebug(logError);
            return obj.Status + response.getBody();
        }

        return 'Failed';
        
    }
    @AuraEnabled
    public Static BillectaSwishHelper getSwishRequestStatus(BillectaSwishHelper obj, String PublicId){
        obj.Status = 'Waiting';
        Http http2 = new Http(); 
        HttpRequest request2 = new HttpRequest();
        HttpResponse response2 = new HttpResponse();

        request2 = BillectaUtils.initBillectaRequest(request2);
        request2 = BillectaUtils.SwishPaymentStatus(request2, PublicId);
      
            try{
                response2 = http2.send(request2);
            
                if(response2.getStatusCode()==200 ||response2.getStatusCode()==201 ){
                    BillectaSwish.SwishPaymentStatusView jsonResp = BillectaSwish.parseStatus(response2.getBody());
                    if(jsonResp.Status != 'Created'){
                        obj.Status = jsonResp.Status;
                        if(obj.Status != 'Paid'){
                            obj.Status = 'Failed';
                            obj.errorMessage = jsonResp.Status;
                        }
                    }
                }

                else if (response2.getStatusCode()!=200 && response2.getStatusCode()!=201){
                    obj.Status = 'Failed';
                    obj.errorMessage = obj.errorMessage +'<--APEX*****'+'Billecta'+'-->'+response2.getBody();
                    system.debug(response2.getBody());
                    throw new CalloutException(obj.errorMessage);
                }
                else{
                    obj.Status = 'Failed';
                    obj.errorMessage = obj.errorMessage +'<--APEX*****'+'Billecta'+'-->'+response2.getBody();
                }
             }catch(Exception e){
                obj.Status = 'Failed';
                obj.ErrorMessage = e.getMessage();
                ApexLog.Error logError = new ApexLog.Error('BillectaSwishHelper', 'getSwishRequestStatus', true, e);
                ApexLog.createLogDebug(logError);
            }
        
        return obj;
    }
    
}