/**
 * Edit / view form for a single `ContractReviewTemplate__mdt` (label,
 * developer name, description). Emits a `save` custom event carrying the
 * deploy payload built via `c/contractReviewDeployService.buildTemplateRecord`.
 */
import { LightningElement, api } from "lwc";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import {
  deploy,
  buildTemplateRecord,
  extractDeployError
} from "c/contractReviewDeployService";

export default class ContractReviewAdminTemplateDetail extends LightningElement {
  @api selectedTemplate;

  @api
  resetEditMode() {
    this.isEditing = false;
    this.isSaving = false;
  }

  isEditing = false;
  isSaving = false;
  editLabel = "";
  editDescription = "";

  get showViewMode() {
    return !this.isEditing;
  }

  @api
  get hasUnsavedChanges() {
    if (!this.isEditing) return false;
    return (
      this.editLabel !== this.selectedTemplate.MasterLabel ||
      this.editDescription !== (this.selectedTemplate.Description__c || "")
    );
  }

  get isSaveDisabled() {
    return this.isSaving || !this.editLabel.trim();
  }

  get descriptionDisplay() {
    return (
      this.selectedTemplate?.Description__c ||
      "No description \u2014 click to edit"
    );
  }

  get descriptionClass() {
    return this.selectedTemplate?.Description__c
      ? "detail-description detail-description-clickable"
      : "detail-description detail-description-empty detail-description-clickable";
  }

  handleEdit() {
    this.editLabel = this.selectedTemplate.MasterLabel;
    this.editDescription = this.selectedTemplate.Description__c || "";
    this.isEditing = true;
  }

  handleLabelChange(event) {
    this.editLabel = event.target.value;
  }

  handleDescriptionChange(event) {
    this.editDescription = event.target.value;
  }

  handleCancel() {
    this.isEditing = false;
  }

  async handleSave() {
    const devName = this.selectedTemplate.DeveloperName;
    const label = this.editLabel.trim();
    const record = buildTemplateRecord(devName, label, {
      Description__c: this.editDescription
    });

    this.isSaving = true;

    try {
      const jobId = await deploy([record]);
      this.dispatchEvent(
        new CustomEvent("deployinitiated", {
          detail: { jobId, entityType: "template", developerName: devName }
        })
      );
    } catch (err) {
      console.error(
        "[TemplateDetail] Deploy error:",
        err?.body?.message || err?.message || JSON.stringify(err)
      );
      this.dispatchEvent(
        new ShowToastEvent({
          title: "Distributionsfel",
          message: extractDeployError(err),
          variant: "error",
          mode: "sticky"
        })
      );
    } finally {
      this.isSaving = false;
    }
  }
}