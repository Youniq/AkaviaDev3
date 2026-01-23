/**
  @description       : Shows the latest Invoices for a logged in Experience user and let's the user pay the outstanding invoices via Swish
  @author            : Håkon Kavli @https://trailblazer.me/id/hkavli
  @group             : Stretch Engage
  @last modified on  : 2025-04-29
  @last modified by  : Malin Nilsson (Stretch Customer AB)
 **/

// Static resources
import AkaviaCSS from "@salesforce/resourceUrl/AkaviaCSS";
import SWISH_SVG from "@salesforce/resourceUrl/swish_logo_primary_RGB";

// Utils
import { getRecord, updateRecord } from "lightning/uiRecordApi";
import { LightningElement, api, wire, track } from "lwc";
import { loadStyle } from "lightning/platformResourceLoader";
import { refreshApex } from "@salesforce/apex";

// Apex Methods
import getInvoices from "@salesforce/apex/InvoiceHelper.getInvoices";
import getUnpaidInvoices from "@salesforce/apex/InvoiceHelper.getUnpaidInvoices";
import getSwishRequestStatus from "@salesforce/apex/BillectaSwishHelper.getSwishRequestStatus";
import initData from "@salesforce/apex/BillectaSwishHelper.initData";
import initSwishPayment from "@salesforce/apex/BillectaSwishHelper.initSwishPayment";

// Fields
import PAYMENTSTATUS_FIELD from "@salesforce/schema/Invoice__c.PaymentStatus__c";
import PERSONMOBILEPHONE_FIELD from "@salesforce/schema/Account.PersonMobilePhone";
import FEECATEGORY_FIELD from "@salesforce/schema/Account.FeeCategory__c";
import BILLECTAID_FIELD from "@salesforce/schema/Invoice__c.BillectaID__c";
import INVOICEID_FIELD from "@salesforce/schema/Invoice__c.Id";
import SWISHPHONE_FIELD from "@salesforce/schema/Invoice__c.Swish_Phone__c";
import EXPIRATIONDATE_FIELD from "@salesforce/schema/Invoice__c.ExpirationDate__c";
import Id from "@salesforce/user/Id";
import ACCOUNTID_FIELD from "@salesforce/schema/User.AccountId";

// Custom Labels
import { paymentpageLabels } from "c/labels";

export default class InvoiceOverwiew extends LightningElement {
  // Public variables
  @api maxRows;
  @api person;

  // @api mobileVersion = false;

  personMobilePhone;
  userAccountId;
  feeCategory;
  //@api recordId; // Invoice Id
  //@api validPhone;

  // Tracked variables
  @track currentObj; // Billecta Swish Helper object from BillectaSwishHelper
  @track invoices;
  @track unpaidInvoices;
  @track publicId;
  hasInvoices;
  hasInvoicesError = false;
  hasUnpaidInvoices;
  hasUnpaidInvError = false;
  recordId;
  // @track status;

  isAlreadyPaid = false;
  isPaid;

  // Status variables
  isModalOpen = false;
  isError = false;
  swishIsLoading;
  swishPaySuccess = false;

  invoice;
  isTrue = true;
  progress;
  componentLoading = true;

  // Constants
  INTERVALID = 5000;
  PHONEPATTERN = "^(?=.*?[1-9])[0-9()/\\-\\+\\s\\.]+$"; //  PHONEPATTERN = '\^(\+46)([0-9]{9})\$';

  // Other variables
  paymentButtonIsDisabled = true;
  row;
  swishPhone;

  // Labels in use
  labels;

  constructor() {
    super();
    this.labels = paymentpageLabels;
  }

  get showUnpaidInvSection() {
    return this.hasUnpaidInvoices || this.hasUnpaidInvError ? true : false;
  }

  connectedCallback() {
    loadStyle(this, AkaviaCSS);
    this.swishLogo = SWISH_SVG;
    this.person = Id;
  }

  @wire(getRecord, {
    recordId: "$person",
    fields: ACCOUNTID_FIELD
  })
  wiredUser({ data, error }) {
    if (error) {
      this.setError(error, "Get User");
      console.debug(`Error in Get User: ${error}`);
    } else if (data) {
      this.user = data;
      this.userAccountId = this.user.fields.AccountId.value;
      //  console.debug("Account Id : " + this.userAccountId);
      this.checkButtonState();
    }
  }

  // Import single invoice
  @wire(getRecord, {
    recordId: "$recordId",
    fields: INVOICEID_FIELD,
    SWISHPHONE_FIELD,
    BILLECTAID_FIELD,
    PAYMENTSTATUS_FIELD,
    EXPIRATIONDATE_FIELD
  })
  wiredInvoice(data, error) {
    if (error) {
      this.setError(error, "Get Invoice");
    } else if (data) {
      this.invoice = data;
    }
  }

  // Import list of Invoices for current user
  @wire(getInvoices, {
    person: "$userAccountId",
    maxRows: "$maxRows"
  })
  getInvoicesList({ data, error }) {
    if (data) {
      this.hasInvoicesError = false;
      if (data.length === 0) {
        this.hasInvoices = false;
      } else {
        this.invoices = this.processInvoiceData(data);
        this.error = undefined;
        this.hasInvoices = true;
      }
    } else if (error) {
      this.hasInvoicesError = true;
      console.debug("Error in getInvoicesList", error);
    }
    // remove spinner if the result isn't undefined.
    if (data || error) {
      this.componentLoading = false;
    }
  }

  @wire(getUnpaidInvoices, { person: "$userAccountId" })
  wiredUnpaidList({ data, error }) {
    if (error) {
      this.hasUnpaidInvError = true;
      console.log("Error in getUnpaidInvoices:", error);
    } else if (data) {
      this.hasUnpaidInvError = false;

      if (data.length === 0) {
        this.hasUnpaidInvoices = false;
      } else {
        this.unpaidInvoices = this.processInvoiceData(data);
        this.error = undefined;
        this.hasUnpaidInvoices = true;
      }
    }
  }

  // Get Phone number from Account
  @wire(getRecord, {
    recordId: "$userAccountId",
    fields: [PERSONMOBILEPHONE_FIELD, FEECATEGORY_FIELD]
  })
  wiredAccount({ data, error }) {
    if (error) {
      this.setError(error, "Get Account");
      console.debug("Error in Get Account:", error);
    } else if (data) {
      this.account = data;
      // console.debug(data);
      this.personMobilePhone = this.account.fields.PersonMobilePhone.value;
      this.feeCategory = this.account.fields.FeeCategory__c.value;
      this.checkButtonState();
    }
  }

  get isFeeCatDubbelSrat() {
    return this.feeCategory === "Dubbelansluten SRAT";
  }

  updateInvoice(swishPhone) {
    this.swishPhone = swishPhone;
    //if (allValid) {
    // console.debug("Is Valid");

    const fields = {};
    fields[INVOICEID_FIELD.fieldApiName] = this.currentInvoice.Id;
    fields[SWISHPHONE_FIELD.fieldApiName] = this.swishPhone;
    fields[BILLECTAID_FIELD.fieldApiName] = this.currentInvoice.BillectaID__c;
    if (this.isPaid) {
      fields[PAYMENTSTATUS_FIELD.fieldApiName] = this.isPaid;
    }

    const recordInput = { fields };
    updateRecord(recordInput)
      .then(() => {
        console.debug(
          `Updated invoice ${this.recordId} / ${this.currentInvoice.Id} \nwith phone number ${this.swishPhone} \nPayment Status: ${this.invoice.PaymentStatus__c}`
        );
        // Display fresh data in the form
        return refreshApex(this.recordId);
      })
      .catch((error) => {
        console.debug(`Error in Update Invoice:`);
        console.debug(error);
      });
  }

  initData() {
    initData({ recordId: this.recordId })
      .then((data) => {
        this.setCurrentObject(data, "initData");
        this.currentInvoice = data.theInvoice;
        console.debug(
          this.currentInvoice.Swish_Phone__c === this.personMobilePhone
        );

        if (this.currentInvoice.Swish_Phone__c !== this.personMobilePhone) {
          this.currentInvoice.Swish_Phone__c = this.personMobilePhone;
          /*          this.updateInvoice(this.personMobilePhone);
          setTimeout(() => {
            this.initData();
          }, 1000); // init recursively after  ms to get updated phone number
         return; */
        }
        // Load with updated phone number
        this.initSwishPayment();
      })
      .catch((error) => {
        this.setError(error, "initSwishPayment");
      });
  }

  /* Input BillectaSwishHelper currentObj  Returns BillectaSwishHelper currentObj
   * Returns String Public Id OR error message
   * 46701234567 will response Declined
   * 46707654321 will response Error
   * Other numbers will return "Paid"
  
  */

  initSwishPayment() {
    initSwishPayment({
      currentObj: this.currentObj
    })
      .then((data) => {
        this.setLoading();
        if (
          data.includes(
            `"Message":"Swish-betalningar är inte tillåtet på betald faktura"`
          )
        ) {
          this.setAlreadyPaid();
          this.updateInvoice(this.personMobilePhone);
          console.debug(data);
        } else if (
          data.includes("Failed") ||
          data.includes("Failed with message")
        ) {
          console.debug(data);
          this.setError(data, "initSwishPayment");
        } else {
          this.publicId = data;
          console.debug(`Success: ${this.publicId}`);

          this.progress = setInterval(() => {
            if (this.currentObj.Status === "Paid") {
              clearInterval(this.progress);
              console.debug(`Paid: ${this.currentObj.Status}`);
              this.swishPaySuccess = true;
            } else if (this.currentObj.Status === "Failed") {
              clearInterval(this.progress);
              console.debug(`Failed`);
              this.setError(this.currentObj.errorMessage, "initSwishPayment");
            } else {
              console.debug(`Run get status: ${this.currentObj.Status}`);
              this.getSwishRequestStatus();
            }
          }, 10000);
        }
      })
      .catch((error) => {
        console.debug("Error in initSwishPayment:");
        console.debug(error);
        this.setError(error, "initSwishPayment");
        this.response = {
          SocialSecurityNumber: "19800113-9297",
          MembershipCategory: "Yrkesverksam",
          MemberNumber: "800092",
          IsCreditInvoice: false,
          HaveIncomeInsurance: false,
          HaveAkassa: true,
          FeeCategory: "Fullbetalande",
          ExternalId: "0013O00000WeStSQAV",
          CreditorPublicId: "4d9023ee-8d43-4e61-a6fc-96cce27cbefe"
        };
      });
  }
  /* 
  // Returns different statuses depending on phone number
  //  46701234567 will response Declined  --> a0F3O000005VaRzUAK
  //  46707654321 will response Error
  //  Other numbers will response Paid
  
  */
  getSwishRequestStatus() {
    getSwishRequestStatus({
      obj: this.currentObj,
      PublicId: this.publicId
    })
      .then((data) => {
        console.debug("getSwishRequestStatus");
        console.debug(data);
        this.setCurrentObject(data, "getSwishRequestStatus");
        if (!this.swishPaySuccess) {
          this.handleSwishRequestStatus();
        } // Handles response from Apex Method
      })
      .catch((error) => {
        console.debug("Error in getSwishRequestStatus:");
        console.debug(error);
        this.setError(error, "getSwishRequestStatus");
      });
  }

  handleSwishRequestStatus() {
    console.debug(`Status: ${this.currentObj.Status}`);
    if (!this.currentObj || this.currentObj.Status === "Failed") {
      this.setError(null, "handleSwishRequestStatus");
    } else if (this.currentObj) {
      if (this.currentObj.Status === "Paid") {
        this.setSuccess();
        this.isPaid = "Betald";
        this.updateInvoice(this.personMobilePhone);
      }
    }
  }

  handlePayment() {
    this.setLoading();

    console.debug("Start Payment on: " + this.recordId);
    this.initData();
  }

  /**
   * Triggered from child component InvoicesTable
   * @param {event object} event
   */
  handleOpenModal(event) {
    this.recordId = event.detail.invoiceId;
    // console.debug(`Invoice Id: ${this.recordId}`);
    this.isModalOpen = true;
  }

  closeModal() {
    // to close modal set isModalOpen tarck value as false
    this.reset();
    this.isModalOpen = false;
  }
  submitModal() {
    // to close modal set isModalOpen tarck value as false
    //Add your code to call apex method or do some processing
    this.reset();
    this.isModalOpen = false;
  }

  // Helper Methods

  // Used in  initData and getSwishRequestStatus to set BillectaSwishHelper currrentObj
  setCurrentObject(data, debugMessage) {
    console.debug(`Response from ${debugMessage}:`);
    console.debug(data);
    this.currentObj = data;
    this.currentObj.Status = data.Status;
    console.debug(`Status: ${this.currentObj.Status}`);
  }

  setError(error, methodName) {
    console.error("An error occured: ", error);
    let errorMessage = "";
    if (error !== null) {
      if (typeof error === "string") {
        errorMessage = error;
        console.debug(`Error: ${error}: ${errorMessage}`);
      } else if (Array.isArray(error.body)) {
        errorMessage = error.body.map((e) => e.message).join(", ");
      } else if (typeof error.body.message === "string") {
        errorMessage = error.body.message;
      }
    }

    this.errorMessage = `Error in ${methodName}: ${errorMessage}`;
    console.debug(this.errorMessage);
    this.showError();
  }
  showError() {
    this.swishIsLoading = false;
    // this.isWaiting = false;
    this.swishPaySuccess = false;
    this.isError = true;
    // this.spinner = false;
  }

  setLoading() {
    this.errorMessage = undefined;
    this.swishIsLoading = true;
    // this.isWaiting = true;
    // this.spinner = true;
    this.paymentButtonIsDisabled = true;
    this.swishPaySuccess = false;
    this.isError = false;
  }
  setSuccess() {
    this.errorMessage = undefined;
    this.hasQR = false;
    this.swishIsLoading = false;
    // this.isWaiting = false;
    this.isError = false;
    this.swishPaySuccess = true;
    // this.spinner = false;
  }

  setAlreadyPaid() {
    this.isPaid = "Betald";
    this.isAlreadyPaid = true;
    this.errorMessage = undefined;
    this.hasQR = false;
    this.swishIsLoading = false;
    // this.isWaiting = false;
    this.isError = false;
    this.swishPaySuccess = false;
    // this.spinner = false;
  }

  reset() {
    this.isAlreadyPaid = false;
    this.swishPaySuccess = false;
    this.isError = false;
    this.paymentButtonIsDisabled = false;
  }

  // Handle phone input
  @api
  handleChange(event) {
    let val = event.detail.value;
    if (this.validatePhoneNumber(val)) {
      this.personMobilePhone = val;
      this.checkButtonState();
    }
  }
  // Helper Methods
  /**
   *
   * @param {Array<Invoice__c>} invoices
   * @returns {Array<Invoice__c>}
   * Loops invoices and cleans Preview URLs and flags paid/unpaid invoices
   */
  processInvoiceData(invoices) {
    const urlRegex = /(https?:\/\/[^ "]*)/;

    const invoiceRows = invoices.map((row) => {
      let newRow = { ...row };
      if (row.InvoiceLink__c) {
        // clean the URL by removing wrapping (e.g. <a> or "external link")
        newRow.InvoiceLink__c = row.InvoiceLink__c.match(urlRegex)[1]; //errors
      }
      // Suppress the Pay button if the Invoice allready is payed
      if (["Ej betald","Delbetald"].includes(row.PaymentStatus__c)) {
        newRow.displayPaymentButton = true;
      } else {
        newRow.displayPaymentButton = false;
      }
      return newRow;
    });
    return invoiceRows;
  }

  validatePhoneNumber(input) {
    if (input != null && input.match(this.PHONEPATTERN)) {
      return true;
    }
    return false;
  }

  @api
  checkButtonState() {
    if (this.personMobilePhone) {
      const allValid = [
        ...this.template.querySelectorAll("lightning-input")
      ].reduce((validSoFar, inputCmp) => {
        inputCmp.reportValidity();
        return validSoFar && inputCmp.checkValidity();
      }, true);

      if (allValid) {
        this.paymentButtonIsDisabled = false;
        return true;
      } else if (!allValid) {
        this.paymentButtonIsDisabled = true;
        return false;
      }
    } else {
      this.paymentButtonIsDisabled = true;
      return false;
    }
  }

  @api
  handleTest(event) {
    let val = event.detail.value;
    this.recordId = val;
  }

  // // Methods to sort Invoice List
  // sort(e) {
  //   if (this.sortedColumn === e.currentTarget.dataset.id) {
  //     this.sortedDirection = this.sortedDirection === "desc" ? "asc" : "desc";
  //   } else {
  //     this.sortedDirection = "desc";
  //   }
  //   let reverse = this.sortedDirection === "desc" ? 1 : -1;
  //   let table = JSON.parse(JSON.stringify(this.invoices));
  //   table.sort((a, b) => {
  //     return a[e.currentTarget.dataset.id] > b[e.currentTarget.dataset.id]
  //       ? 1 * reverse
  //       : -1 * reverse;
  //   });
  //   this.sortedColumn = e.currentTarget.dataset.id;
  //   this.invoices = table;
  // }

  // sortDate(a, b) {
  //   return (
  //     new Date(a.ExpirationDate__c).getTime() -
  //     new Date(b.ExpirationDate__c).getTime()
  //   );
  // }

  // sortDateColumn(e) {
  //   if (this.sortedColumn === e.currentTarget.dataset.id) {
  //     this.sortedDirection = this.sortedDirection === "desc" ? "asc" : "desc";
  //   } else {
  //     this.sortedDirection = "desc";
  //   }
  //   let reverse = this.sortedDirection === "desc" ? 1 : -1;
  //   let table = JSON.parse(JSON.stringify(this.invoices));
  //   table.sort((a, b) => {
  //     return new Date(a[e.currentTarget.dataset.id]).getTime() >
  //       new Date(b[e.currentTarget.dataset.id]).getTime()
  //       ? 1 * reverse
  //       : -1 * reverse;
  //   });
  //   this.sortedColumn = e.currentTarget.dataset.id;
  //   this.invoices = table;
  // }
}