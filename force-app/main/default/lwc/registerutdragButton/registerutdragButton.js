import { LightningElement, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { getRecordNotifyChange } from 'lightning/uiRecordApi';
import generateRegisterutdrag from '@salesforce/apex/RegisterutdragController.generateRegisterutdrag';

export default class RegisterutdragButton extends LightningElement {
    @api recordId;
    loading = false;

    get isDisabled() {
        return this.loading || !this.recordId;
    }

    async handleGenerate() {
        if (!this.recordId) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Fel',
                message: 'Inget ärende valt.',
                variant: 'error'
            }));
            return;
        }
        this.loading = true;
        try {
            const result = await generateRegisterutdrag({ caseId: this.recordId });
            const res = result && result.data !== undefined ? result.data : result;
            if (typeof console !== 'undefined' && console.debug) {
                console.debug('[Registerutdrag] result=', res, 'success=', res?.success, 'contentDocumentId=', res?.contentDocumentId);
            }
            const explicitFailure = res && (res.success === false || res.success === 'false');
            const knownErrorMsg = res && res.message && typeof res.message === 'string' && (
                res.message.includes('saknas') || res.message.includes('kunde inte hittas') ||
                res.message.includes('ingen kopplad') || res.message.includes('Ingen data kunde samlas')
            );
            const knownSuccessMsg = res && res.message && typeof res.message === 'string' && res.message.includes('Registerutdrag skapat');
            const isError = (explicitFailure || knownErrorMsg) && !knownSuccessMsg;
            if (res && !isError) {
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Klart',
                    message: (res.message && String(res.message).trim()) || 'Registerutdrag skapat och kopplat till ärendet.',
                    variant: 'success'
                }));
                try {
                    getRecordNotifyChange([{ recordId: this.recordId }]).catch(() => {});
                } catch (refreshErr) {
                    // Ignore
                }
            } else {
                const msg = (res && res.message && String(res.message).trim()) ? res.message : 'Ett fel uppstod. Kontrollera att ärendet har en kopplad kontakt.';
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Kunde inte skapa registerutdrag',
                    message: msg,
                    variant: 'error'
                }));
            }
        } catch (e) {
            if (typeof console !== 'undefined' && console.error) {
                console.error('[Registerutdrag] catch', e, 'body=', e?.body, 'message=', e?.message);
            }
            const msg = (e.body && e.body.message) || (e.body && e.body.pageErrors && e.body.pageErrors[0] && e.body.pageErrors[0].message) || e.message || String(e) || 'Ett oväntat fel uppstod.';
            this.dispatchEvent(new ShowToastEvent({
                title: 'Fel',
                message: msg,
                variant: 'error'
            }));
        } finally {
            this.loading = false;
        }
    }
}