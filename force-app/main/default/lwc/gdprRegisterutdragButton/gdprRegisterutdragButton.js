import { LightningElement, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import generateForAccount from '@salesforce/apex/GdprRegisterutdragController.generateForAccount';

export default class GdprRegisterutdragButton extends LightningElement {
    @api recordId;
    loading = false;

    get isDisabled() {
        return this.loading || !this.recordId;
    }

    async handleClick() {
        if (!this.recordId) {
            this.showToast('Fel', 'Inget personkonto valt.', 'error');
            return;
        }
        this.loading = true;
        try {
            const result = await generateForAccount({ accountId: this.recordId });
            const res = result && result.data !== undefined ? result.data : result;
            const explicitFailure = res && (res.success === false || res.success === 'false');
            const knownErrorMsg =
                res && res.message && typeof res.message === 'string' && res.message.length > 0;
            const isError =
                !res || explicitFailure || (knownErrorMsg && res.success !== true && res.success !== 'true');

            if (res && !isError) {
                const shortMsg =
                    (res.message && String(res.message).trim()) ||
                    'GDPR‑utdrag finns under Filer på kontot.';
                this.showToast('Klart', shortMsg, 'success');
            } else {
                const msg =
                    res && res.message
                        ? res.message
                        : 'Kunde inte skapa GDPR‑registerutdrag.';
                this.showToast('Kunde inte skapa registerutdrag', msg, 'error');
            }
        } catch (e) {
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
        }
    }

    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({
                title,
                message,
                variant
            })
        );
    }
}