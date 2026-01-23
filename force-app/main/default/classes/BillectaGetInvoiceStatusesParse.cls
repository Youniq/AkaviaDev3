//Draft - måste specas när vi har fått reda på vilket API vi skall använda.
global class BillectaGetInvoiceStatusesParse {
    
    global class InvoiceActionStatusViews{
        public List<InvoiceActionStatusView> InvoiceStatuses;
    }
    
    global class InvoiceActionStatusView{
        public string DistributionMethod_c;
        public double Amount_c;
        public double AmountAkassa;
        public String PaymentMethod_c;
        public double RemainingAmount_c;
        public String PaymentStatus_c;
        public string Name;
        public String OCR_c;
        public String ExpirationDate_c;
        public String InvoiceDate_c;
        public string InvoiceLink_c;
        public string InvoicePeriodStart_c;
        public string InvoicePeriodEnd_c;
        public string PaymentDate_c;
        public string Reminder1_c;
        public string Reminder2_c;
        public string Reminder3_c;
        public string InvoiceStatus_c;
        public string MembershipCategory_c;
        public string FeeCategory_c;
        public string AutogiroStatusMessage_c;
        public string AutogiroStatusMessageDate_c;
    }
    
    global static BillectaGetInvoiceStatusesParse.InvoiceActionStatusView parse(String json) {
        return (BillectaGetInvoiceStatusesParse.InvoiceActionStatusView) System.JSON.deserialize(json, BillectaGetInvoiceStatusesParse.InvoiceActionStatusView.class);
    }
	
/*    global static BillectaGetInvoiceStatusesParse.InvoiceActionStatusViews parseList(String json) {
        return (BillectaGetInvoiceStatusesParse.InvoiceActionStatusViews) System.JSON.deserialize(json, BillectaGetInvoiceStatusesParse.InvoiceActionStatusViews.class);
    }*/

}

/**
 * GET /v1/akavia/InvoiceActionStatus?id=[actionpublicid(string)]
Response:
{
  "typeName": "InvoiceActionStatusView",
  "additionalProperties": false,
  "type": "object",
  "properties": {
    "DistributionMethod_c": {
      "type": "string"
    },
    "Amount_c": {
      "type": "number"
    },
    "PaymentMethod_c": {
      "type": "string"
    },
    "RemainingAmount_c": {
      "type": "number"
    },
    "PaymentStatus_c": {
      "type": "string"
    },
    "Name": {
      "type": "string"
    },
    "OCR_c": {
      "type": "string"
    },
    "ExpirationDate_c": {
      "type": "string"
    },
    "InvoiceDate_c": {
      "type": "string"
    },
    "InvoiceLink_c": {
      "type": "string"
    },
    "InvoicePeriodStart_c": {
      "type": "string"
    },
    "InvoicePeriodEnd_c": {
      "type": "string"
    },
    "PaymentDate_c": {
      "type": "string"
    },
    "Reminder1_c": {
      "type": "string"
    },
    "Reminder2_c": {
      "type": "string"
    },
    "Reminder3_c": {
      "type": "string"
    },
    "InvoiceStatus_c": {
      "type": "string"
    },
    "MembershipCategory_c": {
      "type": "string"
    },
    "FeeCategory_c": {
      "type": "string"
    },
    "AutogiroStatusMessage_c": {
      "type": "string"
    },
    "AutogiroStatusMessageDate_c": {
      "type": "string"
    }
  },
 */