import LightningModal from "lightning/modal";
import { api, track } from "lwc";

export default class ContractReviewNewModal extends LightningModal {
  @api caseId;
  @track flowInputVariables;
  @track flowError = false;
  @track flowFinished = false;

  connectedCallback() {
    this.flowInputVariables = [
      { name: "recordId", type: "String", value: this.caseId }
    ];
  }

  get showFlow() {
    return !this.flowFinished;
  }

  handleFlowStatusChange(event) {
    const { status } = event.detail;
    if (status === "FINISHED" || status === "FINISHED_SCREEN") {
      this.flowFinished = true;
      this.close("FINISHED");
    } else if (status === "ERROR") {
      this.flowError = true;
    }
  }
}