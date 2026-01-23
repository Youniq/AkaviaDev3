/**
 * @description       :
 * @author            : Malin Nilsson (Stretch Customer AB)
 * @group             :
 * @last modified on  : 2024-04-29
 * @last modified by  : Malin Nilsson (Stretch Customer AB)
 **/
global class BillectaBankIDSign {
  global class BankIdSignStatusView {
    public string Status; // "OutstandingTransaction","NoClient","Started","UserSign","UserReq","Complete","Error"
    public String SSN;
    public String ReferenceToken; //Used to retrieve status
    public String AutoStartToken;
    public String GivenName;
    public String Surname;
    public String IpAddress;
    public String Name;
    public String QR; // // added 29 April 2024
    public String NotAfter;
    public String NotBefore;
    public String OcspResponse;
    public String Signature;
    public String Created;
    public String HintCode; // "unknown","outstandingTransaction","noClient","started","userSign","expiredTransaction","certificateErr","userCancel","cancelled","startFailed"
  }

  global class BankIdSignRequestView {
    public string CreditorPublicId;
    public String SSN;
    public String UserMessage;
    public String UserNonVisibleData;
    public Boolean TokenStartRequired; // Used in order to use SäkerStart flow in Billecta before SäkerStart has been inforced by law (1 may 2024)
  }

  global static BillectaBankIDSign.BankIdSignStatusView parse(String json) {
    return (BillectaBankIDSign.BankIdSignStatusView) System.JSON.deserialize(
      json,
      BillectaBankIDSign.BankIdSignStatusView.class
    );
  }
}