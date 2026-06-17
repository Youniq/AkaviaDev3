global class BatchUpdAccountPaymentStatus implements Database.Batchable<sObject>, Database.AllowsCallouts {
	global final string Query;
    global final Set<String> BillectaIdsAsArray;
    global final Map<String, BillectaGetDebtorPaymentStatusesParse.DebtorPaymentStatusView> jsonMap;
    
    
    global BatchUpdAccountPaymentStatus(Map<String, BillectaGetDebtorPaymentStatusesParse.DebtorPaymentStatusView> jsonRespMap) {
       	BillectaIdsAsArray = jsonRespMap.keyset();
        jsonMap = jsonRespMap;
        Query = 'SELECT Id, PaymentStatusUpdated__c, BillectaID__c, Balance__c, OverdueAmount__c, ReminderStatus__c,'+
                       'LatestPaymentDate__c, PaymentMethod__c, DistributionMethod__c,'+
                       'AutogiroApprovalStatus__c FROM Account WHERE BillectaID__c IN: BillectaIdsAsArray';
    }

    global Database.QueryLocator start(Database.BatchableContext BC) {
        
        return Database.getQueryLocator(query);
    }

    global void execute(Database.BatchableContext BC, List<Account> accountsToLoop) {
        System.debug('-----'+ jsonMap + '-------');
        try {
            for(Account acc: accountsToLoop){
                BillectaGetDebtorPaymentStatusesParse.DebtorPaymentStatusView json = jsonMap.get(acc.BillectaID__c);
                acc.Balance__c = json.Balance_c;
            	acc.OverdueAmount__c = json.OverdueAmount_c;
                if(json.ReminderStatus_c != null){
                    acc.ReminderStatus__c = String.valueOf(json.ReminderStatus_c);
                }
                if(json.LatestPaymentDate_c != null && json.LatestPaymentDate_c != '' ){
                    system.debug(json.LatestPaymentDate_c);
                    acc.LatestPaymentDate__c = Date.valueOf(json.LatestPaymentDate_c.left(10));
                }
                acc.PaymentMethod__c = json.PaymentMethod_c;
                acc.DistributionMethod__c = json.DistributionMethod_c;
                acc.AutogiroApprovalStatus__c = json.AutogiroApprovalStatus_c;
                acc.PaymentStatusUpdated__c = DateTime.now();
            }
            update accountsToLoop;
        } catch(DmlException e) {
            System.debug(e.getMessage());
        }
    }
    
    global void finish(Database.BatchableContext BC) {
        
    }
}