import { LightningElement, track, wire } from "lwc";
import { getRecord, getFieldValue } from "lightning/uiRecordApi";
import Id from "@salesforce/user/Id";
import { Employment, Account } from "c/models";
import { employmentService } from "c/services";
import { loadStyle } from "lightning/platformResourceLoader";
// Fields
import ACCOUNTID_FIELD from "@salesforce/schema/User.AccountId";
import CONTACT_ID from "@salesforce/schema/User.ContactId";
import ACCOUNT_SELFEMPLOYEDEVAL_FIELD from "@salesforce/schema/Account.SelfemployedEvaluating__c";
import ACCOUNT_UNEMPLOYED_FIELD from "@salesforce/schema/Account.UnEmployed__c"; // "Arbetssökande, checkbox"
// Static Resources
import AkaviaStyles_Community from "@salesforce/resourceUrl/AkaviaStyles_Community";
import { employmentLabels } from "c/labels";

export default class MyEmployer extends LightningElement {
  loading; // boolean
  userId; // string
  usrAccountId; // string, loaded from a wire
  usrContactId; // string, loaded from a wire
  noEmployment; // boolean
  showChangeEmployerModal; // boolean indicating if modal is open or not
  showConfirmManagerChangeModal; // boolean indicating if modal is open or not
  managerChangeDone; // boolean indicating if manager change is done or not
  showManagerChangeErr; // boolean indicating to show error or not after attempt to change the is Manager value
  showError; // boolean
  labels;
  @track employment; // Object holding information regarding users employment
  @track usrAccount; // user account object, loaded from a wire. Used for reading/updating 'Egenföretagare under behandling' status.

  constructor() {
    super();
    this.labels = employmentLabels;
    this.loading = true;
    this.showError = false;
    this.userId = Id;
    this.showChangeEmployerModal = false;
    this.showConfirmManagerChangeModal = false;
    this.managerChangeDone = false;
    this.noEmployment = false;
    this.usrAccount = {};
  }

  connectedCallback() {
    loadStyle(this, AkaviaStyles_Community);
  }

  get hasEmployment() {
    return this.employment &&
      !this.noEmployment &&
      !this.usrAccount.selfEmployedIsEvaluating
      ? true
      : false;
  }

  /**
   * User has no employment, isn't marked as unemployed (arbetssökande) and isn't marked as self employed evaluating.
   */
  get hasNoEmployment() {
    return (
      this.noEmployment &&
      !this.usrAccount.isUnemployed &&
      !this.usrAccount.selfEmployedIsEvaluating
    );
  }

  /**
   * User has no employment, is marked as unemployed (arbetssökande) and isn't marked as self employed evaluating.
   */
  get isUnemployed() {
    return (
      this.noEmployment &&
      this.usrAccount.isUnemployed &&
      !this.usrAccount.selfEmployedIsEvaluating
    );
  }

  /**
   * Hide Update isManager if noEmployment is true and there's no loading going on.
   */
  get hideManagerSection() {
    return this.noEmployment || this.loading ? true : false;
  }

  get isManagerHeader() {
    return this.employment?.isManager
      ? this.labels.EP_headerEndAsManager
      : this.labels.EP_headerStartAsManager;
  }

  get isManagerTooltip() {
    return this.employment?.isManager
      ? this.labels.EP_tooltipEndAsManager
      : this.labels.EP_tooltipStartAsManager;
  }

  get disabledButton() {
    return this.loading ||
      this.showChangeEmployerModal ||
      this.showConfirmManagerChangeModal
      ? true
      : false;
  }

  /**
   * Wired function to retrieve users Account Id and Contact Id.
   * @param {object} result
   */
  @wire(getRecord, {
    recordId: "$userId",
    fields: [ACCOUNTID_FIELD, CONTACT_ID]
  })
  wiredUser(result) {
    if (result.error) {
      console.error("Something went wrong", result.error);
      this.showError = true;
      this.loading = false;
    } else if (result.data) {
      this.usrAccountId = getFieldValue(result.data, ACCOUNTID_FIELD);
      this.usrContactId = getFieldValue(result.data, CONTACT_ID);
    }
  }

  @wire(getRecord, {
    recordId: "$usrAccountId",
    fields: [ACCOUNT_SELFEMPLOYEDEVAL_FIELD, ACCOUNT_UNEMPLOYED_FIELD]
  })
  wiredAccount(result) {
    if (result.error) {
      console.error(
        "Something went wrong while fetching fields on member account through wire. Continuing without disruption.",
        result.error
      );
      this.getAccountEmployment(this.usrAccountId);
    } else if (result.data) {
      // set initial values on the user account property.
      this.usrAccount = new Account(
        this.usrAccountId,
        null,
        getFieldValue(result.data, ACCOUNT_SELFEMPLOYEDEVAL_FIELD),
        getFieldValue(result.data, ACCOUNT_UNEMPLOYED_FIELD)
      );
      this.getAccountEmployment(this.usrAccountId);
    }
  }

  /**
   * Initiates the component
   * Get the current users active employment from Salesforce.
   * @param {string} accId
   */
  async getAccountEmployment(accId) {
    if (!accId) {
      console.error("Error: Users Account Id couldn't be fetched.");
      this.showError = true;
      this.loading = false;
      return;
    }

    const empArr = await employmentService.getCurrEmployment(accId);

    if (empArr && empArr.length) {
      const emp = empArr[0]; // There can only be one active employment.

      const employerName = emp.Workplace__r?.Parent?.Name || this.labels.EP_unknown;

      // Build employment object - GUI immediately updates.
      this.employment = new Employment(
        emp.Id,
        emp.Workplace__r?.Name,
        emp.Workplace__c,
        emp.Workplace__r?.Parent?.OrganisationNumber__c,
        employerName,
        emp.Manager__c,
        emp.EndDate
      );
      this.noEmployment = false;
    } else if (empArr && !empArr.length) {
      // Unemployed
      /* Avoiding null exception. Initializing this.employment here in order to be able to open the modal dialog.
       * It takes an property of the Employment obj as argument/attribute. */
      this.employment = new Employment();
      this.noEmployment = true;
    } else if (!empArr) {
      this.showError = true;
    }

    this.loading = false;
  }

  handleChangeEmployer() {
    this.showChangeEmployerModal = true;
  }

  handleConfirmManagerChange() {
    this.showConfirmManagerChangeModal = true;
  }

  /**
   * Triggered from the ManagerChangeModal
   */
  async handleChangeIsManager() {
    const empObj = {
      Person__c: this.usrAccountId,
      StartDate__c: new Date().toJSON(),
      Workplace__c: this.employment?.workplaceId,
      Manager__c: !this.employment?.isManager // change the isManager value
    };

    const success = await employmentService.saveNewEmployment(empObj);
    // Indicates that the confirmation is done to the Markup, to display the next slot.
    this.managerChangeDone = true;

    if (success) {
      // Update this.employment obj in order to show change instantly in UI.
      this.employment.isManager = empObj.Manager__c;
    } else {
      this.showManagerChangeErr = true;
    }
  }

  // Triggered from childcomponent, changeEmployerModal.
  async handleNewEmployment(evt) {
    if (evt.detail.employment) {
      // Updates GUI to show info from the new employment.
      this.employment = { ...evt.detail.employment };
      this.noEmployment = false;
      //await this.getAccountEmployment(this.usrAccountId);
    } else if (evt.detail.selfemploymentsubmitted) {
      // in case user reports self employment.
    } else {
      // When user reports unemployment.
      this.employment = new Employment();
      this.noEmployment = true;
    }
    this.usrAccount.SelfemployedEvaluating__c =
      evt.detail.selfemploymentsubmitted;
    this.usrAccount.UnEmployed__c = evt.detail.unemployedSubmitted; // Wether or not to displays member as 'Arbetssökande' in gui.
  }

  handleModalClose() {
    this.showChangeEmployerModal = false;
    this.showConfirmManagerChangeModal = false;
    // reset the managerChangeDone state so that the modal works again even if page is not reloaded
    this.managerChangeDone = false;
  }
}