/**
 * Renders the Svarstext (email draft) tab. Pure presentation: takes the HTML
 * draft as `@api draftHtml`, exposes a copy-to-clipboard button, and shows a
 * fallback message when no draft has been generated yet.
 */
import { LightningElement, api } from "lwc";

export default class ContractReviewViewerDraftTab extends LightningElement {
  @api responseDraft;
  @api responseDraftEng;
  @api svDraftPending = false;
  @api engDraftPending = false;
  @api engDraftError;

  _copyFeedback = null; // null | 'copied' | 'error'
  _engRequested = false;

  // ─── Swedish tab getters ───

  get hasSwedishDraft() {
    return this.responseDraft != null;
  }

  get showSwedishDraftToolbar() {
    return this.hasSwedishDraft;
  }

  // ─── English tab getters ───

  get hasEnglishDraft() {
    return this.responseDraftEng != null;
  }

  get showEnglishDraftToolbar() {
    return this.hasEnglishDraft;
  }

  get showEnglishEmpty() {
    return !this.hasEnglishDraft && !this.engDraftPending && !this.engDraftError;
  }

  // ─── Copy button getters ───

  get copyButtonLabel() {
    if (this._copyFeedback === 'copied') return 'Kopierad!';
    if (this._copyFeedback === 'error') return 'Kopiering misslyckades';
    return 'Kopiera svarsutkast';
  }

  get copyButtonIconName() {
    if (this._copyFeedback === 'copied') return 'utility:check';
    if (this._copyFeedback === 'error') return 'utility:warning';
    return 'utility:copy';
  }

  get copyButtonVariant() {
    if (this._copyFeedback === 'copied') return 'success';
    return 'neutral';
  }

  // ─── Handlers ───

  handleEnglishTabActive() {
    if (
      !this.hasEnglishDraft &&
      !this.engDraftPending &&
      !this.engDraftError &&
      !this._engRequested
    ) {
      this._engRequested = true;
      this.dispatchEvent(new CustomEvent('requestengdraft'));
    }
  }

  handleRetryEngDraft() {
    this._engRequested = false;
    this.dispatchEvent(new CustomEvent('requestengdraft'));
  }

  handleCopySwedishDraft() {
    this._copyToClipboard(this.responseDraft);
  }

  handleCopyEnglishDraft() {
    this._copyToClipboard(this.responseDraftEng);
  }

  _copyToClipboard(htmlContent) {
    try {
      const helper = this.template.querySelector('.copy-helper');
      if (!helper) return;
      // eslint-disable-next-line @lwc/lwc/no-inner-html
      helper.innerHTML = htmlContent;
      const range = document.createRange();
      range.selectNodeContents(helper);
      const sel = window.getSelection();
      sel.removeAllRanges();
      sel.addRange(range);
      document.execCommand('copy');
      sel.removeAllRanges();
      // eslint-disable-next-line @lwc/lwc/no-inner-html
      helper.innerHTML = '';
      this._setCopyFeedback('copied');
    } catch (err) {
      console.error('[ContractReviewViewerDraftTab] Copy failed:', err);
      this._setCopyFeedback('error');
    }
  }

  _setCopyFeedback(state) {
    this._copyFeedback = state;
    // eslint-disable-next-line @lwc/lwc/no-async-operation
    setTimeout(() => {
      this._copyFeedback = null;
    }, 2000);
  }
}