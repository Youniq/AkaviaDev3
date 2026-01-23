/**
 * @description       : 
 * @author            : Malin Nilsson (Stretch Customer AB)
 * @group             : 
 * @last modified on  : 2024-12-16
 * @last modified by  : Malin Nilsson (Stretch Customer AB)
**/
public with sharing class BillectaBankIDAuthenticationHelper {
    @AuraEnabled public String status { get;set; }
    @AuraEnabled public String errorMessage { get;set; }
    @AuraEnabled public Account theAccount { get;set; }
    @AuraEnabled public String referenceToken { get;set; }
    @AuraEnabled public String userFriendlyStatus {get;set;}
    @AuraEnabled public String userFriendlyMessage {get;set;}

    PUBLIC FINAL STRING USER_FRIENDLY_STATUS_FAILED = Label.BankIdAuth_Failed; //'Misslyckades';
    PUBLIC FINAL STRING USER_FRIENDLY_STATUS_IDENTIFIED = Label.BankIdAuth_Identified; //'Identifierades';
    PUBLIC FINAL STRING USER_FRIENDLY_MESSAGE_UNEXPECTED_ERROR_INIT = Label.BankIdAuth_ErrorInitRequest;// 'Ett oväntat fel uppstod vid initiering av bankId verifiering. Kontakta administratör för felsökning';
    PUBLIC FINAL STRING USER_FRIENDLY_MESSAGE_UNEXPECTED_ERROR = Label.BankIdAuth_ErrorDuringAuth; //'Ett oväntat fel uppstod under bankId verifiering. Kontakta administratör för felsökning';
    PUBLIC FINAL STRING USER_FRIENDLY_MESSAGE_NO_CLIENT = Label.BankIdAuth_ErrorNoClient; // 'Kunde inte hitta BankId-klient för personnumret';


    @AuraEnabled(cacheable=true)
    public static BillectaBankIDAuthenticationHelper initData(String recordId){
        try{
            BillectaBankIDAuthenticationHelper obj = new BillectaBankIDAuthenticationHelper();
            obj.status = 'Initiated';
            obj.theAccount = [SELECT Id, BillectaID__c, SocialSecurityNumber__c FROM Account WHERE Id = :recordId];
            
            System.debug('initData: ' + obj);
            return obj;
        }catch(Exception e){
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled(cacheable=true)
    public static BillectaBankIDAuthenticationHelper initBankIDAuthentication(BillectaBankIDAuthenticationHelper currentObj){
        BillectaBankIDAuthenticationHelper obj = currentObj;
        Id apexLogId = null;
        obj.errorMessage = '';
        obj.referenceToken = '';
        Billecta__c credentials = [SELECT Id, Creditor__c FROM Billecta__c];
        String formattedSSN = obj.theAccount.SocialSecurityNumber__c.left(8) + '-' + obj.theAccount.SocialSecurityNumber__c.right(4);
        Blob jsonBody = BillectaEncodeJSON.encodeBankIDAuthenticationRequest(credentials.Creditor__c, formattedSSN);
        
        Http http = new Http(); 
        HttpRequest request = new HttpRequest();
        HttpResponse response = new HttpResponse();
		
        request = BillectaUtils.initBillectaRequest(request);
        request = BillectaUtils.initBankIdAuthentication(request, jsonBody);
        System.debug('initBankIDAuthenticationRequest: ' + request);

        try{
            response = http.send(request);
        }catch(Exception e){
            obj.status = 'Failed';
            obj.errorMessage = e.getMessage();
            ApexLog.Information logError = new ApexLog.Information('BillectaBankIDAuthenticationHelper', 'initBankIDAuthentication', true, obj.errorMessage);
            DebugLog__c dl = ApexLog.createAndReturnDebugLog(logError);
            apexLogId = dl.Id;
        }

        BillectaBankIDAuthentication.BankIdAuthenticationStatusView jsonResp;
                
        if(response.getStatusCode()==200 || response.getStatusCode()==201){     
            jsonResp = BillectaBankIDAuthentication.parseResponse(response.getBody());
            obj.status = jsonResp.Status;
            obj.referenceToken = jsonResp.ReferenceToken;
            if(jsonResp.Status == 'Error' || jsonResp.Status == 'NoClient'){
                obj.errorMessage = jsonResp.Status + ' ' + jsonResp.HintCode;
            }
        } else if(response.getStatusCode()!=200 && response.getStatusCode()!=201){
            obj.status = 'Failed with message';
            obj.errorMessage = obj.errorMessage +'<--APEX*****'+'Billecta'+'-->'+response.getBody();
            ApexLog.Information logError = new ApexLog.Information('BillectaBankIDAuthenticationHelper', 'initBankIdAuthentication', true, obj.errorMessage);
            DebugLog__c dl = ApexLog.createAndReturnDebugLog(logError);
            apexLogId = dl.Id;
        }

        System.debug('Initstatus : ' + obj.status);
        if(obj.status != 'Started'){
            BankIdAuthLog__c logRecord = new BankIdAuthLog__c();
            //UserFriendly Status
            logRecord.Status__c = obj.USER_FRIENDLY_STATUS_FAILED;
            obj.userFriendlyStatus = obj.USER_FRIENDLY_STATUS_FAILED;
            //UserFriendly Message
            switch on obj.status {
                when 'NoClient' {
                    logRecord.ErrorMessage__c = obj.USER_FRIENDLY_MESSAGE_NO_CLIENT;
                    obj.userFriendlyMessage = obj.USER_FRIENDLY_MESSAGE_NO_CLIENT;
                }	
                when else {	
                    logRecord.ErrorMessage__c = obj.USER_FRIENDLY_MESSAGE_UNEXPECTED_ERROR_INIT;
                    obj.userFriendlyMessage =  obj.USER_FRIENDLY_MESSAGE_UNEXPECTED_ERROR_INIT;
                }
            }
            logRecord.ReferenceToken__c = obj.referenceToken;
            logRecord.Person__c = obj.theAccount.Id;
            logRecord.DebugLog__c = apexLogId;
            insert logRecord;
        }
        return obj;
    }

    @AuraEnabled(cacheable=false)
    public static BillectaBankIDAuthenticationHelper getBankIDAuthenticationStatus(BillectaBankIDAuthenticationHelper currentObj) {
        Id apexLogId = null;
        BillectaBankIDAuthenticationHelper obj = currentObj;

        Http http = new Http();
        HttpRequest request = new HttpRequest();
        HttpResponse response = new HttpResponse();

        request = BillectaUtils.initBillectaRequest(request);
        request = BillectaUtils.getBankIDAuthenticationStatus(request, obj.referenceToken);
        System.debug('getBankIDAuthenticationStatusRequest: ' + request);

        try{
            response = http.send(request);
        } catch (Exception e){
            obj.status = 'Failed';
            obj.errorMessage = e.getMessage();
            ApexLog.Information logError = new ApexLog.Information('BillectaBankIDAuthenticationHelper', 'getBankIDAuthenticationStatus', true, obj.errorMessage);
            DebugLog__c dl = ApexLog.createAndReturnDebugLog(logError);
            apexLogId = dl.Id;
        }

        System.debug('getBankIDAuthenticationStatusResponse: ' + response.getBody());
        System.debug(response.getStatusCode());

        if(response.getStatusCode() == 200 || response.getStatusCode() == 201){
            BillectaBankIDAuthentication.BankIdAuthenticationStatusView jsonResp = BillectaBankIDAuthentication.parseResponse(response.getBody());
            obj.status = jsonResp.Status;
            if(jsonResp.Status == 'Error' || jsonResp.Status == 'NoClient'){
                obj.errorMessage = jsonResp.Status + ' ' + jsonResp.HintCode;
            }
        } else if(response.getStatusCode() != 200 && response.getStatusCode() != 201){
            obj.status = 'Failed';
            obj.errorMessage = obj.errorMessage + '<--APEX*****' + 'Billecta' + '-->' + response.getBody();
            ApexLog.Information logError = new ApexLog.Information('BillectaBankIDAuthenticationHelper', 'getBankIDAuthenticationStatus', true, obj.errorMessage);
            DebugLog__c dl = ApexLog.createAndReturnDebugLog(logError);
            apexLogId = dl.Id;
        }

        if(obj.status == 'Complete' || obj.status == 'Failed' || obj.status == 'Error' || obj.status == 'NoClient'){
            BankIdAuthLog__c logRecord = new BankIdAuthLog__c();
            switch on obj.status {
                when 'Complete' {
                    logRecord.Status__c = obj.USER_FRIENDLY_STATUS_IDENTIFIED;
                    obj.userFriendlyStatus = obj.USER_FRIENDLY_STATUS_IDENTIFIED;
                }
                when 'NoClient' {
                    logRecord.Status__c = obj.USER_FRIENDLY_STATUS_FAILED;
                    logRecord.ErrorMessage__c = obj.USER_FRIENDLY_MESSAGE_NO_CLIENT;
                    obj.userFriendlyStatus = obj.USER_FRIENDLY_STATUS_FAILED;
                    obj.userFriendlyMessage = obj.USER_FRIENDLY_MESSAGE_NO_CLIENT;
                }	
                when else {	
                    logRecord.Status__c = obj.USER_FRIENDLY_STATUS_FAILED;
                    logRecord.ErrorMessage__c = obj.USER_FRIENDLY_MESSAGE_UNEXPECTED_ERROR;
                    obj.userFriendlyStatus = obj.USER_FRIENDLY_STATUS_FAILED;
                    obj.userFriendlyMessage = obj.USER_FRIENDLY_MESSAGE_UNEXPECTED_ERROR;
                }
            }
            logRecord.ReferenceToken__c = obj.referenceToken;
            logRecord.Person__c = obj.theAccount.Id;
            logRecord.DebugLog__c = apexLogId;
            insert logRecord;
        }

        System.debug('getBankIDAuthenticationStatus: ' + obj);

        return obj;
    }
}