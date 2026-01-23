import { LightningElement, api, wire, track } from 'lwc';
import { CloseActionScreenEvent } from 'lightning/actions';
import initData from '@salesforce/apex/BillectaBankIDAuthenticationHelper.initData';
import initBankIDAuthentication from '@salesforce/apex/BillectaBankIDAuthenticationHelper.initBankIDAuthentication';
import getBankIDAuthenticationStatus from '@salesforce/apex/BillectaBankIDAuthenticationHelper.getBankIDAuthenticationStatus';
import BANKID_SVG from "@salesforce/resourceUrl/bankID_logo";
import BANKID_SVG_white from "@salesforce/resourceUrl/bankID_logo_white";

export default class AuthenticateWithBankId extends LightningElement {
    @api recordId;
    @api isLoading = false;
    @api isLoaded = false;
    @api showStartButton = false;
    
    @track currentObj;
    @track errorMessage = false;
    @track status;

    @wire(initData, {recordId: '$recordId'})
    BillectaBankIDAuthenticationHelper({ error, data }) {
        if (data) {
            console.log(data);
            this.currentObj = data;
            this.status = this.currentObj.status;
            this.BANKIDLOGO = BANKID_SVG;
            this.BANKIDLOGOWHITE = BANKID_SVG_white;
            this.showStartButton = true;
        } else if (error) {
            this.error = error;
            console.log(this.error);
        }
    }

    initBankId() {
        this.resetSettings();
        initBankIDAuthentication({ currentObj: this.currentObj})
            .then((result) => {
                console.log(result);
                this.currentObj = result;
                this.status = this.currentObj.status; 
                this.progress = setInterval(() => {
                    console.log('Status ', this.status);
                    if(this.status === "Success" || this.status === "Started"){
                        getBankIDAuthenticationStatus({ currentObj: this.currentObj })
                        .then((result) => {
                            console.log('result', result);
                            this.currentObj = result;
                            this.status = this.currentObj.status;
                            this.isLoading = true;
                            this.showStartButton = false;
                        })
                        .catch((error) => {
                            console.log('getBankIDAuthenticationStatusError: ' + JSON.parse(JSON.stringify(error)));
                        });
                    } else if(this.status === "Complete"){
                        clearInterval(this.progress);
                        this.isLoaded = true;
                        this.isLoading = false;
                    } else {
                        clearInterval(this.progress);
                        this.isLoaded = true;
                        this.isLoading = false;
                        this.errorMessage = true;
                        this.showStartButton = true;
                    }
                }, 2000);
            })
            .catch((error) => {
                console.log('initBankIDAuthenticationError: ' + JSON.parse(JSON.stringify(error)));
            });
    }

    closeAction() {
        clearInterval(this.progress);
        this.dispatchEvent(new CloseActionScreenEvent());
    }

    resetSettings(){
        this.errorMessage = false;
        this.status = 'Initiated';
        this.isLoaded = false;
    }
}