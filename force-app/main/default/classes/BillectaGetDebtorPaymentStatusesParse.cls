global class BillectaGetDebtorPaymentStatusesParse {
	
    global DebtorPaymentStatusView[] DebtorPaymentStatusViews;
    
    global class DebtorPaymentStatusView{
        public double Balance_c;
        public double OverdueAmount_c;
        public integer ReminderStatus_c;
        public String LatestPaymentDate_c;
        public String PaymentMethod_c;
        public String DistributionMethod_c;
        public String AutogiroApprovalStatus_c;
        public String BillectaID_c;
    }
    
    global static BillectaGetDebtorPaymentStatusesParse.DebtorPaymentStatusView parse(String json) {
        return (BillectaGetDebtorPaymentStatusesParse.DebtorPaymentStatusView) System.JSON.deserialize(json, BillectaGetDebtorPaymentStatusesParse.DebtorPaymentStatusView.class);
    }
	
/*    global static BillectaGetDebtorPaymentStatusesParse parseList(String json) {
        return (BillectaGetDebtorPaymentStatusesParse) System.JSON.deserialize(json, BillectaGetDebtorPaymentStatusesParse.class);
    }*/

    
/*
 * Response Schema:  
{
  "typeName": "DebtorPaymentStatusView",
  "additionalProperties": false,
  "type": "object",
  "properties": {
    "Balance_c": {
      "type": "number"
    },
    "OverdueAmount_c": {
      "type": "number"
    },
    "ReminderStatus_c": {
      "type": "integer"
    },
    "LatestPaymentDate_c": {
      "type": "string"
    },
    "PaymentMethod_c": {
      "type": "string"
    },
    "DistributionMethod_c": {
      "type": "string"
    },
    "AutogiroApprovalStatus_c": {
      "type": "string"
    }
  },
  "$schema": "http://json-schema.org/draft-04/schema#"
}*/

}