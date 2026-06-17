/**
 * Modal showing the full detail of a single criterion: status badge,
 * two-column Definition + Extract grid, and a full-width AI Comment block.
 * Hosts the "Give Feedback" button that opens
 * `c/contractReviewFeedbackModal`.
 *
 * Inputs (via `@api`): the criterion record. Returns no value to the caller.
 */
import LightningModal from "lightning/modal";
import { api } from "lwc";
import ContractReviewFeedbackModal from "c/contractReviewFeedbackModal";
import { LABEL_EXTRACT, LABEL_AI_COMMENT, LABEL_DEFINITION } from "c/contractReviewUtils";

export default class ContractReviewCriterionViewModal extends LightningModal {
  @api criterion;

  get modalTitle() {
    return this.criterion?.Name || "Granskningspunkt";
  }

  get isMet() {
    return !!this.criterion?.CriterionMet__c;
  }

  get statusLabel() {
    return this.isMet ? "Uppfyllt" : "Ej uppfyllt";
  }

  get statusClass() {
    return this.isMet ? "status-badge status-met" : "status-badge status-not-met";
  }

  get definition() {
    return this.criterion?.Definition__c || null;
  }

  get extract() {
    return this.criterion?.Extract__c || null;
  }

  get aiComment() {
    return this.criterion?.ai_comment__c || null;
  }

  // ─── Label getters (shared constants) ───

  get definitionLabel() { return LABEL_DEFINITION; }
  get extractLabel() { return LABEL_EXTRACT; }
  get aiCommentLabel() { return LABEL_AI_COMMENT; }

  handleClose() {
    this.close();
  }

  handleGiveFeedback() {
    ContractReviewFeedbackModal.open({
      size: "small",
      criterionId: this.criterion?.Id
    });
  }
}