/**
 * Modal for creating a new `ContractReviewTemplate__mdt`. Auto-derives the
 * DeveloperName from the label via `c/contractReviewUtils.generateDeveloperName`.
 * Returns the new template developerName on close.
 */
import LightningModal from "lightning/modal";
import { api } from "lwc";
import {
  deploy,
  buildTemplateRecord,
  extractDeployError
} from "c/contractReviewDeployService";
import { generateDeveloperName } from "c/contractReviewUtils";

export default class ContractReviewAdminTemplateModal extends LightningModal {
  @api templates;

  editLabel = "";
  editDescription = "";
  isSaving = false;
  errorMessage = "";

  get isSaveDisabled() {
    return this.isSaving || !this.editLabel.trim();
  }

  handleLabelChange(event) {
    this.editLabel = event.target.value;
  }

  handleDescriptionChange(event) {
    this.editDescription = event.target.value;
  }

  handleCancel() {
    this.close(null);
  }

  async handleSave() {
    const devName = generateDeveloperName(this.editLabel);
    const label = this.editLabel.trim();

    this.errorMessage = "";
    if (this.templates) {
      const collision = this.templates.find((t) => t.DeveloperName === devName);
      if (collision) {
        this.errorMessage = `A template named "${devName}" already exists. Choose a different name.`;
        return;
      }
    }

    const record = buildTemplateRecord(devName, label, {
      Description__c: this.editDescription
    });

    this.isSaving = true;

    try {
      const jobId = await deploy([record]);
      this.close({ jobId, developerName: devName });
    } catch (err) {
      console.error(
        "[TemplateModal] Deploy error:",
        err?.body?.message || err?.message || JSON.stringify(err)
      );
      this.close({ error: extractDeployError(err) });
    } finally {
      this.isSaving = false;
    }
  }
}