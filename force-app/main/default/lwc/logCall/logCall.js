import { LightningElement, track, wire, api } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { getEnclosingUtilityId, minimizeUtility, closeUtility } from 'lightning/platformUtilityBarApi';
import { CurrentPageReference } from 'lightning/navigation';
import { CloseActionScreenEvent } from 'lightning/actions';
import { getRecord, getFieldValue, getRecordNotifyChange } from 'lightning/uiRecordApi';
import { refreshApex } from '@salesforce/apex';
import { RefreshEvent } from 'lightning/refresh';
import createCallTaskWithMentions from '@salesforce/apex/LogCallController.createCallTaskWithMentions';
import getTaskTypePicklistValues from '@salesforce/apex/LogCallController.getTaskTypePicklistValues';
import ACCOUNT_PERSON_CONTACT_ID from '@salesforce/schema/Account.PersonContactId';
import searchUsersForMention from '@salesforce/apex/LogCallController.searchUsersForMention';

const STORAGE_KEY_BASE = 'callLogComments';
const TYPE_STORAGE_KEY_BASE = 'callLogCaseTypes';
const DEBOUNCE_DELAY = 500;
// Expire local draft cache after 2 days (in milliseconds)
const TTL_MS = 2 * 24 * 60 * 60 * 1000;

export default class CallLog extends NavigationMixin(LightningElement) {
    @track comments = '';
    @track caseTypes = [];
    @track saveStatus = '';
    @track typeOptions = [];
    _recordId;
    @api
    get recordId(){
        return this._recordId;
    }
    set recordId(val){
        if (this._recordId !== val){
            const oldVal = this._recordId;
            this._recordId = val;
            // React to record context change: load draft for new record or clear
            this.applyDraftForCurrentRecordOrClear();
            // If switching between records while docked in Utility Bar, auto-minimize to avoid carry-over visibility
            if (oldVal && val && oldVal !== val) {
                this.hidePanelIfUtility();
            }
        }
    }
    @track accountData;
    @track mentionedUsers = []; // For @mentions
     // Mention UI state
    @track showSuggestions = false;
    @track suggestions = [];
    highlightedIndex = 0;
    // Track current mention token bounds
    mentionStart = -1;
    debounceTimer;

    @wire(CurrentPageReference)
    getPageReference(pageRef) {
        const recId = pageRef?.state?.recordId || pageRef?.attributes?.recordId;
        if (recId) {
            this.recordId = recId;
        }
    }

    async hidePanelIfUtility(){
        try {
            const utilityId = await getEnclosingUtilityId();
            if (utilityId) {
                // Prefer close (fully hides panel); fall back to minimize if unavailable
                try {
                    await closeUtility({ utilityId });
                } catch (e) {
                    await minimizeUtility({ utilityId });
                }
            }
        } catch(e) {
            // Not in a utility context or API not available; safely ignore
        }
    }

    _wiredAccount; // store wire result for refresh
    @wire(getRecord, { recordId: '$recordId', fields: [ACCOUNT_PERSON_CONTACT_ID] })
    wiredAccount(result) {
        this._wiredAccount = result;
        const { error, data } = result || {};
        if (data) {
            this.accountData = data;
        }
    }

    get personContactId() {
        return this.accountData ? getFieldValue(this.accountData, ACCOUNT_PERSON_CONTACT_ID) : null;
    }

    get accountId() {
        return this.recordId;
    }

    @wire(getTaskTypePicklistValues)
    wiredPicklistValues({ error, data }) {
        if (data) {
            this.typeOptions = data;
        } else if (error) {
            // Show error toast for picklist load failure
            this.dispatchEvent(new ShowToastEvent({
                title: 'Varning',
                message: 'Kunde inte ladda ärendetyper. Funktionaliteten kan vara begränsad.',
                variant: 'warning'
            }));
        }
    }

    connectedCallback() {
        // Draft handling occurs when recordId is set via setter above.
        // Also purge any expired drafts across storage to avoid bloat.
        this.purgeExpiredDrafts();
    }

    // Build storage keys scoped to the current record (account or person contact)
    getStorageKey() {
        const idKey = this.accountId || this.personContactId;
        return idKey ? `${STORAGE_KEY_BASE}_${idKey}` : null;
    }

    getTypeStorageKey() {
        const idKey = this.accountId || this.personContactId;
        return idKey ? `${TYPE_STORAGE_KEY_BASE}_${idKey}` : null;
    }

    // ----- LocalStorage with TTL helpers -----
    isExpired(ts) {
        try {
            return typeof ts === 'number' && (Date.now() - ts) > TTL_MS;
        } catch(e) { return false; }
    }

    saveWithTTL(key, value) {
        try {
            if (!key) return;
            const payload = { v: value, ts: Date.now() };
            localStorage.setItem(key, JSON.stringify(payload));
        } catch(e) {}
    }

    loadTextWithTTL(key) {
        try {
            if (!key) return null;
            const raw = localStorage.getItem(key);
            if (!raw) return null;
            try {
                const obj = JSON.parse(raw);
                if (obj && typeof obj === 'object' && 'ts' in obj) {
                    if (this.isExpired(obj.ts)) { localStorage.removeItem(key); return null; }
                    return typeof obj.v === 'string' ? obj.v : (obj.v == null ? '' : String(obj.v));
                }
            } catch(parseErr) { /* legacy plain string */ }
            // Legacy format: plain string. Return it and migrate to TTL format.
            this.saveWithTTL(key, raw);
            return raw;
        } catch(e) { return null; }
    }

    loadArrayWithTTL(key) {
        try {
            if (!key) return [];
            const raw = localStorage.getItem(key);
            if (!raw) return [];
            try {
                const obj = JSON.parse(raw);
                // Envelope format with ts
                if (obj && typeof obj === 'object' && 'ts' in obj) {
                    if (this.isExpired(obj.ts)) { localStorage.removeItem(key); return []; }
                    return Array.isArray(obj.v) ? obj.v : [];
                }
                // Legacy format: raw is a JSON array string
                const legacy = JSON.parse(raw);
                if (Array.isArray(legacy)) {
                    // Migrate to envelope with current timestamp
                    this.saveWithTTL(key, legacy);
                    return legacy;
                }
            } catch(parseErr) { /* non-JSON or unexpected format */ }
            return [];
        } catch(e) { return []; }
    }

    purgeExpiredDrafts() {
        try {
            const toDelete = [];
            for (let i = 0; i < localStorage.length; i++) {
                const k = localStorage.key(i);
                if (!k) continue;
                const isDraftKey = k.startsWith(`${STORAGE_KEY_BASE}_`) || k.startsWith(`${TYPE_STORAGE_KEY_BASE}_`);
                if (!isDraftKey) continue;
                const raw = localStorage.getItem(k);
                if (!raw) { toDelete.push(k); continue; }
                try {
                    const obj = JSON.parse(raw);
                    if (obj && typeof obj === 'object' && 'ts' in obj) {
                        if (this.isExpired(obj.ts)) toDelete.push(k);
                    }
                    // If legacy (no ts), skip deletion to avoid accidental data loss; it will migrate on next read.
                } catch(parseErr) {
                    // Non-JSON legacy content; skip deletion.
                }
            }
            toDelete.forEach(k => { try { localStorage.removeItem(k); } catch(e){} });
        } catch(e) { /* ignore */ }
    }

    applyDraftForCurrentRecordOrClear(){
        // Load draft for new context; if none, clear so old data doesn't follow
        try {
            const commentsKey = this.getStorageKey();
            const typesKey = this.getTypeStorageKey();
            let found = false;
            let newComments = '';
            let newTypes = [];
            if (commentsKey) {
                const cachedComments = this.loadTextWithTTL(commentsKey);
                if (cachedComments) { newComments = cachedComments; found = true; }
            }
            if (typesKey) {
                const cachedTypes = this.loadArrayWithTTL(typesKey);
                if (cachedTypes && cachedTypes.length) { newTypes = cachedTypes; found = true; }
            }
            if (found) {
                this.comments = newComments;
                this.caseTypes = newTypes;
                this.mentionedUsers = this.parseMentions(newComments);
                this.saveStatus = 'draft';
            } else {
                this.comments = '';
                this.caseTypes = [];
                this.mentionedUsers = [];
                this.saveStatus = '';
            }
            this.hideSuggestions();
        } catch (e) {
            // On any error, clear to be safe
            this.comments = '';
            this.caseTypes = [];
            this.mentionedUsers = [];
            this.saveStatus = '';
            this.hideSuggestions();
        }
    }

    get isSpinnerStatus() {
        return this.saveStatus === 'saving';
    }

    get showStatus() {
        return this.saveStatus !== '';
    }

    get statusClass() {
        const baseClass = 'slds-text-body_small slds-grid slds-grid_align-center';
        switch (this.saveStatus) {
            case 'draft':
                return `${baseClass} slds-text-color_weak`;
            case 'saving':
                return `${baseClass} slds-text-color_weak`;
            case 'saved':
                return `${baseClass} slds-text-color_success`;
            case 'error':
                return `${baseClass} slds-text-color_error`;
            default:
                return baseClass;
        }
    }

    get statusIcon() {
        switch (this.saveStatus) {
            case 'draft':
                return 'utility:edit';
            case 'saving':
                return 'utility:spinner';
            case 'saved':
                return 'utility:success';
            case 'error':
                return 'utility:error';
            default:
                return '';
        }
    }

    get statusMessage() {
        switch (this.saveStatus) {
            case 'draft':
                return 'Utkast sparat lokalt';
            case 'saving':
                return 'Sparar...';
            case 'saved':
                return 'Sparat';
            case 'error':
                return 'Fel vid sparning';
            default:
                return '';
        }
    }

    get hasMentions() {
        return this.mentionedUsers && this.mentionedUsers.length > 0;
    }

    // Parse @mentions from text
    parseMentions(text) {
        if (!text || text.indexOf('@') === -1) return [];
        const mentions = [];
        // Allow 1–3 name parts but we'll normalize to max 2 words to avoid capturing trailing sentence words
        const re = /@([A-Za-zÀ-ÖØ-öø-ÿÄäÅåÖö\-]+(?:\s+[A-Za-zÀ-ÖØ-öø-ÿÄäÅåÖö\-]+){0,2})(?=\s|$)/g;
        let m;
        while ((m = re.exec(text)) !== null) {
            // Normalize: keep at most two words (First + Last) to avoid capturing following text
            const parts = m[1].trim().split(/\s+/).filter(Boolean);
            const name = parts.slice(0,2).join(' ');
            mentions.push(name);
        }
        return mentions;
    }

    handleInputChange(event) {
        this.comments = event.target.value;
    try { const k = this.getStorageKey(); if (k) this.saveWithTTL(k, this.comments); } catch(e){}

        // Mentions list for saving/notifications
        this.mentionedUsers = this.parseMentions(this.comments);

        // Autocomplete for current caret
        this.updateMentionSuggestions(event);
        // ...existing draft debounce...
        clearTimeout(this.debounceTimer);
        this.debounceTimer = setTimeout(() => this.autoSaveDraft(), DEBOUNCE_DELAY);
    }

    handleTypeMultiChange(event) {
        this.caseTypes = event.detail.value; // array
    try { const k = this.getTypeStorageKey(); if (k) this.saveWithTTL(k, this.caseTypes); } catch(e){}
        this.autoSaveDraft();
    }
    handleKeyNav(event) {
        if (!this.showSuggestions) return;
        if (event.key === 'ArrowDown') {
            event.preventDefault();
            this.highlightedIndex = (this.highlightedIndex + 1) % this.suggestions.length;
            this.updateSuggestionHighlight();
        } else if (event.key === 'ArrowUp') {
            event.preventDefault();
            this.highlightedIndex = (this.highlightedIndex - 1 + this.suggestions.length) % this.suggestions.length;
            this.updateSuggestionHighlight();
        } else if (event.key === 'Enter') {
            event.preventDefault();
            const s = this.suggestions[this.highlightedIndex];
            if (s) this.insertMention(s.name);
        } else if (event.key === 'Escape') {
            this.hideSuggestions();
        }
    }
     async updateMentionSuggestions(event) {
        const ta = event.target;
        const caret = ta.selectionStart;
        const before = this.comments.substring(0, caret);

        // Find the last '@' before caret that is not followed by a space
        const atIdx = before.lastIndexOf('@');
        if (atIdx === -1) {
            this.hideSuggestions();
            return;
        }
        const token = before.substring(atIdx + 1); // text after '@' to caret
        // Stop if token has whitespace (mention ended)
        if (/\s/.test(token)) {
            this.hideSuggestions();
            return;
        }
        // Require at least 1–2 chars to query
        if (token.length < 1) {
            this.showSuggestions = false;
            this.suggestions = [];
            this.mentionStart = atIdx;
            return;
        }

        this.mentionStart = atIdx;
        try {
            const results = await searchUsersForMention({ query: token, limitSize: 7 });
            // decorate suggestions with class and ensure reactive update
            this.suggestions = (results || []).map((r, i) => {
                // compute initials from name
                const parts = (r.name || '').trim().split(/\s+/).filter(Boolean);
                let initials = '';
                if (parts.length > 0) initials += parts[0].charAt(0).toUpperCase();
                if (parts.length > 1) initials += parts[1].charAt(0).toUpperCase();
                return { id: r.id, name: r.name, initials: initials, _class: 'slds-p-xx-small slds-truncate mention-item' };
            });
            this.showSuggestions = this.suggestions.length > 0;
            this.highlightedIndex = 0;
            this.updateSuggestionHighlight();
        } catch (e) {
            this.hideSuggestions();
        }
    }
    handleSuggestionClick(evt) {
        const idx = Number(evt.currentTarget.dataset.index);
        const s = this.suggestions[idx];
        if (s) {
            this.insertMention(s.name);
        }
    }
    insertMention(fullName) {
        if (this.mentionStart < 0) return;
        // Replace the mention token robustly: find token end (first whitespace after @ or end of text)
        const startIdx = this.mentionStart; // index of '@'
        const afterAt = this.comments.substring(startIdx + 1);
        let relativeEnd = afterAt.search(/\s/);
        let endIdx;
        if (relativeEnd === -1) endIdx = this.comments.length; else endIdx = startIdx + 1 + relativeEnd;
        const before = this.comments.substring(0, startIdx);
        const after = this.comments.substring(endIdx);
        const inserted = `@${fullName} `;
        this.comments = before + inserted + after;
    try { const k = this.getStorageKey(); if (k) this.saveWithTTL(k, this.comments); } catch(e){}

        // Update mentions and hide list
        this.mentionedUsers = this.parseMentions(this.comments);
        this.hideSuggestions();

        // Try to restore caret after inserted text (best-effort)
        // lightning-textarea doesn't expose setSelectionRange; re-render puts caret at end.
    }
    hideSuggestions() {
        this.showSuggestions = false;
        this.suggestions = [];
        this.highlightedIndex = 0;
        this.mentionStart = -1;
    }

    updateSuggestionHighlight(){
        if (!this.suggestions || this.suggestions.length===0) return;
        for (let i=0;i<this.suggestions.length;i++){
            this.suggestions[i]._class = 'slds-p-xx-small slds-truncate mention-item' + (i===this.highlightedIndex ? ' highlighted' : '');
        }
    }
    get suggestionItemClass() {
        return 'slds-p-xx-small slds-truncate mention-item';
    }

    autoSaveDraft() {
        if (this.comments.trim() || (this.caseTypes && this.caseTypes.length > 0)) {
            this.saveStatus = 'draft';
            // persist draft scoped to this record
            try{
                const ck = this.getStorageKey();
                const tk = this.getTypeStorageKey();
                if (ck) this.saveWithTTL(ck, this.comments);
                if (tk) this.saveWithTTL(tk, this.caseTypes || []);
            } catch(e){}
        } else {
            this.saveStatus = '';
        }
    }

     async saveLog() {
        clearTimeout(this.debounceTimer);
        if (!this.comments.trim()) return;

        this.saveStatus = 'saving';
        try {            
            const taskId = await createCallTaskWithMentions({ 
                comments: this.comments,
                // Join as semicolon string to fit a picklist/multi-picklist backend
                taskType: (this.caseTypes && this.caseTypes.length) ? this.caseTypes.join(';') : null,
                contactId: this.personContactId,
                accountId: this.accountId,
                mentionedUsers: this.mentionedUsers
            });

            // Notify LDS to refresh related UI (Activity Timeline) with proper signature
            const idsToRefresh = [{ recordId: this.accountId }];
            if (taskId) idsToRefresh.push({ recordId: taskId });
            if (this.personContactId) idsToRefresh.push({ recordId: this.personContactId });
            await getRecordNotifyChange(idsToRefresh);
            // Ask the page to refresh standard components (Activity Timeline, Related Lists, etc.)
            try { this.dispatchEvent(new RefreshEvent()); } catch(e) {}
            // Nudge again shortly after commit, then once more a bit later for safety
            setTimeout(() => { try { this.dispatchEvent(new RefreshEvent()); } catch(e) {} }, 300);
            setTimeout(() => { try { this.dispatchEvent(new RefreshEvent()); } catch(e) {} }, 900);
            // Explicitly refresh our Account LDS wire to invalidate cache and notify dependents
            try { if (this._wiredAccount) await refreshApex(this._wiredAccount); } catch(e) {}

            // Fallback for custom/non-standard pages: soft re-navigate to the same record to force refresh
            try {
                this[NavigationMixin.Navigate](
                    {
                        type: 'standard__recordPage',
                        attributes: {
                            recordId: this.accountId,
                            objectApiName: 'Account',
                            actionName: 'view'
                        }
                    },
                    true // replace history to avoid stacking
                );
            } catch(e) {}

            // If used as a Quick Action modal, close it
            try { this.dispatchEvent(new CloseActionScreenEvent()); } catch(e) {}

            try{
                const ck = this.getStorageKey();
                const tk = this.getTypeStorageKey();
                if (ck) localStorage.removeItem(ck);
                if (tk) localStorage.removeItem(tk);
            } catch(e){}
            // Notify container (Aura wrapper can listen and force refresh the view)
            try {
                this.dispatchEvent(new CustomEvent('logcallsaved', {
                    detail: { taskId: taskId, accountId: this.accountId, contactId: this.personContactId },
                    bubbles: true,
                    composed: true
                }));
            } catch(e) {}

            this.comments = '';
            this.caseTypes = [];
            this.mentionedUsers = [];
            this.saveStatus = 'saved';
            
            // Show success toast
            this.dispatchEvent(new ShowToastEvent({
                title: 'Sparat',
                message: 'Samtalet har loggats',
                variant: 'success'
            }));
            
            setTimeout(() => {
                this.saveStatus = '';
            }, 2000);
        } catch (error) {
            this.saveStatus = 'error';
            
            // Show user-friendly error toast
            this.dispatchEvent(new ShowToastEvent({
                title: 'Fel vid sparning',
                message: 'Kunde inte logga samtalet. Försök igen eller kontakta support om problemet kvarstår.',
                variant: 'error',
                mode: 'sticky'
            }));
        }
    }

    cancelLog() {
        clearTimeout(this.debounceTimer);
        this.comments = '';
        this.caseTypes = [];
        this.mentionedUsers = [];
        this.saveStatus = '';
    try{
        const ck = this.getStorageKey();
        const tk = this.getTypeStorageKey();
        if (ck) localStorage.removeItem(ck);
        if (tk) localStorage.removeItem(tk);
    } catch(e){}
        // Close Quick Action modal if opened from a Record Action
        try { this.dispatchEvent(new CloseActionScreenEvent()); } catch(e) {}
    }

    removeMention(event){
        const name = event.detail.name;
        // remove from mentions array
        this.mentionedUsers = (this.mentionedUsers || []).filter(u => u !== name);
        // also remove any exact @Name occurrences from comments (best-effort)
        try {
            const escaped = name.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
            const re = new RegExp('@' + escaped + '(?=\\s|$)', 'g');
            this.comments = (this.comments || '').replace(re, '').replace(/\s{2,}/g, ' ').trim();
            this.saveWithTTL(this.getStorageKey(), this.comments);
        } catch(e) {}
    }
}