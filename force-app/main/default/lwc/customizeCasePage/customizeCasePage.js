import { LightningElement } from "lwc";
import { loadStyle } from "lightning/platformResourceLoader";
// Static Resources
import AkaviaCustomizeCase from "@salesforce/resourceUrl/AkaviaCustomizeCase";

//An LWC component which modifies the overall css on the Salesforce Standard Lightning Case Record Page
export default class CustomizeCasePage extends LightningElement {
  connectedCallback() {
    loadStyle(this, AkaviaCustomizeCase);
  }
}