import { LightningElement, api, track } from 'lwc';
import startAutogiroChange from '@salesforce/apex/NewBillectaAutogiroService.startAutogiroChange';
import completeAutogiroChange from '@salesforce/apex/NewBillectaAutogiroService.completeAutogiroChange';
import failAutogiroChange from '@salesforce/apex/NewBillectaAutogiroService.failAutogiroChange';
import { loadScript } from 'lightning/platformResourceLoader';
import BILLECTA_CLIENT from '@salesforce/resourceUrl/BillectaAccountlookupClientJS';

export default class AutogiroBankAccountChange extends LightningElement {
    @api recordId;
    @api accountId;

    get effectiveAccountId() {
        return this.recordId || this.accountId;
    }

    @track isLoading = false;
    @track statusMessage;
    @track errorMessage;

    autogiroChangeLogId;
    billectaClient;
    scriptAlreadyLoaded = false;

    hasStarted = false;

    renderedCallback() {
        if (this.hasStarted) {
            return;
        }
    
        if (!this.effectiveAccountId) {
            return;
        }
    
        const container = this.template.querySelector('.bank-account-iframe');
        if (!container) {
            return;
        }
    
        this.hasStarted = true;
        this.handleStart();
    }

    async handleStart() {
        this.isLoading = true;
        this.statusMessage = null;
        this.errorMessage = null;

        try {
            const session = await startAutogiroChange({
                accountId: this.effectiveAccountId
            });

            this.autogiroChangeLogId = session.autogiroChangeLogId;

            await this.loadBillectaScript();
            //await this.loadBillectaScript(session.clientScriptUrl);

            const options = {};
            if (session.accountLookupBaseUrl) {
                options.baseUrl = session.accountLookupBaseUrl;
            }

            this.billectaClient = new window.Billecta(
                session.sessionToken,
                session.sessionId,
                options
            );

            const container = this.template.querySelector('.bank-account-iframe');

            this.billectaClient.start({
                container: container,
                onSuccessful: async (data) => {
                    try {
                        await completeAutogiroChange({
                            autogiroChangeLogId: this.autogiroChangeLogId,
                            sessionState: data ? data.sessionState : null,
                            clearingNo: data ? data.clearingNo : null,
                            accountNo: data ? data.accountNo : null,
                            bank: data ? data.bank : null,
                            bankName: data ? data.bankName : null,
                            autogiroJson: data ? data.autogiroJson : null
                        });

                        this.statusMessage = 'Autogiroändringen är klar.';
                        this.errorMessage = null;

                        this.dispatchEvent(new CustomEvent('success'));

                    } catch (e) {
                        this.errorMessage = this.normalizeError(e);
                    }
                },
                onAborted: async (data) => {
                    try {
                        await failAutogiroChange({
                            autogiroChangeLogId: this.autogiroChangeLogId,
                            status: 'Aborted',
                            sessionState: data ? data.sessionState : null,
                            errorMessage: data ? data.errorMessage : 'Användaren avbröt flödet.'
                        });

                        this.statusMessage = 'Kontohämtningen avbröts.';
                        this.errorMessage = null;
                    } catch (e) {
                        this.errorMessage = this.normalizeError(e);
                    }
                },
                onFailed: async (data) => {
                    try {
                        await failAutogiroChange({
                            autogiroChangeLogId: this.autogiroChangeLogId,
                            status: 'Failed',
                            sessionState: data ? data.sessionState : null,
                            errorMessage: data ? data.errorMessage : 'Tekniskt fel uppstod.'
                        });
                    } catch (e) {
                        this.errorMessage = this.normalizeError(e);
                        return;
                    }

                    this.errorMessage = data && data.errorMessage
                        ? data.errorMessage
                        : 'Tekniskt fel uppstod vid kontohämtning.';
                    this.statusMessage = null;
                },
                width: '400px',
                height: '600px',
                colorTheme: 'light'
            });
        } catch (e) {
            this.errorMessage = this.normalizeError(e);
            this.statusMessage = null;
        } finally {
            this.isLoading = false;
        }
    }

    handleStop() {
        try {
            if (this.billectaClient && typeof this.billectaClient.stop === 'function') {
                this.billectaClient.stop();
                this.statusMessage = 'Kontohämtningen har stoppats.';

                this.dispatchEvent(new CustomEvent('close'));
            }
        } catch (e) {
            this.errorMessage = this.normalizeError(e);
        }
    }

    // Load Billecta's client script using Salesforce's static resource loader
    loadBillectaScript() {
        if (this.scriptAlreadyLoaded) {
            return Promise.resolve();
        }

        return loadScript(this, BILLECTA_CLIENT)
            .then(() => {
                this.scriptAlreadyLoaded = true;
            })
            .catch(error => {
                throw new Error('Unable to load Billecta script: ' + error.message);
            });
    }
    /** Fetch from Billecta's CDN instead of using static resources. Note! Gives CORS sameorigin policy issue 
     * and is blocked by browser extensions.
    loadBillectaScript(scriptUrl) {
        return new Promise((resolve, reject) => {
            if (this.scriptAlreadyLoaded && window.Billecta) {
                resolve();
                return;
            }

            const script = document.createElement('script');
            script.src = scriptUrl;
            script.async = true;

            script.onload = () => {
                this.scriptAlreadyLoaded = true;
                resolve();
            };

            script.onerror = () => {
                reject(new Error('Unable to load Billecta script.'));
            };

            document.body.appendChild(script);
        });
    }
         */

    normalizeError(error) {
        if (!error) {
            return 'Okänt fel.';
        }
        if (error.body && error.body.message) {
            return error.body.message;
        }
        if (error.message) {
            return error.message;
        }
        return JSON.stringify(error);
    }
}