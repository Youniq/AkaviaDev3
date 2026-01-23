/**
 * @description       :
 * @author            : Malin Nilsson (Stretch Customer AB)
 * @group             :
 * @last modified on  : 2025-07-02
 * @last modified by  : Malin Nilsson (Stretch Customer AB)
 **/
public class BillectaEncodeJSON {
  public static Blob encodeCreateDebtor(Account acc, String creditorId) {
    BillectaCreateDebtor.DebtorView newDebtor = new BillectaCreateDebtor.DebtorView();

    if (acc.BillectaID__c != null) {
      newDebtor.DebtorPublicId = acc.BillectaID__c;
    } else {
      newDebtor.DebtorPublicId = null;
    }
    newDebtor.CreditorPublicId = creditorId; //Required
    newDebtor.DebtorExternalId = acc.Id;
    newDebtor.OrgNo =
      acc.SocialSecurityNumber__c.left(8) +
      '-' +
      acc.SocialSecurityNumber__c.right(4);
    newDebtor.Name = acc.FirstName + ' ' + acc.LastName; //Required
    newDebtor.Attention = null;
    newDebtor.CareOf = acc.CurrentCOAdress__c;
    newDebtor.Address = acc.CurrentStreetAdress__c;
    newDebtor.Address2 = null;
    newDebtor.ZipCode = acc.CurrentZipCode__c;
    newDebtor.City = acc.CurrentCity__c;
    newDebtor.CountryCode = acc.CurrentCountryCode__c;
    newDebtor.CitizenshipCountryCode = null;
    newDebtor.Phone = acc.PersonMobilePhone;
    newDebtor.Email = acc.PersonEmail;
    newDebtor.ContactName = null;
    newDebtor.ContactEmail = null;
    newDebtor.VatNumber = null;
    newDebtor.DebtorNo = acc.MemberNumber__c;
    newDebtor.GLN = null;
    newDebtor.IsActive = true;
    newDebtor.ProtectedIdentity = acc.ProtectedIdentity__c;
    newDebtor.Protectedmaildelivery = acc.ProtectedIdentity__c;
    newDebtor.DebtorType = null; //Allowed values: Private, Company, Undefined
    newDebtor.Intermediator = null;
    newDebtor.Notes = null;
    newDebtor.DebtorSelfInvoiceInfo = null;
    newDebtor.EInvoiceBank = null;
    //
    newDebtor.DefaultActionConfig = new BillectaCreateDebtor.DefaultActionConfigView();
    newDebtor.DefaultActionConfig.DeliveryMethod = acc.DistributionMethod__c;

    // Handle payment method configuration
    if (acc.PaymentMethod__c == 'AG') {
        configureAutogiro(newDebtor, acc);
    } else {
        configureNonAutogiroDelivery(newDebtor, acc);
    }

    String jsonBody = JSON.serialize(newDebtor, true);
    return Blob.valueOf(jsonBody);
    }
 

  public static Blob encodeUpdateDebtor(
    Account acc,
    BillectaCreateDebtor.DebtorView oldDebtor,
    Boolean updPaymentMethod
  ) {
    oldDebtor.DebtorExternalId = acc.Id;
    oldDebtor.OrgNo =
      acc.SocialSecurityNumber__c.left(8) +
      '-' +
      acc.SocialSecurityNumber__c.right(4);
    oldDebtor.Name = acc.FirstName + ' ' + acc.LastName; //Required
    oldDebtor.CareOf = acc.CurrentCOAdress__c;
    oldDebtor.Address = acc.CurrentStreetAdress__c;
    oldDebtor.ZipCode = acc.CurrentZipCode__c;
    oldDebtor.City = acc.CurrentCity__c;
    oldDebtor.CountryCode = acc.CurrentCountryCode__c;
    oldDebtor.Phone = acc.PersonMobilePhone;
    oldDebtor.Email = acc.PersonEmail;
    oldDebtor.DebtorNo = acc.MemberNumber__c;
    oldDebtor.ProtectedIdentity = acc.ProtectedIdentity__c;
    oldDebtor.Protectedmaildelivery = acc.ProtectedIdentity__c;
    if (updPaymentMethod) {
      //Autogiro // E-faktura // Kivra // Post

      if (acc.PaymentMethod__c == 'AG') {
        configureAutogiro(oldDebtor, acc);
      } else if (acc.PaymentMethod__c != 'AG') {
        configureNonAutogiroDelivery(oldDebtor, acc);
      }
    }

    String jsonBody = json.serialize(oldDebtor);
    Blob jsonAsBlob = blob.valueOf(jsonBody);
    return jsonAsBlob;
  }

    /**
    * @description Configure Autogiro payment method
    * @author Malin Nilsson (Stretch Customer AB) | 2025-05-27 
    * @param debtor - Billecta debtor view
    * @param acc - Account from SF  
    **/
    private static void configureAutogiro(BillectaCreateDebtor.DebtorView debtor, Account acc) {
        debtor.EInvoiceBank = null; // clean
        if (debtor.DefaultActionConfig != null) {
          debtor.DefaultActionConfig.ActivateDefaultActionConfigOverride = false; // clean
        }
        // If Autogiro is not set, set it
        if (debtor.Autogiro == null) {
          debtor.Autogiro = new BillectaCreateDebtor.Autogiro();
        }

        debtor.Autogiro.Active = true;
        debtor.Autogiro.Stage = 'Pending';

        // If bank account and clearing number are set, set them
         if (
          acc.AG_BankAccountNumber__c != null &&
          acc.AG_BankClearingNumber__c != null
        ) {
          debtor.Autogiro.AccountNo = acc.AG_BankAccountNumber__c;
          debtor.Autogiro.ClearingNo = acc.AG_BankClearingNumber__c;
          debtor.Autogiro.PayerNumber = acc.SocialSecurityNumber__c;
          debtor.Autogiro.PaymentServiceSupplier = acc.AutogiroBank__c;
        }
    }


    /**
    * @description Configure non-Autogiro delivery method (E-Faktura, Kivra or Postal)
    * @author Malin Nilsson (Stretch Customer AB) | 2025-05-27 
    * @param debtor - Billecta debtor view
    * @param acc - Account from SF
    **/
    private static void configureNonAutogiroDelivery(BillectaCreateDebtor.DebtorView debtor, Account acc) {
        debtor.Autogiro = null; // clean
        if (acc.DistributionMethod__c == 'E-Faktura') {
            if (debtor.DefaultActionConfig != null) {
              debtor.DefaultActionConfig.ActivateDefaultActionConfigOverride = false; // clean
            }
            debtor.EInvoiceBank = acc.EinvoiceBank__c;
        } 
        else if(acc.BillectaID__c != null && (BillectaUtils.isDefaultDeliveryMethodKivra(acc) || acc.DistributionMethod__c == 'Kivra')) {
            // If debtor already exists, and default delivery method is Kivra, set delivery method to Kivra
            debtor.EInvoiceBank = null;
            if (debtor.DefaultActionConfig == null) {
              debtor.DefaultActionConfig = new BillectaCreateDebtor.DefaultActionConfigView();
            }
            debtor.DefaultActionConfig.ActivateDefaultActionConfigOverride = true;
            debtor.DefaultActionConfig.DeliveryMethod = 'Kivra';
        } else {
          // Set delivery method to Mail (postal) for non-E-Faktura and non-Kivra, also used for initial debtor create. payment mehthod/delivery method is updated to members liking after initial create.
          debtor.EInvoiceBank = null;
          if (debtor.DefaultActionConfig == null) {
            debtor.DefaultActionConfig = new BillectaCreateDebtor.DefaultActionConfigView();
          }
          debtor.DefaultActionConfig.ActivateDefaultActionConfigOverride = false;
          debtor.DefaultActionConfig.DeliveryMethod = 'Mail'; // First send Mail for debtor create, then it will later on be set Kivra (as default) if distribution method hasnot been chnaged
        }
    }

  public static blob encodeAkaviaInvoiceActionView(
    Account acc,
    Boolean incomeInsurance,
    String creditorId
  ) {
    BillectaCreateInvoice.AkaviaInvoiceActionView newInvoice = new BillectaCreateInvoice.AkaviaInvoiceActionView();

    newInvoice.CreditorPublicId = creditorId;
    newInvoice.ExternalId = acc.Id;
    newInvoice.SocialSecurityNumber =
      acc.SocialSecurityNumber__c.left(8) +
      '-' +
      acc.SocialSecurityNumber__c.right(4);
    newInvoice.MemberNumber = acc.MemberNumber__c;
    newInvoice.MembershipCategory = acc.MembershipCategory__c;
    newInvoice.FeeCategory = acc.FeeCategory__c;
    newInvoice.HaveAkassa = acc.UnemploymentFundThroughAkavia__c;
    newInvoice.IsCreditInvoice = false;
    newInvoice.HaveIncomeInsurance = incomeInsurance;

    String jsonBody = json.serialize(newInvoice, true);
    Blob jsonAsBlob = blob.valueOf(jsonBody);
    return jsonAsBlob;
  }

  public static blob encodeAkaviaRetroactiveInvoice(
    Account acc,
    BillectaCreateInvoice newRetroActiveInv,
    String creditorId
  ) {
    // Most fee-related invoice information is populated from screen flow.
    //Below we fill person related info and creditorId for Billecta
    newRetroActiveInv.CreditorPublicId = creditorId;
    newRetroActiveInv.ExternalId = acc.Id;
    newRetroActiveInv.SocialSecurityNumber =
      acc.SocialSecurityNumber__c.left(8) +
      '-' +
      acc.SocialSecurityNumber__c.right(4);
    newRetroActiveInv.MemberNumber = acc.MemberNumber__c;
    newRetroActiveInv.IsCreditInvoice = false;

    String jsonBody = json.serialize(newRetroActiveInv, true);
    Blob jsonAsBlob = blob.valueOf(jsonBody);
    return jsonAsBlob;
  }

  public static blob encodeSMS(Account acc, String creditorId) {
    BillectaCreateSMS.SMS newSMS = new BillectaCreateSMS.SMS();

    newSMS.CreditorPublicId = creditorId;
    newSMS.ReceiverPhone = acc.PersonMobilePhone;
    newSMS.Message = System.Label.Billecta_SMS;
    newSMS.CountryCode = null;

    String jsonBody = json.serialize(newSMS, true);
    Blob jsonAsBlob = blob.valueOf(jsonBody);
    return jsonAsBlob;
  }

  public static blob encodeBankIDRequest(String creditorId, String SSN) {
    BillectaBankIDSign.BankIdSignRequestView newRequest = new BillectaBankIDSign.BankIdSignRequestView();

    newRequest.CreditorPublicId = creditorId;
    newRequest.SSN = SSN;
    newRequest.UserMessage = System.Label.Billecta_BankIdSignMessage;
    newRequest.UserNonVisibleData = null;
    newRequest.TokenStartRequired = true;

    String jsonBody = json.serialize(newRequest, true);
    Blob jsonAsBlob = blob.valueOf(jsonBody);
    return jsonAsBlob;
  }

  public static blob encodeBankIDAuthenticationRequest(
    String creditorId,
    String SSN
  ) {
    BillectaBankIDAuthentication.BankIdAuthenticationRequestView newRequest = new BillectaBankIDAuthentication.BankIdAuthenticationRequestView();

    newRequest.CreditorPublicId = creditorId;
    newRequest.SSN = SSN;
    newRequest.TokenStartRequired = null;

    String jsonBody = json.serialize(newRequest, true);
    Blob jsonAsBlob = blob.valueOf(jsonBody);
    return jsonAsBlob;
  }
}