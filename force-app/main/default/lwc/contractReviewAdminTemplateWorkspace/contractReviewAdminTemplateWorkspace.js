/**
 * Admin workspace for one selected template. Composes the template detail
 * editor and the assignment manager. Bubbles deploy events up to
 * `c/contractReviewAdminContainer`.
 */
import { LightningElement, api } from "lwc";

export default class ContractReviewAdminTemplateWorkspace extends LightningElement {
  @api selectedTemplate;
  @api isDeploying;

  get hasTemplate() {
    return !!this.selectedTemplate;
  }

  get templateDevName() {
    return this.selectedTemplate?.DeveloperName;
  }

  @api
  getDetailComponent() {
    return this.template.querySelector(
      "c-contract-review-admin-template-detail"
    );
  }

  @api
  resetDetailEditMode() {
    const detail = this.template.querySelector(
      "c-contract-review-admin-template-detail"
    );
    if (detail) {
      detail.resetEditMode();
    }
  }

  @api
  refreshAssignments() {
    const assignmentManager = this.template.querySelector(
      "c-contract-review-admin-assignment-manager"
    );
    if (assignmentManager) {
      assignmentManager.refresh();
    }
  }

  @api
  refreshCriteriaOnly() {
    const assignmentManager = this.template.querySelector(
      "c-contract-review-admin-assignment-manager"
    );
    if (assignmentManager) {
      assignmentManager.refreshCriteriaOnly();
    }
  }

  handleDeployInitiated(event) {
    this.dispatchEvent(
      new CustomEvent("deployinitiated", { detail: event.detail })
    );
  }
}