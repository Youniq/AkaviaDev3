import { LightningElement, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { getRecordNotifyChange } from 'lightning/uiRecordApi';
import { CloseActionScreenEvent } from 'lightning/actions';
import generateForAccount from '@salesforce/apex/GdprRegisterutdragController.generateForAccount';

export default class GdprRegisterutdragActionV2 extends LightningElement {
    @api recordId;
    _hasRun = false;
    loading = true;

    get showSpinner() {
        return this.loading;
    }

    /**
     * Headless record action entrypoint.
     * Salesforce anropar invoke() endast när användaren klickar på quick action-menypunkten,
     * inte när dropdown/pilen öppnas.
     */
    @api
    async invoke() {
        if (this._hasRun) return;
        this._hasRun = true;

        if (!this.recordId) {
            this.loading = false;
            this.showToast('Fel', 'Inget konto valt.', 'error');
            this.closeAction();
            return;
        }

        await this.run();
    }

    async run() {
        this.loading = true;
        try {
            const result = await generateForAccount({ accountId: this.recordId });
            const res = result && result.data !== undefined ? result.data : result;

            const explicitFailure = res && (res.success === false || res.success === 'false');
            const knownErrorMsg = res && res.message && typeof res.message === 'string' && res.message.length > 0;
            const isError = explicitFailure || (knownErrorMsg && !res.success);

            if (res && !isError) {
                const shortMsg =
                    (res.message && String(res.message).trim()) ||
                    'GDPR‑utdrag finns under Filer på kontot.';
                this.showToast('Klart', shortMsg, 'success');
                try {
                    getRecordNotifyChange([{ recordId: this.recordId }]).catch(() => {});
                } catch (refreshErr) {
                    // Ignore
                }
            } else {
                const msg =
                    res && res.message && String(res.message).trim()
                        ? res.message
                        : 'Kunde inte skapa GDPR‑registerutdrag.';
                this.showToast('Kunde inte skapa registerutdrag', msg, 'error');
            }
        } catch (e) {
            const msg =
                (e?.body && e.body.message) ||
                (e?.body && e.body.pageErrors && e.body.pageErrors[0] && e.body.pageErrors[0].message) ||
                e?.message ||
                String(e) ||
                'Ett oväntat fel uppstod.';
            this.showToast('Fel', msg, 'error');
        } finally {
            this.loading = false;
            setTimeout(() => this.closeAction(), 150);
        }
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    closeAction() {
        try {
            this.dispatchEvent(new CloseActionScreenEvent());
        } catch (e) {
            // Ignore if no action screen to close (e.g. headless)
        }
    }
}