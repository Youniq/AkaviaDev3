import { LightningElement, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { getRecordNotifyChange } from 'lightning/uiRecordApi';
import { CloseActionScreenEvent } from 'lightning/actions';
import generateForAccount from '@salesforce/apex/GdprRegisterutdragController.generateForAccount';

export default class GdprRegisterutdragAction extends LightningElement {
    @api recordId;
    _hasRun = false;
    loading = true;

    get showSpinner() {
        return this.loading;
    }

    connectedCallback() {
        // Kör automatiskt när quick action öppnas, men bara en gång.
        if (this._hasRun) {
            return;
        }

        const start = () => {
            if (!this.recordId) {
                this.loading = false;
                this.showToast('Fel', 'Inget konto valt.', 'error');
                this.closeAction();
                return;
            }
            this._hasRun = true;
            this.run();
        };

        // I normala fall är recordId satt direkt, men vi väntar lite som fallback.
        if (this.recordId) {
            start();
        } else {
            setTimeout(start, 50);
        }
    }

    async run() {
        this.loading = true;
        try {
            const result = await generateForAccount({ accountId: this.recordId });
            const res = result && result.data !== undefined ? result.data : result;
            if (typeof console !== 'undefined' && console.debug) {
                console.debug('[GdprRegisterutdragAction] result=', res, 'success=', res?.success, 'contentDocumentId=', res?.contentDocumentId);
            }
            const explicitFailure = res && (res.success === false || res.success === 'false');
            const knownErrorMsg = res && res.message && typeof res.message === 'string' && res.message.length > 0;
            const isError = explicitFailure || knownErrorMsg && !res.success;
            if (res && !isError) {
                this.showToast(
                    'Klart',
                    (res.message && String(res.message).trim()) ||
                        'GDPR‑registerutdrag skapat och kopplat till personkontot.',
                    'success'
                );
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
            if (typeof console !== 'undefined' && console.error) {
                console.error('[GdprRegisterutdragAction] catch', e, 'body=', e?.body, 'message=', e?.message);
            }
            const msg =
                (e.body && e.body.message) ||
                (e.body &&
                    e.body.pageErrors &&
                    e.body.pageErrors[0] &&
                    e.body.pageErrors[0].message) ||
                e.message ||
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