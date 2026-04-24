import { LightningElement, api, track } from 'lwc';
import startAutogiroChange from '@salesforce/apex/NewBillectaAutogiroService.startAutogiroChange';
import completeAutogiroChange from '@salesforce/apex/NewBillectaAutogiroService.completeAutogiroChange';
import failAutogiroChange from '@salesforce/apex/NewBillectaAutogiroService.failAutogiroChange';

export default class AutogiroBankAccountChange extends LightningElement {
    @api recordId;

    @track isLoading = false;
    @track statusMessage;
    @track errorMessage;

    autogiroChangeLogId;
    billectaClient;
    scriptAlreadyLoaded = false;

    async handleStart() {
        this.isLoading = true;
        this.statusMessage = null;
        this.errorMessage = null;

        try {
            const session = await startAutogiroChange({
                accountId: this.recordId
            });

            this.autogiroChangeLogId = session.autogiroChangeLogId;

            await this.loadBillectaScript(session.clientScriptUrl);

            const options = {};
            if (session.accountLookupBaseUrl) {
                options.baseUrl = session.accountLookupBaseUrl;
            }

            this.billectaClient = new window.Billecta(
                session.sessionToken,
                session.sessionId,
                options
            );

            this.billectaClient.start({
                selector: '#bank-account-iframe',
                onSuccessful: async (data) => {
                    try {
                        await completeAutogiroChange({
                            autogiroChangeLogId: this.autogiroChangeLogId,
                            sessionState: data ? data.sessionState : null,
                            clearingNo: data ? data.clearingNo : null,
                            accountNo: data ? data.accountNo : null,
                            bank: data ? data.bank : null,
                            bankName: data ? data.bankName : null
                        });

                        this.statusMessage = 'Autogiroändringen är klar.';
                        this.errorMessage = null;
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
            }
        } catch (e) {
            this.errorMessage = this.normalizeError(e);
        }
    }

    loadBillectaScript(scriptUrl) {
        return new Promise((resolve, reject) => {
            if (this.scriptAlreadyLoaded && window.Billecta) {
                resolve();
                return;
            }

            const existing = this.template.querySelector('script[data-billecta-script="true"]');
            if (existing) {
                this.scriptAlreadyLoaded = true;
                resolve();
                return;
            }

            const script = document.createElement('script');
            script.src = scriptUrl;
            script.async = true;
            script.dataset.billectaScript = 'true';

            script.onload = () => {
                this.scriptAlreadyLoaded = true;
                resolve();
            };

            script.onerror = () => {
                reject(new Error('Kunde inte ladda Billectas klientscript.'));
            };

            const container = this.template.querySelector('.script-container');
            container.appendChild(script);
        });
    }

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