/**
 * Modal wrapping the `ContractReviewFeedback` Flow. Captures human-in-the-
 * loop feedback on a single criterion evaluation. Inserts a
 * ContractReviewFeedback__c record on Flow finish.
 *
 * Inputs: `@api criterionId`. Closes when the Flow reaches FINISHED or
 * FINISHED_SCREEN.
 */
import LightningModal from "lightning/modal";
import { api, track } from "lwc";

export default class ContractReviewFeedbackModal extends LightningModal {
  @api criterionId;
  @track flowInputVariables;
  @track flowError = false;
  @track flowFinished = false;

  connectedCallback() {
    this.flowInputVariables = [
      { name: "recordId", type: "String", value: this.criterionId }
    ];
  }

  get showFlow() {
    return !this.flowFinished;
  }

  handleFlowStatusChange(event) {
    const { status } = event.detail;
    if (status === "FINISHED" || status === "FINISHED_SCREEN") {
      this.flowFinished = true;
      this.close();
    } else if (status === "ERROR") {
      this.flowError = true;
    }
  }
}