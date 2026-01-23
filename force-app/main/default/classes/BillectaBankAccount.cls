//Hejhej hej 
Global without sharing class BillectaBankAccount {

    global Class BankAccountRequestView{
        public string PublicId;
        Public string Bank;
        Public String SSN; 
        Public String QR; 
        Public String Status; 
        Public List<BankAccountView> AccountNumbers;
        Public String BankIdAutostartToken;
        Public Boolean IsBankIdAutostartTokenRequired;
        Public String FailureMessage;
        Public String FailureCode;   
    }
    
    Global class BankAccountView{
        Public String XNumber;
        Public String ClearingNo;
        Public String AccountNo;
        Public String Name;
        Public String Type;
        Public String AutogiroCompatible;  //Approved, Unapproved, Unknown
     //   Public Double Balance;
     //   Public String Iban;
     //   Public String HolderName;
    }

    Global Class CreatedView{
        public string PublicId ;
    }

    global static BillectaBankAccount.CreatedView parse(String json) {
        return (BillectaBankAccount.CreatedView) System.JSON.deserialize(json, BillectaBankAccount.CreatedView.class);
    }

    global static BillectaBankAccount.BankAccountRequestView parseStatus(String json) {
        return (BillectaBankAccount.BankAccountRequestView) System.JSON.deserialize(json, BillectaBankAccount.BankAccountRequestView.class);
    }


}