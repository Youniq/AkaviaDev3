global class BillectaSwish {
    
    global class SwishPaymentStatusView{
        
        Public String PaymentRequestToken;
        Public String Status;
        Public String  PaidDate;
        Public String Created;
        Public Amount  Amount;
           
          
    }

    global class Amount{
       Public String CurrencyCode;
       Public Integer Value;
       Public Double ValueForView;
    } 

    Global Class CreatedView{
        public string PublicId ;
    }
    
    global static BillectaSwish.CreatedView parse(String json) {
        return (BillectaSwish.CreatedView) System.JSON.deserialize(json, BillectaSwish.CreatedView.class);
    }

    global static BillectaSwish.SwishPaymentStatusView parseStatus(String json) {
        return (BillectaSwish.SwishPaymentStatusView) System.JSON.deserialize(json, BillectaSwish.SwishPaymentStatusView.class);
    }
}