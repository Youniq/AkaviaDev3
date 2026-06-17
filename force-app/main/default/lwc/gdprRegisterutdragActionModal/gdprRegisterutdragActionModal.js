import { LightningElement, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { getRecordNotifyChange } from 'lightning/uiRecordApi';
import { CloseActionScreenEvent } from 'lightning/actions';
import generateForAccountWithFormat from '@salesforce/apex/GdprRegisterutdragController.generateForAccountWithFormat';

export default class GdprRegisterutdragActionModal extends LightningElement {
    @api recordId;
    loading = false;
    selectedFormat = 'CSV';

    get formatOptions() {
        return [
            { label: 'CSV (standard)', value: 'CSV' },
            { label: 'Excel (.xls)', value: 'XLS' }
        ];
    }

    handleFormatChange(event) {
        this.selectedFormat = event.detail.value;
    }

    handleCancel() {
        this.close();
    }

    async handleCreate() {
        if (!this.recordId) {
            this.showToast('Fel', 'Inget konto valt.', 'error');
            this.close();
            return;
        }

        this.loading = true;
        try {
            const result = await generateForAccountWithFormat({
                accountId: this.recordId,
                format: this.selectedFormat
            });
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
                } catch (e) {
                    // ignore
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
            this.close();
        }
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    close() {
        try {
            this.dispatchEvent(new CloseActionScreenEvent());
        } catch (e) {
            // ignore
        }
    }
}