/**
 * Generates a Salesforce-safe DeveloperName from a human-readable label.
 * Strips non-alphanumeric characters (except underscores), collapses
 * whitespace into underscores, and truncates to maxLength characters.
 *
 * @param {string} label - The human-readable label to convert
 * @param {number} [maxLength=40] - Maximum length of the returned name
 * @returns {string} A sanitised DeveloperName
 */
/**
 * Cross-cutting helpers used by multiple contract-review LWCs.
 *
 * Exports:
 *   - `generateDeveloperName(label, maxLength)` — deterministic sanitiser
 *     mapping a free-form label to a Salesforce-safe DeveloperName.
 *   - Field/label constants for runtime criterion fields shared by the
 *     viewer table and the criterion modal.
 *   - `CancellableTimer` — a small setTimeout/setInterval wrapper that
 *     guarantees cleanup on `cancel()` to avoid post-disconnect callbacks.
 */
export function generateDeveloperName(label, maxLength = 40) {
  return label
    .replace(/[^a-zA-Z0-9_\s]/g, "")
    .replace(/\s+/g, "_")
    .replace(/_+/g, "_")
    .replace(/^_|_$/g, "")
    .substring(0, maxLength);
}

// ─── Criterion field constants ───

export const FIELD_EXTRACT = 'Extract__c';
export const FIELD_AI_COMMENT = 'ai_comment__c';
export const FIELD_DEFINITION = 'Definition__c';
export const LABEL_EXTRACT = 'Utdrag ur Avtalstext';
export const LABEL_AI_COMMENT = 'AI Motivering';
export const LABEL_DEFINITION = 'Granskningskriterium';

// ─── Timer utility ───

/**
 * A cancellable one-shot timer wrapping setTimeout/clearTimeout.
 * Callbacks MUST be arrow functions to preserve the caller's `this` binding.
 */
export class CancellableTimer {
  _handle = null;
  _callback;
  _durationMs;

  constructor(callback, durationMs) {
    this._callback = callback;
    this._durationMs = durationMs;
  }

  start() {
    this.cancel();
    // eslint-disable-next-line @lwc/lwc/no-async-operation
    this._handle = setTimeout(() => {
      this._handle = null;
      this._callback();
    }, this._durationMs);
  }

  cancel() {
    if (this._handle !== null) {
      clearTimeout(this._handle);
      this._handle = null;
    }
  }

  get isActive() {
    return this._handle !== null;
  }
}