import { LightningElement, wire, track } from "lwc";
import { getFieldValue, getRecord } from "lightning/uiRecordApi";
import { getPicklistValues } from "lightning/uiObjectInfoApi";
import { loadStyle } from "lightning/platformResourceLoader";
import { CurrentPageReference } from "lightning/navigation";
import { Account, Case } from "c/models";
import { accountService, caseService } from "c/services";
import { pubsub, getDateString, scrollToTop } from "c/utils";

// Static Resources
import AkaviaStyles_Community from "@salesforce/resourceUrl/AkaviaStyles_Community";
import CASE_CATEGORY_FIELD from "@salesforce/schema/Case.CategoryCommunity__c";
import { caseLabels } from "c/labels";

// Fields
import Id from "@salesforce/user/Id";
import USER_CONTACTID_FIELD from "@salesforce/schema/User.ContactId";
import USER_ACCOUNTID_FIELD from "@salesforce/schema/User.AccountId";
import USER_LANG_FIELD from "@salesforce/schema/User.LanguageLocaleKey";
import ACCOUNT_PERSONEMAIL_FIELD from "@salesforce/schema/Account.PersonEmail";

// Constants
const CAT_REDUCEDFEE = "Reducerad avgift";

export default class ContactForm extends LightningElement {
  // private properties
  labels; // Object
  loading; // boolean
  errorMessage; // string
  errorOnEmailSave; // boolean
  userInfoPromise; // promise used when initially loading users contactId and accountId
  categoriesPromise;
  settingsPromise; // promised used when initially loading metadata settings for the component.
  settings; // The actual metadata settings used by the component.
  initOk; // boolean telling if initiation load was ok.
  showUploadFiles; // boolean indicating if upload files frame is displayed.
  showFinishedMsg; // boolean indicating if "Thank you" message is displayed.
  userId; // string
  usrContactId; // string, loaded from a wire
  usrAccountId; // string, loaded from a wire
  userLang; // string, loaded from a wire
  catPicklistValues; // category picklist values
  selFromDate; // string, for selected From Date.
  minToDate; // string, for minimum accepted to date. Based on selected value in From Date.
  files; // uploaded files.
  usrAccount; // user account object. Used for updating users email address.
  @track caseToCreate; // case object, gets populated with information entered in the form.
  @track newCase; // case object, fetched after insert in database. Need new case Id and other info.
  @track selCatConfig; // A object containing the config setting matching the selected category from picklist.

  get acceptedFormats() {
    return [".pdf", ".png", ".jpeg", ".txt", ".docx", ".jpg", ".xlsx"];
  }

  constructor() {
    super();
    this.labels = caseLabels;
    this.loading = true;
    this.firstWireLoaded = false;
    this.userId = Id;
    this.catPicklistValues = [];
    this.caseCreated = false;
    this.showFinishedMsg = false;
    this.caseToCreate = new Case();
    this.usrAccount = {};
  }

  async connectedCallback() {
    loadStyle(this, AkaviaStyles_Community);

    this.settingsPromise = this.getComponentSettings();

    // kicks in when initiation information has loaded, successfully or not.
    Promise.all([
      this.userInfoPromise,
      this.settingsPromise,
      this.categoriesPromise
    ]).then(
      // Resolved
      () => {
        // Display picklist options wich have a matching mdt setting.
        this.catPicklistValues = this.catPicklistValues.filter((pick) => {
          let match = this.settings.some(
            (setting) => setting.CategoryApiName__c === pick.value
          );
          return match;
        });
        console.log("Initial load successful.");
        this.loading = false;
        this.initOk = true;
      },
      // Rejected
      () => {
        console.log("Initial load failed");
        this.loading = false;
        this.initOk = false;
        this.errorMessage = this.labels.CP_errorGeneral;
      }
    );
  }

  /**
   * Needed for cross component communication through pubsub.
   */
  @wire(CurrentPageReference) pageRef;

  /**
   * Wired function to retrieve users Contact Id and users Account Id.
   * @param {object} result
   */
  @wire(getRecord, {
    recordId: "$userId",
    fields: [USER_CONTACTID_FIELD, USER_ACCOUNTID_FIELD, USER_LANG_FIELD]
  })
  wiredUser(result) {
    if (result.error) {
      console.error("Something went wrong", result.error);
      this.errorMessage = this.labels.CP_errorGeneral;
      this.userInfoPromise = Promise.reject("User info failed.");
    } else if (result.data) {
      this.usrContactId = getFieldValue(result.data, USER_CONTACTID_FIELD);
      this.usrAccountId = getFieldValue(result.data, USER_ACCOUNTID_FIELD);
      this.userLang = getFieldValue(result.data, USER_LANG_FIELD);
      this.userInfoPromise = Promise.resolve();
    }
  }

  @wire(getRecord, {
    recordId: "$usrAccountId",
    fields: [ACCOUNT_PERSONEMAIL_FIELD]
  })
  wiredAccount(result) {
    if (result.error) {
      console.error(
        "Something went wrong while fetching your email adress. Continuing without disruption.",
        result.error
      );
    } else if (result.data) {
      this.usrAccount = new Account(
        this.usrAccountId,
        getFieldValue(result.data, ACCOUNT_PERSONEMAIL_FIELD)
      );
    }
  }
  // Commenting away this as categories are collected from the metadata type now.
  @wire(getPicklistValues, {
    recordTypeId: "012000000000000AAA", //master record type, works independently of environment.
    fieldApiName: CASE_CATEGORY_FIELD
  })
  setPicklistValues({ error, data }) {
    if (error) {
      console.error(`ERROR in setPicklistValues`, error);
      this.categoriesPromise = Promise.reject("Picklist categories failed.");
    } else if (data) {
      this.catPicklistValues = data.values;
      this.categoriesPromise = Promise.resolve();
    }
  }

  async getComponentSettings() {
    this.settings = await caseService.getActivePortalQuickCaseSettingRecords();
    if (this.settings == null) {
      let errMsg =
        "Could not load component settings. Either there are no records or something went wrong.";
      console.error(errMsg);
      this.settingsPromise = Promise.reject(errMsg);
    }

    this.settingsPromise = Promise.resolve();
  }

  /**
   * All categories but ReducedFee, RegisterExport and DataPortabiblity
   */
  get ifDefaultForm() {
    return (
      !this.ifReducedFee &&
      this.selCatConfig &&
      !this.selCatConfig.NoInputFromUser__c
    );
  }

  get ifReducedFee() {
    return this.selCatConfig &&
      this.selCatConfig.CategoryApiName__c === CAT_REDUCEDFEE
      ? true
      : false;
  }

  get ifUserLangSV() {
    return this.userLang === "sv";
  }

  get displayBottomInfoSV() {
    return (
      this.userLang === "sv" &&
      this.selCatConfig &&
      this.selCatConfig.BottomInformationSV__c &&
      this.selCatConfig.BottomInformationSV__c.length > 0
    );
  }

  get displayBottomInfoEN() {
    return (
      this.userLang !== "sv" &&
      this.selCatConfig &&
      this.selCatConfig.BottomInformationEN__c &&
      this.selCatConfig.BottomInformationEN__c.length > 0
    );
  }

  get btnLabel() {
    if (this.ifDefaultForm) {
      if (!this.showUploadFiles) {
        return this.labels.CP_btnNext;
      }
      return this.labels.CP_btnFinish;
    }
    return this.labels.CP_btnSend;
  }

  /**
   * sets initial value for the "min" attribute on datePicker "fromDate"
   * The date must not be earlier than first day in next month. Examples:
   * If today is 28th feb, the date accepts 1st of march.
   * If today is 1st feb, the date accepts 1st of march.
   */
  get minFromDate() {
    const now = new Date();
    const minFromDate = new Date(now.getFullYear(), now.getMonth() + 1, 1, 12);
    return getDateString(minFromDate);
  }

  get disableToDate() {
    return this.selFromDate ? false : true;
  }

  // sets value for the "min" attribute on datePicker "toDate", it's dependent on what was selected in the "fromDate" picker.
  // The date must be at least the first day in next month after what was selected in fromDate. If it's 28th feb selected as fromDate, the date accepts 1st of may.
  calcMinToDate() {
    const fromDate = new Date(this.selFromDate);
    const year = fromDate.getFullYear();
    const month = fromDate.getMonth() + 2; // Two months after the selected fromDate

    // Calculate the last day of the month
    const lastDayOfMonth = new Date(year, month + 1, 0).getDate();

    const minToDate = new Date(year, month, lastDayOfMonth);
    return getDateString(minToDate);
}

  /**
   * Validates input fields
   * @param {array} inputFields
   * @returns true or false depending on all fields are valid.
   */
  checkInputValid(inputFields) {
    const allValid = inputFields.reduce((validSoFar, field) => {
      field.reportValidity();
      return validSoFar && field.checkValidity();
    }, true);
    return allValid;
  }

  /**
   * Adds metadata specific for certain category to this.case object.
   * @param {array} allInputFields
   */
  addCatSpecificDataToCase(allInputFields) {
    let property;

    switch (true) {
      case this.selCatConfig.NoInputFromUser__c: {
        // Update object to be added to SF. This category does not take any inputs from end-user.
        this.caseToCreate = {
          ...this.caseToCreate,
          Subject: this.selCatConfig.CategoryApiName__c,
          Description: this.selCatConfig.Description__c
        };
        return true;
      }
      case this.ifDefaultForm: {
        allInputFields.forEach((field) => {
          // the data-field/dataset attribute value in HTML corresponds to the Case fields.
          property = field.dataset.field;
          this.caseToCreate = { ...this.caseToCreate, [property]: field.value };
          //return true;
        });
        return true;
      }
      case this.ifReducedFee: {
        let motivation, salary, from, to;

        allInputFields.forEach((field) => {
          // data "data-field" attribute on input field holds info reg what category the field is specific for.
          property = field.dataset.field;

          if (property === "reducedFeeMotivation") {
            motivation = field.value;
          } else if (property === "reducedFeeSalary") {
            salary = field.value;
          } else if (property === "reducedFeeFromDate") {
            from = field.value;
          } else if (property === "reducedFeeToDate") {
            to = field.value;
          }
        });

        // Update object to be added to SF
        this.caseToCreate = {
          ...this.caseToCreate,
          Subject: this.selCatConfig.CategoryApiName__c,
          Description: `${this.labels.CP_labelMotivation}: ${motivation} \n  ${this.labels.CP_labelIncome}: ${salary} \n  ${this.labels.CP_labelFromDate}: ${from} \n  ${this.labels.CP_labelToDate}: ${to}`
        };
        return true;
      }
      default: {
        break; // do nothing
      }
    }
    return false;
  }

  /**
   * Adds metadata to the case object before creating case record in SF
   * The field values are either the same for all types of cases or they're defined in the custom metadata record (this.selCatConfig).
   */
  async addCommonDataToCase() {
    const recTypeId = await caseService.getRecordTypeByDeveloperName(
      this.selCatConfig.RecordTypeDeveloperName__c
    );

    this.caseToCreate = {
      ...this.caseToCreate,
      ContactId: this.usrContactId,
      Origin: "Portal",
      Priority: this.selCatConfig.Priority__c,
      Reason: this.selCatConfig.Reason__c,
      Type: this.selCatConfig.Type__c,
      CategoryCommunity__c: this.selCatConfig.CategoryApiName__c,
      RecordTypeId: recTypeId
    };
  }

  /**
   * Resets all input fields
   * @param {object[]} allInputFields
   */
  resetInputFields(allInputFields) {
    this.selCatConfig = undefined;
    this.selFromDate = undefined;
    this.minToDate = undefined;
    allInputFields.forEach((field) => {
      field.value = undefined;
    });
  }

  /**
   * the accountCases component listens for this. It triggers a refresh of all listed cases so the new case appears on top.
   */
  notifySiblingComponentOfUpdate() {
    pubsub.fireEvent(this.pageRef, "newcaseadded");
  }

  /**
   * Function checks if email adress has changed, and if so - updates Account object with new email.
   * @param {string} inputEmailVal - text field input value on the email field.
   */
  async processUserEmail(inputEmailVal) {
    if (
      inputEmailVal.toLowerCase() !==
      this.usrAccount.PersonEmail.toLocaleLowerCase()
    ) {
      this.usrAccount.PersonEmail = inputEmailVal;
      const result = await accountService.editAccount(this.usrAccount);

      if (!result) {
        // Displays an error together with the closing frame.
        this.errorOnEmailSave = true;
      }
    }
  }

  /**
   * Function which collects data from input fields and submits a Case record.
   * @param {object[]} caseFields - object array with all fields related to a Case record
   * @returns true or false depending on if case submit is successful or not
   */
  async submitCase(caseFields) {
    if (!(await this.addCatSpecificDataToCase(caseFields))) {
      this.errorMessage = this.labels.CP_errorGeneral;
      return false;
    }

    await this.addCommonDataToCase();
    if (!(await caseService.addNewCase(this.caseToCreate))) {
      this.errorMessage = this.labels.CP_errorGeneral;
      return false;
    }

    return true;
  }

  /**
   * Event fired when selected category changes.
   * @param {object} evt
   */
  handleInput(evt) {
    this.errorMessage = undefined;
    const prop = evt.currentTarget.dataset.field;
    if (prop === "category") {
      // Filter out the one configuration setting matching the picked category.
      this.selCatConfig = this.settings.filter((s) => {
        return s.CategoryApiName__c === evt.detail.value;
      })[0];

      if (!this.selCatConfig) {
        // Det här borde inte inträffa men har fått detta felet någon gång. Förmodligen pga cacheade värden mellan miljöer eller liknande. MEn vet inte säkert.
        this.errorMessage = this.labels.CP_errorUnsupportedCat;
        console.error(
          "There is no matching metadata setting for the selected category."
        );
      }
    }
  }

  /**
   * Event fired when selected From Date changes.
   * @param {object} evt
   */
  handleSelFromDate(evt) {
    this.selFromDate = evt.target.value;
    this.minToDate = this.calcMinToDate(); // dependent on this.selFromDate
  }

  /**
   * Function callback on file upload has finished. Connected to File uploader lightning component.
   * @param {object} event
   */
  handleUploadFinished(event) {
    // Get the list of uploaded files
    if (!this.files) {
      this.files = [];
    }
    this.files = [...event.detail.files, ...this.files];
  }

  /**
   * Function triggered on button click for "Next/Send/Finish"
   * @returns
   */
  async handleClick() {
    this.errorMessage = null;
    // User has the file uploader display and here user should only be able to 'Finish' the Case creation.
    if (this.ifDefaultForm && this.showUploadFiles) {
      this.notifySiblingComponentOfUpdate();
      this.showFinishedMsg = true;
      scrollToTop();
    } else {
      // Validate input fields
      this.loading = true;
      const caseFields = [...this.template.querySelectorAll(".caseInput")];
      const emailField = [...this.template.querySelectorAll(".emailInput")];
      const allFields = [...caseFields, ...emailField];

      if (!this.checkInputValid(allFields)) {
        this.loading = false;
        return;
      }

      // Update users email if changed
      await this.processUserEmail(emailField[0].value);

      // Add case
      if (await this.submitCase(caseFields)) {
        // Using Id and CaseNumber from new case. Hence creating case above and fetching it here.
        this.newCase = await caseService.getNewestCaseByAccount(
          this.usrAccountId
        );

        if (this.ifDefaultForm && !this.showUploadFiles) {
          // Only display error if show upload file screen is expected next.
          if (!this.newCase) {
            this.errorMessage = this.labels.CP_errorFileUploadView;
          } else {
            // Show upload file component if we have the newCase object (need its id).
            this.showUploadFiles = true;
          }
        } else {
          this.notifySiblingComponentOfUpdate();
          this.showFinishedMsg = true;

          // reset all inputs so that a new case can't hold old values by mistake.
          this.resetInputFields(allFields);
          scrollToTop();
        }
      }
      this.loading = false;
    }
  }
}