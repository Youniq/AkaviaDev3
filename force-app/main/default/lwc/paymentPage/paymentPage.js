/**
 * @description       :
 * @author            : Håkon Kavli
 * @group             : Stretch
 * @last modified on  : 2025-03-31
 * @last modified by  : Malin Nilsson (Stretch Customer AB)
 **/
import { LightningElement, api, track, wire } from "lwc";
import { getRecord, updateRecord } from "lightning/uiRecordApi";
import { getPicklistValues } from "lightning/uiObjectInfoApi";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import { loadStyle } from "lightning/platformResourceLoader";
import { refreshApex } from "@salesforce/apex";

// Fields
import ACCOUNT_RECORDTYPE_FIELD from "@salesforce/schema/Account.RecordTypeId";
import AUTOGIROBANK_FIELD from "@salesforce/schema/Account.AutogiroBank__c";
import AUTOGIROBANKACCOUNT_FIELD from "@salesforce/schema/Account.AG_BankAccountNumber__c";
import AUTOGIROCLEARING_FIELD from "@salesforce/schema/Account.AG_BankClearingNumber__c";
import BANKIDSIGNTOKEN_FIELD from "@salesforce/schema/Account.AG_BankIDSignToken__c";
import DISTRIBUTIONMETHOD_FIELD from "@salesforce/schema/Account.DistributionMethod__c";
import EINVOICEBANK_FIELD from "@salesforce/schema/Account.EinvoiceBank__c";
import ID_FIELD from "@salesforce/schema/Account.Id";
import PAYMENTMETHOD_FIELD from "@salesforce/schema/Account.PaymentMethod__c";
import PERSONMOBILEPHONE_FIELD from "@salesforce/schema/Account.PersonMobilePhone";
import FEECATEGORY_FIELD from "@salesforce/schema/Account.FeeCategory__c";
import Id from "@salesforce/user/Id";
import ACCOUNTID_FIELD from "@salesforce/schema/User.AccountId";

// Apex Methods
import initBankIDSign from "@salesforce/apex/BillectaBankAccountHelper.initBankIDSign";
import initData from "@salesforce/apex/BillectaBankAccountHelper.initData";
import getBankAccountsStatus from "@salesforce/apex/BillectaBankAccountHelper.getBankAccountsStatus";
import getBankIDSignStatus from "@salesforce/apex/BillectaBankAccountHelper.getBankIDSignStatus";
import initGetBankAccounts from "@salesforce/apex/BillectaBankAccountHelper.initGetBankAccounts";

// Labels
import { paymentpageLabels } from "c/labels";

// Static Resources
import AkaviaCSS from "@salesforce/resourceUrl/AkaviaCSS";
import BANKID_SVG from "@salesforce/resourceUrl/bankID_logo";
import BANKID_SVG_white from "@salesforce/resourceUrl/bankID_logo_white";

export default class PaymentPage extends LightningElement {
  // Tracked private variables
  @track userAccountId;
  @track userId;
  @track account;
  @track recordTypeId;
  @track paymentMethodSelectedValue;
  @track bankAccounts = [];
  @track person;
  @track currentObj;

  // Public variables
  @api displayPageHeader;
  @api displayPageIngress;
  @api displayPageSubheader;

  // Local variables
  autogiroBank;
  autogiroBankDisplayValue;
  autoGiroPicklistValues;
  isModalOpen = false;
  autoGiroIsSelected = true;
  actualBG = false;
  actualAG = false;
  actualEinvoice = false;
  autoOpenToken;
  bankChanged;
  bankGiroIsSelected = false;
  bankHeaderIsHidden = false;
  openBankIdButtonIsDisabled = false; //false?
  data;
  debugMessage;
  distributionMethod;
  eInvoiceIsSelected;
  eInvoiceBank;
  eInvoiceBankDisplayValue;
  error;
  errorMessage;
  hasMultipleBankAccounts = false;
  hasQR = false;
  hasRedirectURL = false;
  hasValidBankAccounts = false;
  hideHelptext = false;
  INTERVALID = 1200;
  isComplete;
  isError;
  isLoading;
  isReadyForSign;
  message;
  progressAccounts; // used on setInterval to generate new QR code.
  progressSign; // used on setInterval to generate new QR code.
  publicId;
  paperInvoiceIsSelected = false;
  QR;
  redirectURL;
  selectedBankAccount;
  signButtonIsDisabled = true;
  showOpenBankId = false;
  showChangeButton = false;
  showCloseButton = true;
  getBankAccountsButtonIsDisabled = true;
  getBankAccountsButtonIsShowing = true;
  showVerifyBankidDevice = false;
  useBankidOnOtherDevice;

  labels;
  cancelCloseLabel;

  constructor() {
    super();
    this.labels = paymentpageLabels;
    this.cancelCloseLabel = this.labels.PP_Cancel;
  }

  get isFeeCatDubbelSrat() {
    return this.account.fields.FeeCategory__c.value === "Dubbelansluten SRAT";
  }

  connectedCallback() {
    loadStyle(this, AkaviaCSS);
    //you can add a .then().catch() if you'd like, as loadStyle() returns a promise
    this.BANKIDLOGO = BANKID_SVG;
    this.BANKIDLOGOWHITE = BANKID_SVG_white;
    this.userId = Id; // Retrieves  Account Id via User ID
    this.autogiroIsSelected = true;
    console.log("test", this.autogiroIsSelected);
  }

  // Import User
  @wire(getRecord, {
    recordId: "$userId",
    fields: ACCOUNTID_FIELD
  })
  wiredUser({ data, error }) {
    if (error) {
      this.setError(error, "Get User");
    } else if (data) {
      this.user = data;
      this.userAccountId = this.user.fields.AccountId.value;
    }
  }

  // Retrieves the Users Account
  @wire(getRecord, {
    recordId: "$userAccountId",
    fields: [
      ACCOUNT_RECORDTYPE_FIELD,
      DISTRIBUTIONMETHOD_FIELD,
      ID_FIELD,
      PAYMENTMETHOD_FIELD,
      FEECATEGORY_FIELD
    ],
    optionalFields: [
      AUTOGIROBANK_FIELD,
      AUTOGIROBANKACCOUNT_FIELD,
      AUTOGIROCLEARING_FIELD,
      EINVOICEBANK_FIELD,
      PERSONMOBILEPHONE_FIELD,
      BANKIDSIGNTOKEN_FIELD
    ]
  })
  wiredAccount({ data, error }) {
    if (error) {
      let message = "Unknown error";
      if (Array.isArray(error.body)) {
        message = error.body.map((e) => e.message).join(", ");
      } else if (typeof error.body.message === "string") {
        message = error.body.message;
      }
      this.dispatchEvent(
        new ShowToastEvent({
          title: "Error loading Account",
          message,
          variant: "error"
        })
      );
    } else if (data) {
      this.account = { ...data };
      this.recordTypeId = this.account.fields.RecordTypeId.value;
      if (this.account.fields.DistributionMethod__c.value) {
        console.log(this.account.fields.DistributionMethod__c.value);
        this.distributionMethod =
          this.account.fields.DistributionMethod__c.value;
        if (this.account.fields.DistributionMethod__c.value === "E-faktura") {
          this.actualEinvoice = true;
        } else {
          this.actualEinvoice = false;
        }
      }
      if (this.account.fields.PaymentMethod__c.value) {
        console.log(this.account.fields.PaymentMethod__c.value);
        this.paymentMethodSelectedValue =
          this.account.fields.PaymentMethod__c.value;
        this.paymentMethodDisplayValue =
          this.account.fields.PaymentMethod__c.displayValue; //Picklist Label (displayValue) is descriptive and more intutive to show the User frontend, then value (AG/ BG) is
      }

      //Set active Payment Method selection
      this.setActivePaymentMethod();
      this.setEinvoiceIsSelected();

      if (this.account.fields.AutogiroBank__c.value) {
        this.autogiroBank = this.account.fields.AutogiroBank__c.value;
        this.autogiroBankDisplayValue =
          this.account.fields.AutogiroBank__c.displayValue;
        this.getBankAccountsButtonIsDisabled = false;
      }
      if (this.account.fields.EinvoiceBank__c.value) {
        this.eInvoiceBank = this.account.fields.EinvoiceBank__c.value;
        this.eInvoiceBankDisplayValue =
          this.account.fields.EinvoiceBank__c.displayValue;
      }
    }
  }

  // helper method to control visibility for fields in the table
  setActivePaymentMethod() {
    switch (this.paymentMethodSelectedValue) {
      case "AG":
        console.log("AG in setActivePaymentMethod");
        this.actualAG = true;
        this.actualBG = false;
        this.autogiroIsSelected = true;
        this.bankgiroIsSelected = false;
        this.paperInvoiceIsSelected = false;
        break;
      case "BG":
        console.log("BG in setActivePaymentMethod");
        this.actualBG = true;
        this.actualAG = false;
        this.autogiroIsSelected = false;
        this.bankgiroIsSelected = true;
        this.paperInvoiceIsSelected = false;
        break;
      case "PI":
        console.log("PI in setActivePaymentMethod");
        this.actualAG = false;
        this.actualBG = false;
        this.autogiroIsSelected = false;
        this.bankgiroIsSelected = false;
        this.paperInvoiceIsSelected = true;
        break;
      default:
        break;
    }
  }

  // Retrieves the availible AutoGiro Banks for selection
  @wire(getPicklistValues, {
    recordTypeId: "$recordTypeId",
    fieldApiName: AUTOGIROBANK_FIELD
  })
  wiredPickListValue({ data, error }) {
    if (data) {
      this.autoGiroPicklistValues = data.values;
      this.error = undefined;
    }
    if (error) {
      this.error = error;
      this.pickListvalues = undefined;
    }
  }
  // Retrieves the availible eInvoice Bank options for selection
  @wire(getPicklistValues, {
    recordTypeId: "$recordTypeId",
    fieldApiName: EINVOICEBANK_FIELD
  })
  eInvoiceBankPicklistValues;

  // Retrieves the availible payment option for selection
  @wire(getPicklistValues, {
    recordTypeId: "$recordTypeId",
    fieldApiName: PAYMENTMETHOD_FIELD
  })
  paymentOptionsPicklistValues;

  // Retrieves the availible Distribution methods for selection
  @wire(getPicklistValues, {
    recordTypeId: "$recordTypeId",
    fieldApiName: DISTRIBUTIONMETHOD_FIELD
  })
  distributionMethodPicklistValues;

  updateAccount() {
    const fields = {};
    console.log("update");
    if (this.userAccountId) {
      fields[ID_FIELD.fieldApiName] = this.userAccountId;
    }
    if (this.autogiroBank !== undefined) {
      fields[AUTOGIROBANK_FIELD.fieldApiName] = this.autogiroBank;
    }
    if (this.selectedBankAccount && this.selectedBankAccount.indexOf("-") > 0) {
      fields[AUTOGIROBANKACCOUNT_FIELD.fieldApiName] =
        this.selectedBankAccount.split("-")[1];
      fields[AUTOGIROCLEARING_FIELD.fieldApiName] =
        this.selectedBankAccount.split("-")[0];
    } else if (this.selectedBankAccount === null) {
      fields[AUTOGIROBANKACCOUNT_FIELD.fieldApiName] = null;
      fields[AUTOGIROCLEARING_FIELD.fieldApiName] = null;
    }
    if (this.eInvoiceBank !== undefined) {
      fields[EINVOICEBANK_FIELD.fieldApiName] = this.eInvoiceBank;
    }
    if (this.distributionMethod !== undefined) {
      fields[DISTRIBUTIONMETHOD_FIELD.fieldApiName] = this.distributionMethod;
    }
    if (this.paymentMethodSelectedValue !== undefined) {
      fields[PAYMENTMETHOD_FIELD.fieldApiName] =
        this.paymentMethodSelectedValue;
    }
    if (
      this.currentObj !== undefined &&
      this.currentObj.Status === "Complete" &&
      this.currentObj.PublicId !== undefined
    ) {
      fields[BANKIDSIGNTOKEN_FIELD.fieldApiName] = this.currentObj.PublicId;
    }
    const recordInput = { fields };
    updateRecord(recordInput)
      .then(() => {
        // Display fresh data in the form
        console.log("then");
        return refreshApex(this.userAccountId);
      })
      .catch((error) => {
        console.log(error);
        this.dispatchEvent(
          new ShowToastEvent({
            title: "Fel vid updateringen",
            message: `${PP_UpdatePaymentInfoError1} ${PP_UpdatePaymentInfoError2} ${PP_UpdatePaymentInfoError3}`,
            variant: "error"
          })
        );
      });
  }

  // Show message about open Bank Id app in case property showOpenBankId is true and we do not have a QR code to scan/ button to display
  get doShowOpenBankId() {
    return !!this.showOpenBankId && !this.hasQR && !this.autoOpenToken;
  }

  get doShowQr() {
    return this.useBankidOnOtherDevice && this.hasQR && !!this.QR;
  }

  // Checks that user has selected to use BankId on current device and that a redirectURL has been found
  get doShowBankIdRedirectBtn() {
    if (!this.useBankidOnOtherDevice && this.hasRedirectURL) {
      // Legacy thing to check that this.hasMultipleBankAccounts, it's used when fetching bank accounts and controlling visibility of button..
      // Sign request needs to know that an account is selected and mthat the isReadyForSign is true.
      return (
        !this.hasMultipleBankAccounts ||
        (this.selectedBankAccount != null && this.isReadyForSign )
      );
    }
    return false;
  }

  openModal() {
    this.isModalOpen = true;
    this.isSuccess = false;
  }
  closeModal() {
    this.isModalOpen = false;
    this.showOpenBankId = false;
    this.hasQR = false;
    this.QR = null;
    this.resetBank();
    clearInterval(this.progressAccounts);
    clearInterval(this.progressSign);
  }
  closeModalWithUpdate() {
    this.updateAccount();
    this.isModalOpen = false;
    this.showOpenBankId = false;
    this.hasQR = false;
    this.QR = null;
    clearInterval(this.progressAccounts);
    clearInterval(this.progressSign);
  }

  submitModal() {
    this.updateAccount();
    this.isModalOpen = false;
    this.showOpenBankId = false;
    this.hasQR = false;
    this.QR = null;
    clearInterval(this.progressAccounts);
    clearInterval(this.progressSign);
  }

  handleGetAccounts() {
    this.getBankAccountsButtonIsShowing = false;
    this.showVerifyBankidDevice = true;
  }

  handleBankIdCurrDevice() {
    // false for current device
    this.useBankidOnOtherDevice = false;
    this.initData(this.useBankidOnOtherDevice);
    this.showVerifyBankidDevice = false;
  }

  handleBankIdOtherDevice() {
    // true for other device
    this.useBankidOnOtherDevice = true;
    this.initData(this.useBankidOnOtherDevice);
    this.showVerifyBankidDevice = false;
  }

  // Starts the get bank accounts process
  // initData .Input Account.Id (inv.Id)  Rerturns BillectaBankAccountHelper currentObj
  initData() {
    initData({
      recordId: this.userAccountId
    })
      .then((data) => {
        this.setCurrentObject(
          data,
          "***** Loaded BillectaBankAccountHelper Object: *****"
        );
        this.currentObj.theAccount.PaymentMethod__c =
          this.paymentMethodSelectedValue;
        this.currentObj.theAccount.AutogiroBank__c = this.autogiroBank;
        if (!this.isLoadingBankAccounts) {
          this.setLoading();
          this.initGetBankAccounts();
        }
      })
      .catch((error) => {
        console.debug(error);
      });
  }

  //initGetBankAccounts -> (Data.Status); // Returns   'Error' 'NoClient''Failed' 'Complete'
  initGetBankAccounts() {
    this.autoOpenToken = null;
    this.hasRedirectURL = false;

    initGetBankAccounts({
      currentObj: this.currentObj, //  Rerturns BillectaBankAccountHelper PublicId to be used when asking for status
      otherDevice: this.useBankidOnOtherDevice
    })
      .then((data) => {
        this.isLoadingBankAccounts = true;
        if (data.errorMessage != null) {
          this.isLoadingBankAccounts = false;
          this.isLoading = false;
          this.hideHelptext = true;
          console.debug(data.errorMessage);
          this.setErrorState();
        }
        if (data.PublicId != null) {
          console.log("we have public ID", this.showOpenBankId);
          //this.showOpenBankId = true; //We do not want to ask the user to open bank id untill we know we have gotten a PublicID back
          this.setPublicId(data.PublicId);
          console.log("we have public ID", this.showOpenBankId);
          this.setCurrentObject(
            data,
            "Retrieved response from initGetBankAccounts"
          );

          // Call every 1 seconds
          this.progressAccounts = setInterval(() => {
             if (!this.hasValidBankAccounts && !this.isError) 
             {
              this.getBankAccountsStatus();
            } else {
              clearInterval(this.progressAccounts);
              this.hasValidBankAccounts = true;
            }
          }, this.INTERVALID);
        }
      })
      .catch((error) => {
        console.debug(error);
        this.setError(error, "initGetBankAccounts");
        clearInterval(this.progressAccounts);
      });
  }

  /*
  // init BankIDSign Create Mobile BankID sign request 
  //  Test (SSN) Numbers:
  //    19800113-9297 will respond with Success after 10 seconds
  //    19700123-9297 will respond with Error after 10 seconds
  //    19600106-2626 will respond with NoClient after 2 seconds.
  */
  startBankIdSign() {
    this.signButtonIsDisabled = true;
    this.hasRedirectURL = false;
    this.openBankIdButtonIsDisabled = true; //kanske
    this.autoOpenToken = null;
    this.setWaiting();
    this.isReadyForSign = true;
    console.log("startBankIdSign currObj:", this.currentObj);

    initBankIDSign({
      currentObj: this.currentObj //  Input BillectaAccountHelper currentObj  Rerturns BillectaAccountHelper currentObj
    })
      .then((data) => {
        if (data.errorMessage != null) {
          this.isLoading = false;
          this.hideHelptext = true;
          console.debug(data.errorMessage);
          this.setErrorState();
        }

        // IF we have a public id - the transaction is ongoing -> continue
        if (data.PublicId != null) {
          this.setPublicId(data.PublicId);
          this.setCurrentObject(data, "retrieved data from initBankIdSign");

          // Call every 1 seconds
          this.progressSign = setInterval(() => {
            if (!this.isComplete) {
              this.getBankIDSignStatus();
            } else if (this.currentObj.Status === "Complete") {
              this.isWaiting = false;
              clearInterval(this.progressSign);
            }
          }, this.INTERVALID);
        }
      })
      .catch((error) => {
        console.debug(error);
        this.setError(error, "initBankIDSign");
        clearInterval(this.progressSign);
      });
  }

  // getBankIDSignStatus
  getBankIDSignStatus() {
    getBankIDSignStatus({
      obj: this.currentObj,
      PublicId: this.publicId
    })
      .then((data) => {
        this.currentObj = { ...data };
        this.handleBankIdSign();
      })
      .catch((error) => {
        clearInterval(this.progressSign);
        this.setError(error, "getBankIDSignStatus");
        console.error(error);
      });
  }

  handleBankIdSign() {
    if (!this.currentObj || this.currentObj.Status === "Failed") {
      this.setErrorState();
      this.isLoading = false;
      this.showOpenBankId = false;
      console.error("Error occured during sign", this.currentObj);
      clearInterval(this.progressSign);
    } else if (this.currentObj) {
      if (this.currentObj.Status === "Complete") {
        this.isLoading = false;
        this.isComplete = true;
        this.showOpenBankId = false;
        this.validateSubmitOK();
        this.updateAccount();
        this.setSuccess();
        clearInterval(this.progressSign);
      }
      // Not completed yet
      else {
        // Display QR code (will only be visible for desktop)
        if (this.currentObj.QR != null && this.currentObj.QR !== this.QR) {
          this.QR = this.currentObj.QR;
          this.hasQR = true;
          this.isLoading = false;
        }

        /* This will probably not be true. The autostartroken looks to be the same one as
         * retrieved from the initBankIDSign() call higher up, starting the Sign chain
         */
        if (
          this.currentObj.BankIdAutostartToken != null &&
          this.autoOpenToken !== this.currentObj.BankIdAutostartToken
        ) {
          this.autoOpenToken = this.currentObj.BankIdAutostartToken;
          this.redirectURL =
            "https://app.bankid.com/?autostarttoken=" +
            this.currentObj.BankIdAutostartToken +
            "&redirect=null";
          this.hasRedirectURL = true;
          this.isLoading = false;
          this.openBankIdButtonIsDisabled = false;
        }
      }
    }
  }

  /* Method to poll Billecta for BankAccounts, via the Apex Method getBankAccountsStatus
   * Input: BillectaAccountHelper obj and  String PublicId
   * Returns: BillectaAccountHelper currentObj
   *
   */
  getBankAccountsStatus() {
    getBankAccountsStatus({
      obj: this.currentObj,
      PublicId: this.publicId
    })
      .then((data) => {
        if (data.errorMessage) {
          console.debug(data.errorMessage);
        }
        console.debug(data.Status);
        this.setCurrentObject(data, "Data from getBankAccountsStatus:");
        this.currentObj.Status = data.Status;
        this.handleGetBankAccounts();
        // Returns   'Error' 'NoClient''Failed' 'Complete'
      })
      .catch((error) => {
        this.setError(error, "getBankAccountsStatus");
        clearInterval(this.progressAccounts);
      });
  }

  handleGetBankAccounts() {
    if (
      !this.currentObj ||
      this.currentObj.Status === "Failed" ||
      this.currentObj.Status === "Error" ||
      this.currentObj.Status === "No Client"
    ) {
      this.setErrorState();
      this.showOpenBankId = false;
      this.isLoading = false;
      clearInterval(this.progressAccounts);
    } else if (this.currentObj) {
      if (this.currentObj.Status === "Success") {
        this.hasQR = false;
        this.showOpenBankId = false;
        this.hasValidBankAccounts = true;
        this.isLoading = false;
        // if bank accounts were returned set the this.bankAccounts if they are not already set. 
        if (this.currentObj.bankAccounts && !this.bankAccounts.length) {
          this.hasMultipleBankAccounts = true;
          this.bankAccounts = this.currentObj.bankAccounts.map((element) => {
            return {
              label: `${element}`,
              value: `${element}`
            };
          });
        }

        // Only set the selected bank account if it is not already set.
        if(!this.selectedBankAccount) {
          this.selectedBankAccount =
            this.currentObj.theAccount.AG_BankAccountNumber__c;
        }
        this.isWaiting = false;

        if (this.selectedBankAccount) {
          this.signButtonIsDisabled = false;
          this.isReadyForSign = true;
        }

        clearInterval(this.progressAccounts);
        return;
      } else if (this.currentObj.Status === "Waiting") {
        this.isWaiting = true;
        if (this.currentObj.QR != null && this.currentObj.QR !== this.QR) {
          this.QR = this.currentObj.QR;
          this.hasQR = true;
          this.isLoading = false;
        }
        if (
          this.currentObj.BankIdAutostartToken != null &&
          this.currentObj.BankIdAutostartToken !== this.autoOpenToken
        ) {
          this.autoOpenToken = this.currentObj.BankIdAutostartToken;
          this.redirectURL =
            "https://app.bankid.com/?autostarttoken=" +
            this.currentObj.BankIdAutostartToken +
            "&redirect=null";
          this.hasRedirectURL = true;
          this.getBankAccountsButtonIsShowing = false;
          this.isLoading = false;
          this.openBankIdButtonIsDisabled = false;
          return;
        }
        if (!this.currentObj.QR && !this.currentObj.BankIdAutostartToken) {
          // Display message in case no QR or Autostarttoken was delivered.
          this.showOpenBankId = true;
        }
      }
    }
  }

  // Helper methods

  openBankIdApp() {
    if (windowObjectReference == null || windowObjectReference.closed) {
      this.windowObjectReference = window.open(
        this.redirectURL,
        "Open BankId",
        "noopener",
        "noreferrer"
      );
    }
    window.location.replace(this.windowObjectReference);
  }

  @api
  handleAGBankChange(event) {
    this.getBankAccountsButtonIsShowing = true;
    this.showVerifyBankidDevice = false;
    this.autogiroBank = event.target.value;
    if (this.currentObj) {
      this.currentObj.theAccount.AutogiroBank__c = this.autogiroBank;
      this.resetBank();
    }
    this.bankChanged = true;
    this.getBankAccountsButtonIsDisabled = false;
  }

  @api
  handleAGBankAccountChange(event) {
    let val = event.target.value;
    this.selectedBankAccount = val;
    this.signButtonIsDisabled = false;
    
    /* this.isReadyForSign = true; */
}
  resetBank() {
    console.log("resetBank --> False");
    this.getBankAccountsButtonIsShowing = true;
    this.QR = null;
    this.hasQR = false;
    this.autoOpenToken = null;
    this.isReadyForSign = false;
    this.hasMultipleBankAccounts = false;
    this.hasValidBankAccounts = false; 
    this.bankAccounts = [];
    this.isLoadingBankAccounts = false;
    this.getBankAccountsButtonIsDisabled = true;
    this.openBankIdButtonIsDisabled = true;
    this.hasQR = false;
    this.hasRedirectURL = false;
    this.showVerifyBankidDevice = false;
    this.useBankidOnOtherDevice = null;
  }

  setError(error, methodName) {
    let errorMessage = "";
    if (Array.isArray(error.body)) {
      errorMessage = error.body.map((e) => e.message).join(", ");
    } else if (typeof error.body.message === "string") {
      errorMessage = error.body.message;
    }
    this.errorMessage = `Error in ${methodName}: ${errorMessage}`;
    this.setErrorState();
  }

  setErrorState() {
    console.log("Set Error --> False");
    this.isLoading = false;
    this.isSuccess = false;
    this.isError = true;
    this.QR = null;
    this.autoOpenToken = null;
    this.currentObj = undefined;
    this.signButtonIsDisabled = true;
    this.openBankIdButtonIsDisabled = false;
  }
  setLoading() {
    console.log("Set Loading --> true");
    this.setWaiting();
    this.isLoadingBankAccounts = true;
    this.signButtonIsDisabled = true;
    this.getBankAccountsButtonIsDisabled = true;
    this.openBankIdButtonIsDisabled = false;
  }

  setWaiting() {
    // Disables the Autogiro picker control when true
    this.isWaiting = true;
    this.isError = false;
    this.isLoading = true;
    this.isSuccess = false;
  }

  setSuccess() {
    console.log("SetSuccess --> true");
    this.isLoading = false;
    this.isSuccess = true;
    this.isError = false;
    this.isWaiting = false;
    this.hideHelptext = true;
    this.QR = undefined;
    this.hasQR = false;
    this.isReadyForSign = false;
    this.autoOpenToken = null;
    this.hasRedirectURL = false;
    this.openBankIdButtonIsDisabled = true;
    this.showVerifyBankidDevice = false;
    this.useBankidOnOtherDevice = null;
  }

  setCurrentObject(data, debugMessage) {
    console.log("SetcurrentObject --> true");
    console.debug(debugMessage, data);
    this.currentObj = data;
    this.openBankIdButtonIsDisabled = true;
    this.getBankAccountsButtonIsDisabled = true;
  }

  setPublicId(data) {
    this.publicId = data.replaceAll('"', "");

    if (data.QR != null) {
      this.QR = data.QR;
      this.hasQR = true;
    }

    if (data.BankIdAutostartToken != null) {
      let bankIdAutostartToken = data.BankIdAutostartToken;
      this.redirectURL =
        "https://app.bankid.com/?autostarttoken=" +
        bankIdAutostartToken +
        "&redirect=null";
      this.hasRedirectURL = true;
    }
  }
  @api
  handlePaymentSelectionChange(event) {
    this.paymentMethodSelectedValue = event.target.value;
    switch (this.paymentMethodSelectedValue) {
      case "AG":
        console.log("AG in handlePaymentSelectionChange");
        this.autogiroIsSelected = true;
        this.bankgiroIsSelected = false;
        this.paperInvoiceIsSelected = false;
        this.resetBankGiroInformation();
        this.validateSubmitOK();
        console.log("AG f");
        break;
      case "BG":
        console.log("BG in handlePaymentSelectionChange");
        this.autogiroIsSelected = false;
        this.bankgiroIsSelected = true;
        this.paperInvoiceIsSelected = false;
        this.resetAutoGiroInformation();
        this.validateSubmitOK();
        console.log("BG");
        break;
      case "PI":
        console.log("PI in handlePaymentSelectionChange");
        this.autogiroIsSelected = false;
        this.bankgiroIsSelected = false;
        this.paperInvoiceIsSelected = true;
        break;
      default:
        break;
    }
  }

  @api
  handleAutogiroBankSelectionChange(event) {
    let val = event.target.value;
    this.autogiroBank = val;
  }

  @api
  handleEinvoiceBankSelectionChange(event) {
    console.log("bank" + event.target.value);
    this.eInvoiceBank = event.target.value;
    this.validateSubmitOK();
  }

  @api
  handleDistributionMethodChange(event) {
    this.distributionMethod = event.target.value;
    if (this.distributionMethod === "Post") {
      //this.paymentMethodSelectedValue = 'PI';
      console.log("handleDistributionChange");
      this.autogiroIsSelected = false;
      this.bankgiroIsSelected = true;
    }
    this.setEinvoiceIsSelected();
    this.resetAutoGiroInformation();
  }

  setEinvoiceIsSelected() {
    if (this.distributionMethod === "E-faktura") {
      this.eInvoiceIsSelected = true;
    } else {
      this.eInvoiceIsSelected = false;
    }
    this.displayBankHeader();
    this.validateSubmitOK();
  }

  resetBankGiroInformation() {
    this.distributionMethod = null;
    this.eInvoiceBank = null;
  }

  resetAutoGiroInformation() {
    this.autogiroBank = null;
    this.autogiroBankDisplayValue = null;
    this.selectedBankAccount = null;
    this.getBankAccountsButtonIsShowing = true;
  }

  hideBankHeader() {
    this.bankHeaderIsHidden = true;
  }

  displayBankHeader() {
    if (this.actualAG || this.actualEinvoice) {
      this.bankHeaderIsHidden = false;
    } else {
      this.bankHeaderIsHidden = true;
    }
  }

  get useEmptyColumn() {
    return this.bankHeaderIsHidden || !this.actualBG ? true : false;
  }

  validateSubmitOK() {
    console.log("validate");
    if (this.eInvoiceIsSelected && this.eInvoiceBank) {
      this.showCloseButton = false;
      this.showChangeButton = true;
    } else if (this.autogiroIsSelected) {
      if (this.currentObj && this.currentObj.Status === "Complete") {
        this.cancelCloseLabel = this.labels.IO_CloseModal;
      }
      this.showCloseButton = true;
      this.showChangeButton = false;
    } else if (
      this.distributionMethod === "Post" ||
      this.distributionMethod === "Kivra"
    ) {
      this.showCloseButton = false;
      this.showChangeButton = true;
    } else {
      this.showCloseButton = true;
      this.showChangeButton = false;
    }
  }

  disconnectedCallback() {
    clearInterval(this.progressAccounts);
    clearInterval(this.progressSign);
  }
}