import { LightningElement, api, track } from "lwc";
import { employmentService, caseService, accountService } from "c/services";
import { createEnum, getYesterday } from "c/utils";
import { employmentLabels } from "c/labels";
import { Employment, Account } from "c/models";
import { loadStyle } from "lightning/platformResourceLoader";
// Static Resources
import AkaviaStyles_Community from "@salesforce/resourceUrl/AkaviaStyles_Community";

export default class ChangeEmployerModal extends LightningElement {
  // Public properties (inherited)
  @api usrContactId; // Id of users Contact record
  @api activeEmploymentId; // Id of Employment record
  @api usrAccountId; // user account object. Used for updating Account field "Egenföretagare under behandling"
  @api usrAccountSelfempEval;
  @api usrUnemployed; // True if user is marked as unemployed (arbetssökande)

  // Private properties
  _steps; // object to keep track of which step/frame is active in the wizard.
  activeIndex; // holding index of active step (int)
  doSubmit; // boolean - keeping track of if submittal is expected or not.
  loading; // boolean for when to show the loading spinner.
  selIsManager; // true/false depending on users choise.
  selWorkplaceId; // accountId for selected workplace;
  inputEmployer = { name: "", address: "" }; // holds info of employer user eneters when enabling "can't find my employer"
  inputWpAddress; // holds value for workplace adress user enters when enabling can't find my workplace.
  childValidationError; // holds true/false after validating input fields on child components.
  errorMessage;
  @track selEmployer; // account for selected new employer.
  updateObj;
  usrAccount; // obj to hold api usr account info.
  newEmploymentId; // save employmentId to this var when new employment is created.

  /**
   * state object, keeps track of selections made by user in the modal (bad naming "state" I know.)
   */
  @track state = {
    selEmployment: "",
    missingEmployer: false,
    missingWorkplace: false,
    employmentValsEnum: createEnum([
      "updateEmployer",
      "selfEmployed",
      "unemployed",
      "notWorking"
    ]),

    get isUpdateEmployer() {
      return !!(this.selEmployment === this.employmentValsEnum.updateEmployer);
    },
    get isSelfEmployed() {
      return !!(this.selEmployment === this.employmentValsEnum.selfEmployed);
    },
    get isUnemployed() {
      return !!(this.selEmployment === this.employmentValsEnum.unemployed);
    },

    get isNotWorking() {
      return !!(this.selEmployment === this.employmentValsEnum.notWorking);
    }
  };

  constructor() {
    super();
    this.loading = false;
    this.doSubmit = false;
    this.childValidationError = false;
    this.errorMessage = "";
    this.labels = employmentLabels;
    this.updateObj = { employment: null, caseData: null, member: null };

    // Initiates the _steps object. Step one is the first
    this._steps = {
      one: { index: 1, active: true },
      two: { index: 2, active: false },
      three: { index: 3, active: false },
      four: { index: 4, active: false },
      five: { index: 5, active: false }
    };
    this.activeIndex = 1;
  }

  connectedCallback() {
    loadStyle(this, AkaviaStyles_Community);
    this.setModalFocus();
    this.usrAccount = new Account(
      this.usrAccountId,
      null,
      this.usrAccountSelfempEval,
      this.usrUnemployed
    );
  }

  /**
   * Handles the movement from one step/frame to the next.
   */
  set steps(newIndex) {
    const copySteps = { ...this._steps };

    Object.keys(copySteps).forEach((key) => {
      const currStep = copySteps[key];
      if (currStep.index === newIndex) {
        currStep.active = true;
        this.activeIndex = newIndex;
      } else {
        currStep.active = false;
      }
    });

    this._steps = { ...copySteps };
  }

  /**
   * Gets the steps object
   */
  get steps() {
    return this._steps;
  }

  get showSearchEmployer() {
    //return this.loading || this.state.missingEmployer ? false : true;
    return (this.selEmployer && this.loading) || this.state.missingEmployer
      ? false
      : true;
  }

  get showPickWorkplace() {
    return this.loading || this.state.missingWorkplace ? false : true;
  }

  /**
   * Checks on how far in the wizard user is
   */
  get progress() {
    const stepsLength = Object.keys(this._steps).length;
    return `${this.activeIndex}/${stepsLength}`;
  }

  /**
   * Keeps track of when to display the 'previous' button to go backwards.
   */
  get showPrevButton() {
    return this.steps.three.active && !this.state.missingEmployer
      ? true
      : false;
  }

  /**
   * Keeps track of when to change buttons to "Close" button instead of Next button
   */
  get showCloseButton() {
    switch (true) {
      case this.steps.two.active && this.state.isUnemployed:
      case this.steps.two.active && this.state.isNotWorking:
      case this.steps.two.active && this.state.isSelfEmployed:
      case this.steps.three.active && this.state.missingEmployer:
      case this.steps.four.active && this.state.missingWorkplace:
      case this.steps.five.active:
        return true;
      default:
        return false;
    }
  }

  /**
   * Gets Available options in radio btn of first page in wizard.
   */
  get employmentOptions() {
    return [
      {
        label: this.labels.EP_ChangeEmployer_radioUpdateEmployer,
        value: this.state.employmentValsEnum.updateEmployer,
        id: "1"
      },
      {
        label: this.labels.EP_ChangeEmployer_radioSelfEmployed,
        value: this.state.employmentValsEnum.selfEmployed,
        id: "2"
      },
      {
        label: this.labels.EP_ChangeEmployer_radioUnemployed,
        value: this.state.employmentValsEnum.unemployed,
        id: "3"
      },
      {
        label: this.labels.EP_ChangeEmployer_radioNotWorking,
        value: this.state.employmentValsEnum.notWorking,
        id: "4"
      }
    ];
  }

  /**
   * Get options for  Manager boolean value.
   */
  get managerOptions() {
    return [
      { label: this.labels.EP_ChangeEmployer_radioYes, value: "1" },
      { label: this.labels.EP_ChangeEmployer_radioNo, value: "0" }
    ];
  }

  setModalFocus() {
    const modalElm = this.template.querySelector(".akavia-modal-focus");
    if (modalElm) {
      modalElm.focus();
    }
  }

  /**
   * Event receiver for when user selects an employment option.
   * @param {event object} event
   */
  handleEmploymentPick(event) {
    this.state.selEmployment = event.detail.value;
  }

  /**
   * Event receiver for when user selects isManager yes/no
   * @param {event object} event
   */
  handleIsManagerPick(event) {
    this.selIsManager = !!(event.detail.value === "1");
  }

  /**
   * Is triggered from the searchEmployer component.
   * @param {event object} event
   */
  handleSelectedEmployer(event) {
    this.selEmployer = event.detail.employer;
  }

  /**
   * Is triggered from the pickWorkplace component.
   * @param {event object} event
   */
  handleSelectedWorkplace(event) {
    this.selWorkplaceId = event.detail.workplaceId;
  }

  /**
   * Triggered from serchEmployer and pickWorkplace component if a service call throws an error.
   * @param {event object} event
   */
  handleChildError(event) {
    if (event.detail.hasError) {
      this.errorMessage = this.labels.EP_errorGeneral;
    }
  }

  /**
   * Toggles display of content
   * @param {event object} evt
   */
  handleToggle(evt) {
    const targetId = evt.target.id;

    // On toggling "can't fint employer" on step 2
    if (targetId.indexOf("toggle_miss_employer") === 0) {
      this.state.missingEmployer = evt.detail.checked;
    }
    // Toggling "can't find my workplace" on step 3.
    else if (targetId.indexOf("toggle_miss_workplace") === 0) {
      this.state.missingWorkplace = evt.detail.checked;
    }

    // Remove any validation errrors connected to SearchEmployer/Pick workplace component, becuase now user might fill in the form for missing employer/missing workplace
    this.childValidationError = false;
  }

  /**
   * Saves input values to the private properties
   * @param {event object} evt
   */
  handleCompanyInput(evt) {
    const targetId = evt.target.id;

    if (targetId.indexOf("company_name_input") === 0) {
      // when user can't find employer, company name input.
      this.inputEmployer.name = evt.target.value;
    } else if (targetId.indexOf("company_address_input") === 0) {
      // when user can't find employer, company address input.
      this.inputEmployer.address = evt.target.value;
    } else if (targetId.indexOf("wp_adress_input") === 0) {
      // when user can't find workplace, workplace address input.
      this.inputWpAddress = evt.target.value;
    }
  }

  /**
   * Sends event to parent about new employment
   */
  notifyParentOfNewEmployment() {
    let newEmployment, selfEmployedSubmitted, unemployedSubmitted;
    if (this.state.isUpdateEmployer) {
      // Buildning object to immediately (without page refresh) update GUI on parent - myEmployer component.
      newEmployment = new Employment(
        this.newEmploymentId,
        null,
        this.selWorkplaceId,
        this.selEmployer.OrganisationNumber__c,
        this.selEmployer.Name,
        this.selIsManager,
        null
      );
      selfEmployedSubmitted = false;
      unemployedSubmitted = false;
    } else if (this.state.isUnemployed) {
      newEmployment = null;
      selfEmployedSubmitted = false;
      unemployedSubmitted = true;
    } else if (this.state.isNotWorking) {
      newEmployment = null;
      selfEmployedSubmitted = false;
      unemployedSubmitted = false;
    } else if (this.state.isSelfEmployed) {
      newEmployment = null;
      selfEmployedSubmitted = true; // Adds an info message saying that self employment is under evaluation.
      unemployedSubmitted = false;
    }

    const newEmploymentEvent = new CustomEvent("newemployment", {
      detail: {
        employment: newEmployment,
        selfemploymentsubmitted: selfEmployedSubmitted,
        unemployedSubmitted: unemployedSubmitted
      }
    });
    this.dispatchEvent(newEmploymentEvent);
  }

  /**
   * Builds an object literal of all values needed for a new Case record.
   * The keys corresponds to the Case object in SF.
   * @param {array} recordType
   * @returns object
   */
  getNewCaseObject(recordType) {
    let descr, subj;

    if (this.state.missingEmployer) {
      // Can't find employer
      subj = this.labels.EP_ChangeEmployer_caseMissingEmployerSubject;
      descr = `${this.labels.EP_ChangeEmployer_caseMissingEmployerDescr} ${this.inputEmployer.name} - ${this.inputEmployer.address}.`;
    } else if (this.state.missingWorkplace) {
      // Can't find workplace
      subj = this.labels.EP_ChangeEmployer_caseMissingWorkplaceSubject;
      descr = `${this.labels.EP_ChangeEmployer_caseMissingWorkplaceDescr_1} ${this.selEmployer.Name} - Org.num ${this.selEmployer.OrganisationNumber__c} ${this.labels.EP_ChangeEmployer_caseMissingWorkplaceDescr_2} ${this.inputWpAddress}`;
    } else if (this.state.isSelfEmployed) {
      // User is self employed
      subj = this.labels.EP_ChangeEmployer_caseSelfEmployedSubject;
      descr = this.labels.EP_ChangeEmployer_caseSelfEmployedDescr;
    }

    return {
      CategoryCommunity__c: "Övrigt",
      ContactId: this.usrContactId,
      Description: descr,
      Origin: "Portal",
      Priority: "Medium",
      RecordTypeId: recordType[0].Id, // I know I only have one record in the array.
      Status: "Registrerad",
      Subject: subj,
      Type: "Fråga"
    };
  }

  /***
   * Calls caseService to retrieve the recordTypeId for a Service Case
   * Builds a case object literal
   * Saves a new record from the object literal to Case Object in SF
   */
  async buildServiceCase() {
    const recordType = await caseService.getServiceCaseId();
    if (recordType) {
      const caseObj = this.getNewCaseObject(recordType);
      this.updateObj.caseData = caseObj;
      return true;
    }
    // we didn't get a recordType containing the serviceCaseId and cannot continue add a new case.
    return false;
  }

  /**
   * Setting up obj to submit wich ends users current employment. Last day of work is yesterday.
   */
  buildEndActiveEmployment() {
    if (!this.activeEmploymentId) {
      if (
        this.state.isNotWorking &&
        !this.usrAccount.SelfemployedEvaluating__c &&
        !this.usrAccount.isUnemployed
      ) {
        this.errorMessage = this.labels.EP_labelNoEmployment;
      }
      return;
    }

    const empObj = {
      Id: this.activeEmploymentId,
      EndDate__c: getYesterday().toJSON()
    };
    this.updateObj.employment = { action: "U", record: empObj };
    //return employmentService.editEmployment(empObj);
  }

  // /**
  //  *
  //  * @param {boolean} inProgress - sets checkbox 'SelfemployedEvaluating__c' on Account to true/false depending on param.
  //  */
  // buildMemberSelfEmploymentEval(inProgress) {
  //   const member = new Account(this.usrAccount.Id, null, inProgress);
  //   this.updateObj.member = member;
  // }

  /**
   *
   * @param {boolean} isSelfEmploymentEval - mark user for self employed evaulation in progress
   * @param {boolean} isUnemployed - mark user as unemployed (arbetssökande)
   */
  buildMemberUpdateObj(isSelfEmploymentEval = false, isUnemployed = false) {
    const member = new Account(
      this.usrAccount.Id,
      null,
      isSelfEmploymentEval,
      isUnemployed
    );
    this.updateObj.member = member;
  }

  /**
    * This func can validate input fields directly in this component (changeEmployerModal.js). 
    But it doesn't reach child components input fields. Handling child compoonent validation separately. 
    * @returns true or false indicating input fields are valid or not.
    */
  isInputValid() {
    let isValid = true;
    let inputFields = this.template.querySelectorAll(".validate");
    inputFields.forEach((field) => {
      if (!field.checkValidity()) {
        field.reportValidity();
        isValid = false;
      }
    });
    return isValid;
  }

  /**
   *
   * @returns True or false depending on if all information was successfully processed.
   */
  async processFrame() {
    const index = this.activeIndex;
    let success = true;
    switch (index) {
      // STEP 1 - pick employment
      case 1: {
        if (this.state.isUnemployed) {
          // Ends users active employment and marks member as unemployed (arbetssökande). Throws error if there's no active employment.
          this.buildEndActiveEmployment();
          this.buildMemberUpdateObj(false, true);
          this.doSubmit = true;
        } else if (this.state.isNotWorking) {
          // Ends users active employment. Throws error if there's no active employment.
          this.buildEndActiveEmployment();
          this.buildMemberUpdateObj(false, false);
          this.doSubmit = true;
        } else if (this.state.isSelfEmployed) {
          // Creates service case reg. user is self employed.
          if (await this.buildServiceCase()) {
            this.buildMemberUpdateObj(true);
            this.doSubmit = true;
          } else {
            success = false;
          }
        }
        break;
      }
      // STEP 2 - Select employer/ file case
      case 2: {
        if (this.state.isUpdateEmployer) {
          if (!this.state.missingEmployer) {
            // Validation on input field from child component (searchEmployment component)
            success = this.selEmployer && this.selEmployer.Id ? true : false;
            this.childValidationError = !success;
          } else {
            // user can't have a selected employer and say 'can't find my employer' at the same time.
            this.selEmployer = null;
            // Creates service case reg. user can't find emplopyer.
            success = await this.buildServiceCase();
            this.doSubmit = success ? true : false;
          }
        }
        break;
      }
      // STEP 3 - Select workplace/ file case
      case 3: {
        // don't need to check on state.isUpdateEmployer because that's the only one running past index 2.
        if (!this.state.missingWorkplace) {
          // Validation on child component input field (pickWorkplace component)
          success = this.selWorkplaceId ? true : false;
          this.childValidationError = !success;
        } else {
          // user can't have a selected workplace and say 'can't find my workplace' at the same time.
          this.selWorkplaceId = null;
          // Creates service case reg. user can't find workplace.
          success = await this.buildServiceCase();
          this.doSubmit = success ? true : false;
        }
        break;
      }
      // STEP 4 - Select is manager (t/f) and then save a new employment record to Sf.
      case 4: {
        // build object literal matching employment__c fields in Sf.
        const empObj = {
          Person__c: this.usrAccount.Id,
          Manager__c: this.selIsManager,
          StartDate__c: new Date().toJSON(),
          Workplace__c: this.selWorkplaceId
        };

        this.updateObj.employment = { action: "C", record: empObj };
        this.buildMemberUpdateObj(false, false);
        this.doSubmit = true;
        break;
      }
      default: {
        break;
      }
    }
    return success;
  }

  async submitUpdates() {
    const { employment, caseData, member } = this.updateObj;
    let anyError = false;
    let submitSuccess = true;

    if (employment) {
      // C - Create
      if (employment.action === "C" && this.state.isUpdateEmployer) {
        const empId = await employmentService.saveNewEmployment(
          employment.record
        );
        if (empId) {
          this.newEmploymentId = empId;
        } else anyError = true;
      }

      // U - Update
      else if (
        employment.action === "U" &&
        (this.state.isUnemployed || this.state.isNotWorking)
      ) {
        submitSuccess = await employmentService.editEmployment(
          employment.record
        );
      }
      if (!submitSuccess) anyError = true;
    }
    if (
      caseData &&
      (this.state.isSelfEmployed ||
        this.state.missingEmployer ||
        this.state.missingWorkplace)
    ) {
      submitSuccess = await caseService.addNewCase(caseData);
      if (!submitSuccess) anyError = true;
    }
    if (
      member &&
      (!this.state.missingWorkplace || !this.state.missingEmployer)
    ) {
      submitSuccess = await accountService.editAccount(member);
      if (!submitSuccess) anyError = true;
    }

    if (
      !anyError &&
      !this.state.missingEmployer &&
      !this.state.missingWorkplace
    ) {
      this.notifyParentOfNewEmployment();
    }

    return !anyError;
  }

  /**
   * Triggered by user when clicking "Next".
   */
  async handleClickNext() {
    this.loading = true;
    this.errorMessage = "";

    if (this.isInputValid()) {
      if (await this.processFrame()) {
        // Validation Ok.
        if (
          this.errorMessage === "" &&
          (!this.doSubmit || (await this.submitUpdates()))
        ) {
          this.steps = this.activeIndex + 1; // runs set steps and moves to next frame

          // reset errors and spinner
          this.loading = false;
          this.doSubmit = false;
          this.errorMessage = "";
          this.childValidationError = false;
          this.setModalFocus();
        } else {
          if (!this.errorMessage) {
            this.errorMessage = this.labels.EP_errorGeneral;
          }
        }
      } else {
        // if something went wrong and if errorMessage isn't already set.
        if (!this.childValidationError && !this.errorMessage) {
          // Display the general error message (meant for HTTP errors) if the childCalidationError isn't active.
          this.errorMessage = this.labels.EP_errorGeneral;
        }
      }
    }
    this.loading = false;
  }

  /**
   * Triggered by user when clicking "Previous".
   */
  async handleClickPrevious() {
    this.loading = true;
    this.errorMessage = "";
    this.steps = this.activeIndex - 1;
    this.loading = false;
    this.doSubmit = false;
  }

  // Send event to parent component.
  handleCloseModal() {
    const modalCloseEvent = new CustomEvent("modalclose");
    this.dispatchEvent(modalCloseEvent);
  }
}