/**
 * @description       :
 * @author            : Malin Nilsson (Stretch Customer AB)
 * @group             :
 * @last modified on  : 2024-05-27
 * @last modified by  : Malin Nilsson (Stretch Customer AB)
 **/
global class BillectaCreateInvoice {
  public string CreditorPublicId;
  public String ExternalId;

  @AuraEnabled
  public String SocialSecurityNumber;
  @AuraEnabled
  public String MemberNumber;
  @AuraEnabled
  public String MembershipCategory;
  @AuraEnabled
  public String FeeCategory;
  @AuraEnabled
  public Boolean HaveAkassa;
  public Boolean IsCreditInvoice;
  @AuraEnabled
  public boolean HaveIncomeInsurance;
  @AuraEnabled
  public Date PeriodStart; // First day of a month, to use if creating retroactive invoices
  public Date PeriodEnd; // Akavia implements this like periodStart-periodEnd is always one month

  // TODO - Replace with above in order to have them @aurahandled and be able to populate them from flow
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

  global class CreatedView {
    public string PublicId;
  }

  global static BillectaCreateInvoice.CreatedView parse(String json) {
    return (BillectaCreateInvoice.CreatedView) System.JSON.deserialize(
      json,
      BillectaCreateInvoice.CreatedView.class
    );
  }
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