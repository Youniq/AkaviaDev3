import { LightningElement, api, wire } from 'lwc';
import { CurrentPageReference } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { getRecordNotifyChange } from 'lightning/uiRecordApi';
import { CloseActionScreenEvent } from 'lightning/actions';
import generateRegisterutdrag from '@salesforce/apex/RegisterutdragController.generateRegisterutdrag';

/**
 * Quick Action: Ett klick på den VITA "Ta ut registerutdrag" i action-baren skapar utdraget direkt.
 * Ingen mörkgrå knapp – bara spinner sedan klart. Komponenten får endast användas som Quick Action.
 * LÄGG ALDRIG IN denna komponent på Case-sidan i App Builder – då skapas utdrag varje gång man öppnar ärendet.
 */
export default class RegisterutdragAction extends LightningElement {
    _recordId;
    _hasRun = false;
    loading = true;

    get showSpinner() {
        return this.recordId && this.loading;
    }

    @api
    get recordId() {
        return this._recordId;
    }
    set recordId(value) {
        this._recordId = value;
        if (value && !this._hasRun) {
            this._hasRun = true;
            this.run();
        }
    }

    @wire(CurrentPageReference)
    wiredPageRef(wireResult) {
        const pageRef = wireResult && (wireResult.data !== undefined ? wireResult.data : wireResult);
        if (!pageRef || this._recordId) return;
        const id = (pageRef.attributes && pageRef.attributes.recordId) || (pageRef.state && pageRef.state.recordId);
        if (id) {
            this._recordId = id;
            if (!this._hasRun) {
                this._hasRun = true;
                this.run();
            }
        }
    }

    connectedCallback() {
        if (this._recordId && !this._hasRun) {
            this._hasRun = true;
            this.run();
            return;
        }
        if (this._recordId) return;
        const self = this;
        setTimeout(() => {
            if (self._recordId && !self._hasRun) {
                self._hasRun = true;
                self.run();
                return;
            }
            if (!self._hasRun) {
                self._hasRun = true;
                self.loading = false;
                self.showToast('Fel', 'Inget ärende valt.', 'error');
                setTimeout(() => self.closeAction(), 150);
            }
        }, 150);
    }

    async run() {
        this.loading = true;
        try {
            const result = await generateRegisterutdrag({ caseId: this.recordId });
            const res = result && result.data !== undefined ? result.data : result;
            if (typeof console !== 'undefined' && console.debug) {
                console.debug('[RegisterutdragAction] result=', res, 'success=', res?.success, 'contentDocumentId=', res?.contentDocumentId);
            }
            const explicitFailure = res && (res.success === false || res.success === 'false');
            const knownErrorMsg = res && res.message && typeof res.message === 'string' && (
                res.message.includes('saknas') || res.message.includes('kunde inte hittas') ||
                res.message.includes('ingen kopplad') || res.message.includes('Ingen data kunde samlas')
            );
            const knownSuccessMsg = res && res.message && typeof res.message === 'string' && res.message.includes('Registerutdrag skapat');
            const isError = (explicitFailure || knownErrorMsg) && !knownSuccessMsg;
            if (res && !isError) {
                this.showToast('Klart', (res.message && String(res.message).trim()) || 'Registerutdrag skapat och kopplat till ärendet.', 'success');
                try {
                    getRecordNotifyChange([{ recordId: this.recordId }]).catch(() => {});
                } catch (refreshErr) {
                    // Ignore
                }
            } else {
                const msg = (res && res.message && String(res.message).trim()) ? res.message : 'Ett fel uppstod. Kontrollera att ärendet har en kopplad kontakt.';
                this.showToast('Kunde inte skapa registerutdrag', msg, 'error');
            }
        } catch (e) {
            if (typeof console !== 'undefined' && console.error) {
                console.error('[RegisterutdragAction] catch', e, 'body=', e?.body, 'message=', e?.message);
            }
            const msg = (e.body && e.body.message) || (e.body && e.body.pageErrors && e.body.pageErrors[0] && e.body.pageErrors[0].message) || e.message || String(e) || 'Ett oväntat fel uppstod.';
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