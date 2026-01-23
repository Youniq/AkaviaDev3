/**
 * @description       : Reusable component to Display a Page Header in Akavias Mina Sidor
 * @author            : Håkon Kavli
 * @group             : Stretch Engage
 * @last modified on  : 11-15-2021
 * @last modified by  : Håkon Kavli
 **/
import { LightningElement, api } from "lwc";
import { loadStyle } from "lightning/platformResourceLoader";
import AkaviaCSS from "@salesforce/resourceUrl/AkaviaCSS";

export default class PageHeader extends LightningElement {
  @api mainHeader;
  @api preamble;

  connectedCallback() {
    loadStyle(this, AkaviaCSS);
    //you can add a .then().catch() if you'd like, as loadStyle() returns a promise
    //console.log("Loader Header");
  }
}