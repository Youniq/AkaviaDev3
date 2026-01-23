import { LightningElement, api, wire, track } from 'lwc';
import { CurrentPageReference } from 'lightning/navigation';
import { getRecord } from 'lightning/uiRecordApi';

export default class LogCallPanel extends LightningElement {
    @track activeSection = [];
    @track open = false;
    _recordId;
    @api objectApiNameFilter; // optional filter for object api name (e.g., Account, CustomObject__c)
    @api personAccountsOnly = false; // require person account when on Account
    @api defaultOpen = false; // design-time toggle for initial open/closed
    @track show = true;
    _objectApiName;
    _recordData;

    @api
    get recordId(){ return this._recordId; }
    set recordId(v){ this._recordId = v; }

    @wire(CurrentPageReference)
    getPageReference(pageRef) {
        const recId = pageRef?.state?.recordId || pageRef?.attributes?.recordId;
        if (recId) {
            this.recordId = recId;
            // Ensure panel is closed when navigating to a record
            this.open = false;
        }
        // Track object api name from page ref
        this._objectApiName = pageRef?.attributes?.objectApiName || pageRef?.state?.objectApiName || this._objectApiName;
        this.evaluateVisibility();
    }

    handleSectionToggle(evt){
        this.activeSection = evt.detail.openSections;
    }

    connectedCallback(){
        // Force closed on initial load regardless of design property
        this.open = false;
    }

    // Safe layout-based record fetch; works for any object. We'll read IsPersonAccount when present.
    @wire(getRecord, { recordId: '$_recordId', layoutTypes: ['Full'], modes: ['View'] })
    wiredRecord(w){
        this._recordData = w?.data || null;
        this.evaluateVisibility();
    }

    evaluateVisibility(){
        let visible = true;
        const objName = (this._objectApiName || '').toLowerCase();
        // Filter by object API name if provided
        if (this.objectApiNameFilter && objName && objName !== this.objectApiNameFilter.toLowerCase()) {
            visible = false;
        }
        // Person Account restriction
        if (visible && this.personAccountsOnly) {
            if (objName && objName !== 'account') {
                // If we definitively know we're not on Account, hide
                visible = false;
            } else {
                // On Account or unknown context (e.g., App Builder preview):
                // Only hide when we know it's NOT a Person Account.
                const isPersonVal = this._recordData?.fields?.IsPersonAccount?.value;
                if (isPersonVal === false) {
                    visible = false;
                } else {
                    // true or unknown -> keep visible
                    visible = true;
                }
            }
        }
        this.show = visible;
    }

    toggleOpen(){
        this.open = !this.open;
    }
    get toggleIcon(){
        return this.open ? 'utility:chevrondown' : 'utility:chevronright';
    }

    // Allow Aura host to explicitly collapse the panel
    @api collapse(){
        this.open = false;
    }
}