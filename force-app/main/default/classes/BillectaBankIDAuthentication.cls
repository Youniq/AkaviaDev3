/**
 * @description       :
 * @author            : Malin Nilsson (Stretch Customer AB)
 * @group             :
 * @last modified on  : 2024-04-29
 * @last modified by  : Malin Nilsson (Stretch Customer AB)
 **/
global class BillectaBankIDAuthentication {
  global class BankIdAuthenticationStatusView {
    public String Status; // "OutstandingTransaction","NoClient","Started","UserSign","UserReq","Complete","Error"
    public String SSN;
    public String ReferenceToken; //Used to retrieve status
    public String AutoStartToken;
    public String GivenName;
    public String Surname;
    public String IpAddress;
    public String Name;
    public String QR; // added 29 April 2024 - probably not used by Akavia as the BankIdAuthenticationStatusView is always triggered by Akavia support, causing a BankId Auth at member.
    public String NotAfter;
    public String NotBefore;
    public String OcspResponse;
    public String Signature;
    public String Created;
    public String HintCode; // "unknown","outstandingTransaction","noClient","started","userSign","expiredTransaction","certificateErr","userCancel","cancelled","startFailed"
    public String Details; // Not used per info from Billecta. Maybe some extra info is available here but nothing important for making Bank Id sign.
  }

  global class BankIdAuthenticationRequestView {
    public String CreditorPublicId;
    public String SSN;
    public Boolean TokenStartRequired;
  }

  global static BillectaBankIDAuthentication.BankIdAuthenticationStatusView parseResponse(
    String json
  ) {
    return (BillectaBankIDAuthentication.BankIdAuthenticationStatusView) System.JSON.deserialize(
      json,
      BillectaBankIDAuthentication.BankIdAuthenticationStatusView.class
    );
  }
}