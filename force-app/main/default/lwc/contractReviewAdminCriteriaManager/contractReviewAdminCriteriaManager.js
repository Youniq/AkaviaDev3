/**
 * CRUD UI for `ContractReviewCriterion__mdt`. Lists criteria from
 * `ContractReviewMetadataSelector.getCriteria` and opens
 * `c/contractReviewAdminCriterionModal` for create/edit.
 */
import { LightningElement, api } from "lwc";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import getCriteria from "@salesforce/apex/ContractReviewMetadataSelector.getCriteria";
import ContractReviewAdminCriterionModal from "c/contractReviewAdminCriterionModal";

export default class ContractReviewAdminCriteriaManager extends LightningElement {
  criteria;
  error;
  _isLoading = false;

  @api isDeploying = false;

  connectedCallback() {
    this._loadCriteria();
  }

  async _loadCriteria() {
    this._isLoading = true;
    try {
      const data = await getCriteria();
      this.criteria = data;
      this.error = undefined;
    } catch (err) {
      console.error(
        "[CriteriaManager] Load error:",
        err?.body?.message || err?.message || JSON.stringify(err)
      );
      this.error = err;
      this.criteria = undefined;
    } finally {
      this._isLoading = false;
    }
  }

  get hasCriteria() {
    return this.criteria && this.criteria.length > 0;
  }

  get isLoading() {
    return this._isLoading;
  }

  get decoratedCriteria() {
    if (!this.criteria) return [];
    return this.criteria.map((c) => ({
      ...c,
      truncatedDefinition: c.Definition__c
        ? c.Definition__c.length > 80
          ? c.Definition__c.substring(0, 80) + "…"
          : c.Definition__c
        : "—"
    }));
  }

  async handleNewCriterion() {
    const result = await ContractReviewAdminCriterionModal.open({
      size: "medium",
      criterion: undefined
    });
    this._handleModalResult(result);
  }

  async handleEditCriterion(event) {
    const devName = event.currentTarget.dataset.developerName;
    const criterion = this.criteria.find((c) => c.DeveloperName === devName);
    const result = await ContractReviewAdminCriterionModal.open({
      size: "medium",
      criterion
    });
    this._handleModalResult(result);
  }

  _handleModalResult(result) {
    if (result?.error) {
      this.dispatchEvent(
        new ShowToastEvent({
          title: "Distributionsfel",
          message: result.error,
          variant: "error"
        })
      );
      return;
    }
    if (result && result.jobId) {
      this.dispatchEvent(
        new CustomEvent("deployinitiated", {
          detail: {
            jobId: result.jobId,
            entityType: "criterion",
            developerName: result.developerName
          }
        })
      );
    }
  }

  @api
  refresh() {
    return this._loadCriteria();
  }
}