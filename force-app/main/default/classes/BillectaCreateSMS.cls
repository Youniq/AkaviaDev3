global class BillectaCreateSMS {
    
    Global CreatedView CreatedView;
    
    global class SMS {
        public string CreditorPublicId;
        public string ReceiverPhone;
        public string Message;
        public string CountryCode;
    }

    global class CreatedView {
        public string PublicId;
    }

}