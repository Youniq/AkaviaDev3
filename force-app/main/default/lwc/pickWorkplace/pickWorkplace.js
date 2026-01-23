import { LightningElement, api, track } from "lwc";
import { sortObjArrayByProperty } from "c/utils";
import { employmentLabels } from 'c/labels';
import { employmentService } from "c/services";

export default class PickWorkplace extends LightningElement {
  @api employerId; // account id for selected employer.
  @api hasError; // boolean indicating there're validation errors to bring to UI
  _hasServiceError; // boolean
  searchFilterEnabled; // boolean
  loading; // boolean
  allWorkplaces; // object array, (the truth). Should always hold the raw data from sales force.
  labels = employmentLabels;
  @track filteredWorkplaces; // object array, OK to make changes to this.

  constructor() {
    super();
    this.loading = true;
    this.searchFilterEnabled = false;
    this.hasServiceError = false;
  }

  async connectedCallback() {
    // Load workplaces from salesforce
    const result = await employmentService.getEmployerWorkplaces(
      this.employerId
    );
    this.loading = false;
    if (result) {
      this.allWorkplaces = sortObjArrayByProperty(
        [...result],
        "ShippingCity"
      );
      // Display top 50 workplaces
      this.filteredWorkplaces = this.getTop50Items([...this.allWorkplaces]);

      // Allow search within results if there are more than 7 workplaces returned.
      this.searchFilterEnabled = this.filteredWorkplaces.length > 7 ? true : false;
    } else {
      this.hasServiceError = true;
    }
  }

  /**
   * A result means there's nothing loading, and there're entries in the allWorkplaces array.
   */
  get hasResults() {
    if (!this.loading && this.allWorkplaces && this.allWorkplaces.length) {
      return true;
    }
    return false;
  }

  /**
   * No result means there's nothing loading and the allWorkplaces array is empty [].
   */
  get hasNoResult() {
    if (!this.loading && this.allWorkplaces && !this.allWorkplaces.length) {
      return true;
    }
    return false;
  }

  get fieldsetClasses() {
    // dynamically set the slds-has-error class to html.
    return this.hasError
      ? "slds-form-element slds-has-error"
      : "slds-form-element";
  }

  /**
   * Set property and notify parent of error from within service call, to display general error in modal
   */
  set hasServiceError(state) {
    if (this._hasServiceError !== state) {
      const event = new CustomEvent("error", { detail: { hasError: state } });
      this.dispatchEvent(event);
      this._hasServiceError = state;
    }
  }

  getTop50Items(array) {
    return array.slice(0, 50);
  }

  /** Notify parent of a selected workplace */
  handleSelection(evt) {
    const workplaceId = evt.target.value;
    const event = new CustomEvent("workplaceselected", {
      detail: { workplaceId: workplaceId }
    });
    this.dispatchEvent(event);
  }

  /**
   * User can search within the result when there're many workplaces listed.
   * This is the event listener for when user is typing.
   * @param {event object} evt
   */
  handleKeyUp(evt) {
    const val = evt.target.value.toLowerCase();

    if (val === "") {
      this.filteredWorkplaces = this.getTop50Items([...this.allWorkplaces]);
    } else {
      const searchRes = this.allWorkplaces.filter((wp) => {
        // any listed workplace contains the search word in either name or shipping city fields
        return wp.Name.toLowerCase().indexOf(val) > -1 ||
          wp.ShippingCity.toLowerCase().indexOf(val) > -1
          ? true
          : false;
      });
      this.filteredWorkplaces = this.getTop50Items(searchRes);
    }
  }
}