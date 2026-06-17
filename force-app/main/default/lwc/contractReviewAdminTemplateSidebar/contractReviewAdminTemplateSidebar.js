/**
 * Left-hand sidebar listing every `ContractReviewTemplate__mdt`. Emits a
 * `select` custom event with the chosen template DeveloperName.
 */
import { LightningElement, api } from "lwc";

export default class ContractReviewAdminTemplateSidebar extends LightningElement {
  @api templates;

  selectedDeveloperName;

  get decoratedTemplates() {
    if (!this.templates) {
      return [];
    }
    return this.templates.map((tmpl) => {
      const isActive = tmpl.DeveloperName === this.selectedDeveloperName;
      return {
        ...tmpl,
        isActive,
        itemClass:
          "slds-nav-vertical__item sidebar-item" +
          (isActive ? " slds-is-active sidebar-item-active" : "")
      };
    });
  }

  handleTemplateClick(event) {
    event.preventDefault();

    const developerName = event.currentTarget.dataset.developerName;

    const selected = this.templates.find(
      (tmpl) => tmpl.DeveloperName === developerName
    );

    if (selected) {
      this.selectedDeveloperName = developerName;
      this.dispatchEvent(
        new CustomEvent("templateselected", { detail: selected })
      );
    } else {
    }
  }

  handleNewClick() {
    this.selectedDeveloperName = null;
    this.dispatchEvent(new CustomEvent("templatecreate"));
  }
}