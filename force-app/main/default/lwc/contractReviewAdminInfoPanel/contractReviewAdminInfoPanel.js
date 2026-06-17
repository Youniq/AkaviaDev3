/**
 * Read / inline-edit panel that surfaces the full set of fields for a
 * selected criterion (Definition + SV/EN output text + display titles).
 * Used inside the criteria manager and the assignment manager.
 */
import { LightningElement, api, track } from "lwc";

export default class ContractReviewAdminInfoPanel extends LightningElement {
  @api disabled = false;

  _criterion;
  @api
  get criterion() {
    return this._criterion;
  }
  set criterion(value) {
    const prevDev = this._criterion?.DeveloperName;
    this._criterion = value;
    const newDev = value?.DeveloperName;
    if (prevDev !== newDev) {
      this._isEditing = false;
    }
  }

  /* ── Edit state ── */
  @track _isEditing = false;
  _editLabel = "";
  _editDefinition = "";
  _editDisplayTitleEng = "";
  _editDisplayTitle = "";
  _editOutputTrueSv = "";
  _editOutputTrueEng = "";
  _editOutputFalseSv = "";
  _editOutputFalseEng = "";

  /* ── Computed: display ── */

  get hasCriterion() {
    return !!this._criterion;
  }

  get isReadMode() {
    return this.hasCriterion && !this._isEditing;
  }

  get isEditMode() {
    return this.hasCriterion && this._isEditing;
  }

  get criterionLabel() {
    return this._criterion?.MasterLabel || "";
  }

  get definition() {
    return this._criterion?.Definition__c || "";
  }

  get outputTrueSv() {
    return this._criterion?.Output_When_True_sv__c || "";
  }

  get outputTrueEng() {
    return this._criterion?.Output_when_True_Eng__c || "";
  }

  get outputFalseSv() {
    return this._criterion?.Output_When_False_sv__c || "";
  }

  get outputFalseEng() {
    return this._criterion?.Output_When_False_eng__c || "";
  }

  get displayTitle() {
    return this._criterion?.Display_Title__c || "";
  }

  get displayTitleEng() {
    return this._criterion?.Display_Title_Eng__c || "";
  }

  /* ── Display getters with placeholder for read mode ── */

  get displayTitleDisplay() {
    return this.displayTitle || "—";
  }

  get displayTitleEngDisplay() {
    return this.displayTitleEng || "—";
  }

  get outputTrueSvDisplay() {
    return this.outputTrueSv || "—";
  }

  get outputTrueEngDisplay() {
    return this.outputTrueEng || "—";
  }

  get outputFalseSvDisplay() {
    return this.outputFalseSv || "—";
  }

  get outputFalseEngDisplay() {
    return this.outputFalseEng || "—";
  }

  get isEditDisabled() {
    return this.disabled;
  }

  get isInputDisabled() {
    return this.disabled;
  }

  get hasEditChanges() {
    return (
      this._editLabel !== this.criterionLabel ||
      this._editDefinition !== this.definition ||
      this._editDisplayTitleEng !== this.displayTitleEng ||
      this._editDisplayTitle !== this.displayTitle ||
      this._editOutputTrueSv !== this.outputTrueSv ||
      this._editOutputTrueEng !== this.outputTrueEng ||
      this._editOutputFalseSv !== this.outputFalseSv ||
      this._editOutputFalseEng !== this.outputFalseEng
    );
  }

  get isSaveDisabled() {
    return (
      this.disabled ||
      !this._editLabel.trim() ||
      !this._editDefinition.trim() ||
      !this.hasEditChanges
    );
  }

  /* ── Edit mode toggling ── */

  handleEdit() {
    this._editLabel = this.criterionLabel;
    this._editDefinition = this.definition;
    this._editDisplayTitleEng = this.displayTitleEng;
    this._editDisplayTitle = this.displayTitle;
    this._editOutputTrueSv = this.outputTrueSv;
    this._editOutputTrueEng = this.outputTrueEng;
    this._editOutputFalseSv = this.outputFalseSv;
    this._editOutputFalseEng = this.outputFalseEng;
    this._isEditing = true;
  }

  handleCancel() {
    this._isEditing = false;
  }

  /* ── Field change handlers ── */

  handleLabelChange(event) {
    this._editLabel = event.target.value;
  }

  handleDefinitionChange(event) {
    this._editDefinition = event.target.value;
  }

  handleDisplayTitleEngChange(event) {
    this._editDisplayTitleEng = event.target.value;
  }

  handleDisplayTitleChange(event) {
    this._editDisplayTitle = event.target.value;
  }

  handleOutputTrueSvChange(event) {
    this._editOutputTrueSv = event.target.value;
  }

  handleOutputTrueEngChange(event) {
    this._editOutputTrueEng = event.target.value;
  }

  handleOutputFalseSvChange(event) {
    this._editOutputFalseSv = event.target.value;
  }

  handleOutputFalseEngChange(event) {
    this._editOutputFalseEng = event.target.value;
  }

  /* ── Save: fire intent event to parent ── */

  handleSave() {
    this.dispatchEvent(
      new CustomEvent("criterionsave", {
        detail: {
          developerName: this._criterion.DeveloperName,
          label: this._editLabel.trim(),
          fields: {
            Definition__c: this._editDefinition,
            Display_Title_Eng__c: this._editDisplayTitleEng,
            Display_Title__c: this._editDisplayTitle,
            Output_when_True_Eng__c: this._editOutputTrueEng,
            Output_When_True_sv__c: this._editOutputTrueSv,
            Output_When_False_eng__c: this._editOutputFalseEng,
            Output_When_False_sv__c: this._editOutputFalseSv
          }
        }
      })
    );
    this._isEditing = false;
  }
}