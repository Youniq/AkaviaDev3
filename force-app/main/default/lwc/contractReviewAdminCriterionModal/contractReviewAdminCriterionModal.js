/**
 * Create / edit modal for a single `ContractReviewCriterion__mdt`. Validates
 * required fields, derives DeveloperName from MasterLabel for new records,
 * and returns the deploy payload to the caller.
 */
import LightningModal from "lightning/modal";
import { api } from "lwc";
import {
  deploy,
  buildCriterionRecord,
  extractDeployError
} from "c/contractReviewDeployService";
import { generateDeveloperName } from "c/contractReviewUtils";

export default class ContractReviewAdminCriterionModal extends LightningModal {
  @api criterion;

  editLabel = "";
  editDefinition = "";
  editDisplayTitleEng = "";
  editDisplayTitle = "";
  editOutputTrueEng = "";
  editOutputTrueSv = "";
  editOutputFalseEng = "";
  editOutputFalseSv = "";
  isSaving = false;

  connectedCallback() {
    if (this.criterion) {
      this.editLabel = this.criterion.MasterLabel || "";
      this.editDefinition = this.criterion.Definition__c || "";
      this.editDisplayTitleEng = this.criterion.Display_Title_Eng__c || "";
      this.editDisplayTitle = this.criterion.Display_Title__c || "";
      this.editOutputTrueEng = this.criterion.Output_when_True_Eng__c || "";
      this.editOutputTrueSv = this.criterion.Output_When_True_sv__c || "";
      this.editOutputFalseEng = this.criterion.Output_When_False_eng__c || "";
      this.editOutputFalseSv = this.criterion.Output_When_False_sv__c || "";
    }
  }

  get isNew() {
    return !this.criterion;
  }

  get modalTitle() {
    return this.isNew ? "Nytt kriterium" : "Redigera kriterium";
  }

  get isSaveDisabled() {
    return (
      this.isSaving || !this.editLabel.trim() || !this.editDefinition.trim()
    );
  }

  handleLabelChange(event) {
    this.editLabel = event.target.value;
  }

  handleDefinitionChange(event) {
    this.editDefinition = event.target.value;
  }

  handleDisplayTitleEngChange(event) {
    this.editDisplayTitleEng = event.target.value;
  }

  handleDisplayTitleChange(event) {
    this.editDisplayTitle = event.target.value;
  }

  handleOutputTrueEngChange(event) {
    this.editOutputTrueEng = event.target.value;
  }

  handleOutputTrueSvChange(event) {
    this.editOutputTrueSv = event.target.value;
  }

  handleOutputFalseEngChange(event) {
    this.editOutputFalseEng = event.target.value;
  }

  handleOutputFalseSvChange(event) {
    this.editOutputFalseSv = event.target.value;
  }

  handleCancel() {
    this.close(null);
  }

  async handleSave() {
    const devName = this.isNew
      ? generateDeveloperName(this.editLabel)
      : this.criterion.DeveloperName;
    const label = this.editLabel.trim();

    const fields = {
      Definition__c: this.editDefinition,
      Display_Title_Eng__c: this.editDisplayTitleEng,
      Display_Title__c: this.editDisplayTitle,
      Output_when_True_Eng__c: this.editOutputTrueEng,
      Output_When_True_sv__c: this.editOutputTrueSv,
      Output_When_False_eng__c: this.editOutputFalseEng,
      Output_When_False_sv__c: this.editOutputFalseSv
    };

    const record = buildCriterionRecord(devName, label, fields);

    this.isSaving = true;

    try {
      const jobId = await deploy([record]);
      this.close({ jobId, developerName: devName });
    } catch (err) {
      console.error(
        "[CriterionModal] Deploy error:",
        err?.body?.message || err?.message || JSON.stringify(err)
      );
      this.close({ error: extractDeployError(err) });
    } finally {
      this.isSaving = false;
    }
  }
}