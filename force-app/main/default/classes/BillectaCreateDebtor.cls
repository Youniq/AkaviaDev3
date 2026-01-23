global class BillectaCreateDebtor {
    
    global CreatedView CreatedView;
    global DebtorView DebtorView;

    Global Class DebtorView{
  		public String DebtorPublicId; //Required on update
        public String CreditorPublicId; //Required
        public String DebtorExternalId; 
        public String OrgNo;
        public String Name; //Required
        public String Attention;
        public String CareOf;
        public String Address;
        public String Address2;
        public String ZipCode;
        public String City;
        public String CountryCode;
        public String CitizenshipCountryCode;
        public String Phone;
        public String Email;
        public String ContactName;
        public String ContactEmail;
        public String VatNumber;
        public String DebtorNo;
        public String GLN;
        public Boolean IsActive;
        public Boolean ProtectedIdentity;
        public Boolean Protectedmaildelivery;
        public String DebtorType; 			//Allowed values: Private, Company, Undefined
        public String Intermediator; 
        public String EInvoiceBank; 
        public String Notes;
        public DebtorSelfInvoiceInfoView DebtorSelfInvoiceInfo;
        public DefaultActionConfigView DefaultActionConfig;
        public Autogiro Autogiro;
        public String[] CreditCards;
        public String Created;
    }
    
    global class Autogiro {
        public Boolean Active;
        public String AccountNo;
        public String ClearingNo;
        public String Stage;
        public String PayerNumber;
        public String PaymentServiceSupplier;
        public String AutogiroFirstWithdrawalDate;
    }
    
  
    global class DebtorSelfInvoiceInfoView{
        public String NextSelfInvoiceNumber ;
        public String PaymentMethod; // Allowed values : "BankGiro","PlusGiro","BankAccount","IBAN"
        public String BankgiroNo;
        public String PlusgiroNo;
        public String AccountNo;
        public String ClearingNo;
        public String IBAN;
        public String BIC;
        public boolean ApprovedCompanyTax;
    }    
    
    global class DefaultActionConfigView{
        public Boolean ActivateDefaultActionConfigOverride;
        public String StartDebtCollectionActionLevel; // Allowed values : "BankGiro","PlusGiro","BankAccount","IBAN"
        public String DeliveryMethod;
        public String CommunicationLanguage;
        public Integer PaymentTermsInDays;
        public Integer DebtCollectionPaymentTermsInDays ;
        public Double InterestPercentage;
        public Integer InvoicePaymentTermsInDays;
        public String InterestType;
        public Integer InterestStartInDaysAfterDueDate;
        public String ReasonForHigherInterest;
        public String OurReference;
        public Integer NumberOfReminders;
        public String CurrencyCode;
        public Integer SendInvoiceToDebtCollectionAfterDays;
        public Boolean SendInvoiceToDebtCollection;
        public Boolean IncludePdfInEmail;
        public Boolean SendReminderInvoice;
        public Integer SendReminderInvoiceDaysAfterDueDate;
        public Double InvoiceFee;
        public Double ReminderInvoiceFee;
        public Integer SendByMailIfEmailNotViewedInDays;
        public Boolean SendByMailIfEmailNotViewedInDaysEnabled;
        public Integer ReminderInvoicePaymentTermsInDays;
        public String InvoiceComment;
    }
    
    
    Global Class CreatedView{
        public string PublicId;
    }

    global static BillectaCreateDebtor.CreatedView parse(String json) {
        return (BillectaCreateDebtor.CreatedView) System.JSON.deserialize(json, BillectaCreateDebtor.CreatedView.class);
    }

    global static BillectaCreateDebtor.DebtorView parseDebtor(String json) {
        return (BillectaCreateDebtor.DebtorView) System.JSON.deserialize(json, BillectaCreateDebtor.DebtorView.class);
    }

}