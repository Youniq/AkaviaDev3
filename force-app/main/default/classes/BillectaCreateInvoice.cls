/**
 * @description       :
 * @author            : Malin Nilsson (Stretch Customer AB)
 * @group             :
 * @last modified on  : 2026-03-23
 * @last modified by  : Stefan Trieton (Stretch Customer AB)
 **/
global class BillectaCreateInvoice {
    @AuraEnabled public String CreditorPublicId;
    @AuraEnabled public String ExternalId;
    @AuraEnabled public String SocialSecurityNumber;
    @AuraEnabled public String MemberNumber;
    @AuraEnabled public String MembershipCategory;
    @AuraEnabled public String FeeCategory;
    @AuraEnabled public Boolean HaveAkassa;
    @AuraEnabled public Boolean IsCreditInvoice;
    @AuraEnabled public Boolean HaveIncomeInsurance;
    @AuraEnabled public Boolean UseDebtorBalance;
    @AuraEnabled public Date PeriodStart;
    @AuraEnabled public Date PeriodEnd;
    @AuraEnabled public Date DueDate;

    global class CreatedView {
        public String PublicId;
    }

    global static CreatedView parse(String json) {
        return (CreatedView) System.JSON.deserialize(json, CreatedView.class);
    }

  // TODO - Replace with above in order to have them @aurahandled and be able to populate them from flow
  /** Are this still active somewhere?
  global class AkaviaInvoiceActionView {
    public string CreditorPublicId;
    public String ExternalId;
    public String SocialSecurityNumber;
    public String MemberNumber;
    public String MembershipCategory;
    public String FeeCategory;
    public Boolean HaveAkassa;
    public Boolean IsCreditInvoice;
    public boolean HaveIncomeInsurance;
  }
    */

  /** 
  global class CreatedView {
    public string PublicId;
  }

  global static BillectaCreateInvoice.CreatedView parse(String json) {
    return (BillectaCreateInvoice.CreatedView) System.JSON.deserialize(
      json,
      BillectaCreateInvoice.CreatedView.class
    );
  }
    */
  /*    {
  "typeName": "AkaviaInvoiceActionView",
  "additionalProperties": false,
  "type": "object",
  "properties": {
    "CreditorPublicId": {
      "type": "string",
      "format": "guid"
    },
    "ExternalId": {
      "type": "string"
    },
    "SocialSecurityNumber": {
      "type": "string"
    },
    "MemberNumber": {
      "type": "string"
    },
    "MembershipCategory": {
      "type": "string"
    },
    "FeeCategory": {
      "type": "string"
    },
    "HaveAkassa": {
      "type": "boolean"
    },
    "IsCreditInvoice": {
      "type": "boolean"
    }
  },*/
}