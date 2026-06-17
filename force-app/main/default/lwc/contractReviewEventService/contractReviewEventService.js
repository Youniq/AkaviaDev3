/**
 * Stateless helper module that owns all Platform Event subscriptions used by
 * `contractReviewViewer`. Centralises empApi subscribe/unsubscribe so the
 * viewer stays focused on UI state.
 *
 * Channels:
 *   - /event/ContractReviewStarted__e
 *   - /event/ContractReviewCompleted__e
 *   - /event/ContractReviewDraftCompleted__e
 *
 * Filters every inbound event by Case Id (`recordId`) and, where relevant,
 * by the currently selected review Id so background activity on other
 * reviews does not trigger UI churn.
 */
import {
  subscribe,
  unsubscribe,
  onError,
} from "lightning/empApi";

const CHANNEL_STARTED = "/event/ContractReviewStarted__e";
const CHANNEL_COMPLETED = "/event/ContractReviewCompleted__e";
const CHANNEL_DRAFT_COMPLETED = "/event/ContractReviewDraftCompleted__e";

let _errorHandlerRegistered = false;

/**
 * Creates platform-event subscriptions for the ContractReview channels.
 * Returns an object with a `destroy()` method that unsubscribes all channels.
 *
 * IMPORTANT: All handler callbacks (`onStarted`, `onCompleted`, `onDraftCompleted`)
 * MUST be arrow functions to preserve the caller's `this` binding. Do NOT pass
 * unbound method references (e.g. `this.handleCompleted` without `.bind(this)`).
 *
 * @param {Object} config
 * @param {string} config.recordId - The Case record Id to filter started/completed events.
 * @param {Function} config.getSelectedReviewId - Getter returning the current selectedReviewId
 *   at call time (avoids stale closures).
 * @param {Object} config.handlers
 * @param {Function} config.handlers.onStarted - Called with the event payload when a review starts.
 * @param {Function} config.handlers.onCompleted - Called with the event payload when a review completes.
 * @param {Function} config.handlers.onDraftCompleted - Called with the event payload when a draft completes.
 * @returns {{ destroy: Function }}
 */
export function createEventSubscriptions({ recordId, getSelectedReviewId, handlers }) {
  const { onStarted, onCompleted, onDraftCompleted } = handlers;

  let _destroyed = false;
  let _startedSub = null;
  let _completedSub = null;
  let _draftCompletedSub = null;

  // Register global error handler once per module lifecycle
  if (!_errorHandlerRegistered) {
    _errorHandlerRegistered = true;
    onError((error) => {
      console.error("[contractReviewEventService] empApi error:", error);
    });
  }

  subscribe(CHANNEL_STARTED, -1, (event) => {
    if (_destroyed) return;
    const payload = event.data.payload;
    if (payload.CaseId__c === recordId) {
      onStarted(payload);
    }
  }).then((sub) => {
    if (_destroyed) {
      unsubscribe(sub);
    } else {
      _startedSub = sub;
    }
  });

  subscribe(CHANNEL_COMPLETED, -1, (event) => {
    if (_destroyed) return;
    const payload = event.data.payload;
    if (payload.CaseId__c === recordId) {
      onCompleted(payload);
    }
  }).then((sub) => {
    if (_destroyed) {
      unsubscribe(sub);
    } else {
      _completedSub = sub;
    }
  });

  subscribe(CHANNEL_DRAFT_COMPLETED, -1, (event) => {
    if (_destroyed) return;
    const payload = event.data.payload;
    if (payload.ReviewId__c === getSelectedReviewId()) {
      onDraftCompleted(payload);
    }
  }).then((sub) => {
    if (_destroyed) {
      unsubscribe(sub);
    } else {
      _draftCompletedSub = sub;
    }
  });

  return {
    destroy() {
      if (_destroyed) return;
      _destroyed = true;
      if (_startedSub) {
        unsubscribe(_startedSub);
        _startedSub = null;
      }
      if (_completedSub) {
        unsubscribe(_completedSub);
        _completedSub = null;
      }
      if (_draftCompletedSub) {
        unsubscribe(_draftCompletedSub);
        _draftCompletedSub = null;
      }
    }
  };
}