import { LightningElement, api, track } from 'lwc';
import createLookupSession from '@salesforce/apex/BillectaBankAccountService.createLookupSession';
import saveSuccessfulLookup from '@salesforce/apex/BillectaBankAccountPersistenceService.saveSuccessfulLookup';
import saveFailedLookup from '@salesforce/apex/BillectaBankAccountPersistenceService.saveFailedLookup';

export default class BillectaBankAccountLookup extends LightningElement {
    @api recordId;
    @api personalIdNumber;

    @track isLoading = false;
    @track errorMessage;
    @track statusMessage;
    client;
    scriptLoaded = false;

    renderedCallback() {
        if (this.scriptLoaded) {
            return;
        }
        this.scriptLoaded = true;
    }

    async handleStart() {
        this.isLoading = true;
        this.errorMessage = null;
        this.statusMessage = null;

        try {
            const session = await createLookupSession({
                personalIdNumber: this.personalIdNumber
            });

            await this.loadExternalScript(session.clientScriptUrl);

            const options = {};
            if (session.accountLookupBaseUrl) {
                options.baseUrl = session.accountLookupBaseUrl;
            }

            this.client = new window.Billecta(
                session.sessionToken,
                session.sessionId,
                options
            );

            this.client.start({
                selector: '#bank-account-iframe',
                onSuccessful: async (data) => {
                    this.statusMessage = 'Bankkonto hämtat.';
                    await saveSuccessfulLookup({
                        relatedRecordId: this.recordId,
                        sessionState: data.sessionState,
                        clearingNo: data.clearingNo,
                        accountNo: data.accountNo,
                        bank: data.bank,
                        bankName: data.bankName
                    });
                },
                onAborted: async (data) => {
                    this.statusMessage = 'Användaren avbröt processen.';
                    await saveFailedLookup({
                        relatedRecordId: this.recordId,
                        status: 'Aborted',
                        sessionState: data ? data.sessionState : null,
                        errorMessage: data ? data.errorMessage : null
                    });
                },
                onFailed: async (data) => {
                    this.errorMessage = data && data.errorMessage ? data.errorMessage : 'Tekniskt fel uppstod.';
                    await saveFailedLookup({
                        relatedRecordId: this.recordId,
                        status: 'Failed',
                        sessionState: data ? data.sessionState : null,
                        errorMessage: data ? data.errorMessage : null
                    });
                },
                width: '400px',
                height: '600px',
                colorTheme: 'light'
            });
        } catch (e) {
            this.errorMessage = this.normalizeError(e);
        } finally {
            this.isLoading = false;
        }
    }

    handleStop() {
        try {
            if (this.client && typeof this.client.stop === 'function') {
                this.client.stop();
            }
        } catch (e) {
            this.errorMessage = this.normalizeError(e);
        }
    }

    loadExternalScript(src) {
        return new Promise((resolve, reject) => {
            const existing = this.template.querySelector('script[data-billecta="true"]');
            if (existing) {
                resolve();
                return;
            }

            const script = document.createElement('script');
            script.src = src;
            script.async = true;
            script.dataset.billecta = 'true';
            script.onload = () => resolve();
            script.onerror = () => reject(new Error('Kunde inte ladda Billecta client script.'));
            this.template.appendChild(script);
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