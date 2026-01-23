import { LightningElement, api, wire, track } from 'lwc';
 import { getRecord } from "lightning/uiRecordApi";
import { loadStyle } from "lightning/platformResourceLoader";
import { NavigationMixin } from 'lightning/navigation';
import { pubsub, sortObjArrayByProperty, sortObjArrByDateProperty, sortEventTriggeredOk } from 'c/utils';
import {caseService} from 'c/services';
import { Case } from 'c/models';
import { caseLabels } from 'c/labels';

// Fields
import Id from "@salesforce/user/Id";
import ACCOUNTID_FIELD from "@salesforce/schema/User.AccountId";

// Static Resources
import AkaviaStyles_Community from "@salesforce/resourceUrl/AkaviaStyles_Community";

export default class AccountCases extends NavigationMixin(LightningElement) {
    // Private variables
    labels;
    loading;
    accountId;
    userId;
    sortAsc;   
    caseInfoPageRef; // PageReference object used for navigation
    url; // just for show, when user hovers link
    @track userCases;
    @track _sortedState;

    // Public variables
    @api displayComponentHeader;

    get sortedState() {
        return this._sortedState;
    }

    get hasCases() {
        return this.userCases && this.userCases.length ? true : false;
    }

    get noCases() {
        return this.userCases && !this.userCases.length ? true : false;
    }

    get hasCasesError() {
        return !this.loading && !this.userCases ? true : false;
    }

    /**
     * Handles outputting correct information in 'aria-sort' attribute on <table> used by screen readers.
     */
    set sortedState(activeCol) {
        const stateCopy = {...this._sortedState};
        Object.keys(stateCopy).forEach(key => {
            if(key === activeCol) {
                this._sortedState[key] = {...stateCopy[key],
                                    active: true,
                                    sortOrder: this.sortAsc ? 'ascending': 'descending'
                                }
            } else {
                this._sortedState[key] = {...this._sortedState[key],
                    active: false,
                    sortOrder: 'none'
                }
            }
        });      
    }

    constructor() {
        super();
        this.labels = caseLabels;
        this.userId = Id;
        this.loading = true;
    }

    connectedCallback() {
        //you can add a .then().catch() if you'd like, as loadStyle() returns a promise
        loadStyle(this, AkaviaStyles_Community);
        pubsub.registerListener()
        pubsub.registerListener('newcaseadded', this.callGetAccountCases, this);
    }

    disconnectedCallback() {
        pubsub.unregisterAllListeners(this);
    }

    /**
     * wired method to retrieve curr users account id information. 
     * With account id information, call dependent function.  
     * @param {*} param0 
     */
    @wire(getRecord, {recordId: "$userId", fields: ACCOUNTID_FIELD})
    async wiredUser({ data, error }) {
        if (error) {            
            console.error(`ERROR in wiredUser`, error);
        } else if (data) {
            this.accountId = data.fields.AccountId.value;
            await this.callGetAccountCases();
            this.loading = false;
        }
    }

    /**
     * Calls Apex method to retrieve all account cases for an account.
     */
    async callGetAccountCases() {
        const result = await caseService.getCasesByAccount(this.accountId);
        if(result) {
            const baseUrl = document.location.href.slice(0, document.location.href.lastIndexOf('/'));
            const pageUrl = `${baseUrl}/case-info`; 
            this.userCases = [...result].map(item => {
                const itemCopy = {...new Case(item)};
                itemCopy.caseUrl = `${pageUrl}?id=${itemCopy.Id}`;
                return itemCopy;
            });
            // setup the sorted state
            this.initSortedState(this.userCases[0]); 
        }
        // shows error from get hasCasesError()
    }

    // Initiating object wich is resposible for outputting correct information in 'aria-sort' attribute used by screen readers.
    initSortedState(obj) {
        if(!obj){
            return;
        }

        this._sortedState = {};
        Object.keys(obj).forEach(col => {
            this._sortedState = {
                    ...this._sortedState, 
                    [col]: {
                        active: (col === 'CreatedDate') ? true : false,
                        sortOrder: (col === 'CreatedDate') ? 'descending' : 'none'
                    }
                };
        });
    }

    handleSortTextField(evt) {   
        evt.stopPropagation();
       
        if(!sortEventTriggeredOk(evt)){
            return;
        }
        const target = evt.currentTarget;
        this.sortAsc = this.sortAsc ? false : true;
        const sortField = target.parentNode.dataset.field;
        this.userCases = sortObjArrayByProperty([...this.userCases], sortField, this.sortAsc);
        this.sortedState = sortField;
    }

    handleSortDateField(evt) {
        evt.stopPropagation();
        if(!sortEventTriggeredOk(evt)){
            return;
        }

        const target = evt.currentTarget;
        this.sortAsc = this.sortAsc ? false : true;
        const sortField = target.parentNode.dataset.field;
        this.userCases = sortObjArrByDateProperty([...this.userCases], sortField, this.sortAsc);
        this.sortedState = sortField;
    }

    // Use Navigation mixin for navigation as Sf documentation says you should.
    // This one is faster than linking to the same url, since this doens't reload all page header and so on... 
    handleLinkClick(evt){
        evt.preventDefault();
        evt.stopPropagation();

        const target = evt.target;
        const parent = target.parentNode;
        const caseId = parent.dataset.id; 

        // Using the PageReference way to navigate to other page as thisis the LWC recommended way. It loads much faster than linking the page in a traditional way. 
        this.caseInfoPageRef = {
            type: 'comm__namedPage',
            attributes: {
                name: 'Case_Info__c'
            },
            state: {
                id: caseId // send as query param.
            }
        };
        // navigate to page
        this[NavigationMixin.Navigate](this.caseInfoPageRef);
    }
}