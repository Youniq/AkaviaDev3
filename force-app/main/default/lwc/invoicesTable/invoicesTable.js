/**
  @description       : A Child component which displays invoice information. 
  @author            : Malin Nilsson
  @group             : Stretch Customer
  @last modified on  : 02-27-2023
  @last modified by  : Malin Nilsson
 **/

import { LightningElement, api, track } from "lwc";
import { paymentpageLabels } from "c/labels";

export default class InvoicesTable extends LightningElement {
  @api invoicesList;
  @track compInvoices; // the data which is used in the component.
  labels;

  constructor() {
    super();
    this.labels = paymentpageLabels;
  }

  connectedCallback() {
    this.compInvoices = this.invoicesList.map((row) => {
      return { ...row };
    });
  }

  /**
   * Notify parent of payment button being clicked.
   * @param {event object} evt
   */
  openModal(evt) {
    const recordId = evt.target.value;
    const event = new CustomEvent("openmodal", {
      detail: { invoiceId: recordId }
    });
    this.dispatchEvent(event);
  }

  // Methods to sort Invoice List
  sort(e) {
    if (this.sortedColumn === e.currentTarget.dataset.id) {
      this.sortedDirection = this.sortedDirection === "desc" ? "asc" : "desc";
    } else {
      this.sortedDirection = "desc";
    }
    let reverse = this.sortedDirection === "desc" ? 1 : -1;
    let table = JSON.parse(JSON.stringify(this.invoicesList));
    table.sort((a, b) => {
      return a[e.currentTarget.dataset.id] > b[e.currentTarget.dataset.id]
        ? 1 * reverse
        : -1 * reverse;
    });
    this.sortedColumn = e.currentTarget.dataset.id;
    this.compInvoices = table;
  }

  sortDate(a, b) {
    return (
      new Date(a.ExpirationDate__c).getTime() -
      new Date(b.ExpirationDate__c).getTime()
    );
  }

  sortDateColumn(e) {
    if (this.sortedColumn === e.currentTarget.dataset.id) {
      this.sortedDirection = this.sortedDirection === "desc" ? "asc" : "desc";
    } else {
      this.sortedDirection = "desc";
    }
    let reverse = this.sortedDirection === "desc" ? 1 : -1;
    let table = JSON.parse(JSON.stringify(this.invoicesList));
    table.sort((a, b) => {
      return new Date(a[e.currentTarget.dataset.id]).getTime() >
        new Date(b[e.currentTarget.dataset.id]).getTime()
        ? 1 * reverse
        : -1 * reverse;
    });
    this.sortedColumn = e.currentTarget.dataset.id;
    this.compInvoices = table;
  }
}