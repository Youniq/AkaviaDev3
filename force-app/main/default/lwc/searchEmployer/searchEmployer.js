import { LightningElement, track, api } from "lwc";
import { employmentService } from "c/services";
import { debounce, sortObjArrayByProperty } from "c/utils";
import { employmentLabels } from "c/labels";

export default class SearchEmployer extends LightningElement {
  @api hasError; // boolean indicating there're validation errors to bring to UI
  @api selectedEmployer; // Populated both when coming here from clicking "previous" or after selecting employer from search result.
  loading; // boolean
  _hasServiceError; // boolean, for service exceptions to notify parent about.
  labels = employmentLabels;
  @track searchResults; // Object array
  @track employer; // Object

  get hasSelectedEmployer() {
    return this.selectedEmployer && this.selectedEmployer.Name;
  }

  /**
   * A result means there's nothing loading, and there're entries in the allWorkplaces array.
   */
  get hasResults() {
    if (!this.loading && this.searchResults && this.searchResults.length) {
      return true;
    }
    return false;
  }

  /**
   * No result means there's nothing loading and the allWorkplaces array is empty [].
   */
  get hasNoResult() {
    if (!this.loading && this.searchResults && !this.searchResults.length) {
      return true;
    }
    return false;
  }

  get fieldsetClasses() {
    // dynamically set the has error class to html.
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

  // Mark this.selectedEmployer as checked radiobutton in Gui. Match with id.
  checkSelectedEmp(searchResults, id) {
    if (id) {
      const mappedResult = searchResults.map((company) => {
        if (company.Id === id) {
          return { ...company, selected: true };
        }
        return company;
      });
      return mappedResult;
    }
    return searchResults;
  }

  // A debouncer for input handler so that it' isn't triggered on every keytroke.
  // But checks value every 400ms from first keystroke
  bouncedHandler = debounce((fn) => {
    fn();
  }, 400);

  /**
   * Event handler for entering a search phrase in search box.
   * Sends query to fetch search results from Sf, and display the results in Gui.
   * @param {event object} evt
   */
  handleKeyUp(evt) {
    const val = evt.target.value;
    this.bouncedHandler(async () => {
      if (val.length >= 3) {
        let searching = true;
        // Delay setting this.loading = true --> to avoid a flickering experience where spinner shows up every now and then if you're a slow typer.
        this.bouncedHandler(() => {
          if (searching) {
            this.loading = true;
          }
        });

        const data = await employmentService.searchForEmployers(val);
        if (data) {
          // sort result and display the top 20 items.
          const sortedData = sortObjArrayByProperty([...data], "Name").slice(
            0,
            20
          );

          this.searchResults = this.checkSelectedEmp(
            sortedData,
            this.selectedEmployer ? this.selectedEmployer.Id : ""
          );
          this.hasServiceError = false;
        } else {
          // Trigger general error on parent component.
          this.hasServiceError = true;
        }

        searching = false;
        this.loading = false;
      } else if (!val.length) {
        // Too short search string. Just empty the Gui - not showing "No reults found..".
        this.hasServiceError = false;
        this.searchResults = null;
        this.loading = false;
      }
    });
  }

  /**
   * Handles a selection from the listed employers. (Notifying parent component)
   * @param {event object} evt
   */
  handleSelection(evt) {
    const selEmployerId = evt.target.value;
    const employerObj = this.searchResults.find(
      (item) => item.Id === selEmployerId
    );

    const event = new CustomEvent("employerselected", {
      detail: { employer: employerObj }
    });
    this.dispatchEvent(event);
    this.searchResults = this.checkSelectedEmp(
      this.searchResults,
      selEmployerId
    );
  }
}