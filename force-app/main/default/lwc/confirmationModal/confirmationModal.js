import { LightningElement, api } from "lwc";
import { employmentLabels } from 'c/labels';


export default class ConfirmationModal extends LightningElement {
  @api confirmed;
  initiatedConfirm;
  labels = employmentLabels;

  get loading() {
    if (!this.confirmed && this.initiatedConfirm) {
      return true;
    } 
    return false;
  }

  // Send event to parent component.
  handleCloseModal() {
    const modalCloseEvent = new CustomEvent("modalclose");
    this.dispatchEvent(modalCloseEvent);
  }

  handleConfirm() {
    this.initiatedConfirm = true;
    const confirmEvent = new CustomEvent("confirm");
    this.dispatchEvent(confirmEvent);
  }
}