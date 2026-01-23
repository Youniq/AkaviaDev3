import { LightningElement, api } from "lwc";

export default class ToggledConent extends LightningElement {
  @api helpText; // Tooltip text
  @api label; // string , The text displayed next to toggler
  @api toggleState; // boolean

  handleToggle(evt) {
    const checked = evt.target.checked;
    const event = new CustomEvent("toggle", { detail: { checked: checked } });
    this.dispatchEvent(event);
  }
}