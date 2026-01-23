import { LightningElement, wire, track } from "lwc";
import basePath from "@salesforce/community/basePath";
import { CurrentPageReference } from "lightning/navigation";
import { caseService } from "c/services";
import { Case, CaseComment, File } from "c/models";
import {
  sortObjArrayByProperty,
  sortObjArrByDateProperty,
  sortEventTriggeredOk
} from "c/utils";
import { loadStyle } from "lightning/platformResourceLoader";
// import { getRecord } from 'lightning/uiRecordApi';

// Static Resources
import AkaviaStyles_Community from "@salesforce/resourceUrl/AkaviaStyles_Community";
import { caseLabels } from "c/labels";

export default class CaseInfo extends LightningElement {
  basePath;
  labels;
  loading;
  showError;
  sortAsc;
  showCommentInput;
  commentVal;
  caseId;
  @track caseObj; // the fetched case record
  @track openComments; // keeps track of which accordions are open for the listed comments.
  @track caseComments;
  @track caseFiles;
  @track _sortedState;

  get sortedState() {
    return this._sortedState;
  }

  get isOpen() {
    return this.caseObj && this.caseObj.Status !== "Avslutad";
  }

  get hasComments() {
    return this.caseComments && this.caseComments.length ? true : false;
  }

  get noComments() {
    return !this.loading && this.caseComments && !this.caseComments.length
      ? true
      : false;
  }

  get hasCommentsError() {
    return !this.loading && !this.caseComments ? true : false;
  }

  get hasCaseError() {
    return !this.loading && !this.caseObj ? true : false;
  }

  get hasFiles() {
    return this.caseFiles && this.caseFiles.length ? true : false;
  }

  /**
   * No files are added to case if caseObjects listed ContentDocumentLinks is falsy
   */
  get noFiles() {
    return !this.loading && this.caseObj && !this.caseObj.ContentDocumentLinks
      ? true
      : false;
  }

  /**
   * An error file fetching has happened if there are ContentDocumentLinks for the case but this.caseFiles is falsy.
   */
  get hasFilesError() {
    return !this.loading &&
      this.caseObj &&
      this.caseObj.ContentDocumentLinks &&
      !this.caseFiles
      ? true
      : false;
  }

  get acceptedFormats() {
    return [".pdf", ".png", ".jpeg", ".txt", ".docx", ".jpg", ".xlsx"];
  }

  /**
   * A way of keeping track of if spinner should run within modal or on full page view.
   */
  get showSpinnerOnPage() {
    return this.loading && !this.showCommentInput ? true : false;
  }

  /**
   * Checks that owner is out of office and that there is a configured ooo message to display.
   */
  get showOwnerOooMsg() {
    return (
      this.caseObj.ownerIsOoo &&
      this.caseObj.oooMsg &&
      this.caseObj.oooMsg.length
    );
  }

  get oooMsg() {
    if (this.caseObj.oooMsg && this.caseObj.oooMsg.length) {
      return this.caseObj.oooMsg;
    }

    return this.labels.CP_oooMsgStandard;
  }

  /**
   * Handles outputting correct information in 'aria-sort' attribute used by screen readers.
   */
  set sortedState(activeCol) {
    const stateCopy = { ...this._sortedState };
    Object.keys(stateCopy).forEach((key) => {
      if (key === activeCol) {
        this._sortedState[key] = {
          ...stateCopy[key],
          active: true,
          sortOrder: this.sortAsc ? "ascending" : "descending"
        };
      } else {
        this._sortedState[key] = {
          ...this._sortedState[key],
          active: false,
          sortOrder: "none"
        };
      }
    });
  }

  constructor() {
    super();
    this.labels = caseLabels;
    this.loading = true;
    this.showCommentInput = false;
  }

  connectedCallback() {
    loadStyle(this, AkaviaStyles_Community);
    this.basePath = basePath;
  }

  /**
   * Retrieves caseId from url qurey param 'id' in the LWC way, using CurrentPageReference (imported object).
   * Then calls dependent functions to load case and case-comments.
   * @param {object} currentPageReference
   */
  @wire(CurrentPageReference)
  getStateParameters(currentPageReference) {
    if (currentPageReference) {
      const urlStateParameters = currentPageReference.state;

      // get url query parameter
      const caseId = urlStateParameters.id || null;
      this.caseId = caseId;
      if (caseId) {
        /* Using Promise.all because the functions can run in parallel and
         * complete quicker than running them after one another.
         */
        Promise.all([this.getCaseInfo(caseId), this.getComments(caseId)])
          .then(() => {
            return this.getCaseDocs();
          })
          .then(() => {
            // stop loading once async operations are done
            this.loading = false;
          });
      }
    }
  }

  /**
   * Gets Case record by case id and maps it to js class Case (see file models/case.js).
   * @param {string} caseId
   */
  async getCaseInfo(caseId) {
    const result = await caseService.getCaseById(caseId);
    // Expecting response of apex type: CommunityCaseModel {caseRecord, ownerIsOutOfOffice, ownerOooMsg}
    if (result && result.caseRecord) {
      this.caseObj = new Case(result);

      if (this.caseObj.RecordTypeId) {
        const caseRecordType = await caseService.getRtNameByRtId(
          this.caseObj.RecordTypeId
        );
        if (caseRecordType) {
          this.caseObj.RecordTypeName = caseRecordType[0].Name;
        }
      }
    }
    // Shows error through  get hasCaseError
  }

  /**
   * Retrieves case documents for current case
   */
  async getCaseDocs() {
    if (this.caseObj && this.caseObj.ContentDocumentLinks) {
      const docIds = this.caseObj.ContentDocumentLinks.map((link) => {
        return link.ContentDocumentId;
      });

      const result = await caseService.getFilesContentVersionById(docIds);

      if (result) {
        const files = result.map((doc) => {
          const file = new File(doc);
          file.fileDownloadPath = file.getFileDownloadPath(this.basePath);
          return file;
        });
        this.caseFiles = sortObjArrayByProperty([...files], "Title");
      }
    }
    return null;
    // Shows error through  get hasFilesError
  }

  /**
   * Gets case comments by caseId and maps the results to js class CaseComment (see file models/caseComment.js).
   * @param {string} caseId
   */
  async getComments(caseId) {
    const result = await caseService.getCommentsByCaseId(caseId);
    if (result) {
      this.caseComments = result
        .filter((item) => {
          if (!item.Body && !item.CommentBody) return false;
          return true;
        })
        .map((item) => {
          return new CaseComment(item);
        });
      // setup the sorted state
      this.initSortedState(this.caseComments[0]);
      this.sortAsc = false;
      const sortField = "CreatedDate";
      this.caseComments = sortObjArrByDateProperty(
        [...this.caseComments],
        sortField,
        this.sortAsc
      );
      this.sortedState = sortField;
    }
    // Shows error through get hasCommentsError
  }

  // Initiating object wich is resposible for outputting correct information in 'aria-sort' attribute used by screen readers.
  initSortedState(obj) {
    if (!obj) {
      return;
    }

    this._sortedState = {};
    Object.keys(obj).forEach((col) => {
      this._sortedState = {
        ...this._sortedState,
        [col]: {
          active: false,
          sortOrder: "none"
        }
      };
    });
  }

  checkInputValid(inputs) {
    const allValid = inputs.reduce((validSoFar, field) => {
      field.reportValidity();
      return validSoFar && field.checkValidity();
    }, true);
    return allValid;
  }

  handleSortTextField(evt) {
    evt.stopPropagation();

    if (!sortEventTriggeredOk(evt)) {
      return;
    }
    const target = evt.currentTarget;
    this.sortAsc = this.sortAsc ? false : true;
    const sortField = target.parentNode.dataset.field;
    this.caseComments = sortObjArrayByProperty(
      [...this.caseComments],
      sortField,
      this.sortAsc
    );
    this.sortedState = sortField;
  }

  handleSortDateField(evt) {
    evt.stopPropagation();
    if (!sortEventTriggeredOk(evt)) {
      return;
    }

    const target = evt.currentTarget;
    this.sortAsc = this.sortAsc ? false : true;
    const sortField = target.parentNode.dataset.field;
    this.caseComments = sortObjArrByDateProperty(
      [...this.caseComments],
      sortField,
      this.sortAsc
    );
    this.sortedState = sortField;
  }

  handleSectionToggle(evt) {
    this.openComments = [...evt.detail.openSections];
  }

  handleCommentBtnClick() {
    this.showError = false;
    // Toggle display of input
    this.showCommentInput = this.showCommentInput ? false : true;
  }

  /**
   * If input is ok in validation, new comment is created and comments list gets immediately refreshed.
   */
  async handleSaveNewComment() {
    const inputFields = [...this.template.querySelectorAll(".input")];
    if (this.checkInputValid(inputFields)) {
      // There's only the comment input field, so getting first array index
      const commentField = inputFields[0];
      this.loading = true;
      const success = await caseService.addNewCaseComment(
        this.caseObj.Id,
        commentField.value
      );
      if (success) {
        // Removed (cacheable=true) on the apex function, to have comments updated, otherwise page had to be reloaded to get the new comment.
        // If cache is necessary for other reasons I guess component needs to be rewritten to do things the wired way.
        await this.getComments(this.caseObj.Id);
        this.showCommentInput = false;
      } else {
        this.showError = true;
      }
    }
    this.loading = false;
  }

  /**
   * Function callback on file upload has finished. Connected to File uploader lightning component.
   */
  async handleUploadFinished() {
    this.loading = true;
    await this.getCaseInfo(this.caseObj.Id);
    await this.getCaseDocs();
    this.loading = false;
  }

  handleCloseModal() {
    this.showCommentInput = false;
  }
}