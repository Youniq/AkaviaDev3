/**
 * Main user-facing viewer for the GenAI Contract Review feature.
 *
 * Exposed on the `Case` record page (target `lightning__RecordPage`). Drives
 * the three-tab UI (Resultat / Svarstext / Granskat Avtal) and the new-review
 * Flow modal.
 *
 * Reactivity model:
 *   - `@wire(getContractReviews)`: list of reviews for the Case.
 *   - `@wire(getReviewDetails)`: criteria + draft + PDF for the selected review.
 *   - Platform events via `c/contractReviewEventService`:
 *       * ContractReviewStarted__e   — switches to processing state.
 *       * ContractReviewCompleted__e — triggers refreshApex on details.
 *       * ContractReviewDraftCompleted__e — refreshes the Svarstext tab.
 *   - Polling fallback (15 s) while a review is in `Processing`.
 *   - 10-minute stale threshold reveals a manual `Cancel` button that calls
 *     `ContractReviewController.cancelStuckReview`.
 *
 * Apex calls: getContractReviews, getReviewDetails, cancelStuckReview,
 * generateDraft.
 */
import { LightningElement, api, wire } from "lwc";
import { NavigationMixin } from "lightning/navigation";
import { refreshApex } from "@salesforce/apex";
import {
  IsConsoleNavigation,
  EnclosingTabId,
  getTabInfo,
  openSubtab
} from "lightning/platformWorkspaceApi";
import getContractReviews from "@salesforce/apex/ContractReviewController.getContractReviews";
import getReviewDetails from "@salesforce/apex/ContractReviewController.getReviewDetails";
import cancelStuckReview from "@salesforce/apex/ContractReviewController.cancelStuckReview";
import generateDraft from "@salesforce/apex/ContractReviewController.generateDraft";
import { CancellableTimer } from "c/contractReviewUtils";
import { createEventSubscriptions } from "c/contractReviewEventService";

const STALE_THRESHOLD_MS = 10 * 60 * 1000; // 10 minutes
const POLL_INTERVAL_MS = 15 * 1000; // 15 seconds
const DRAFT_TIMEOUT_MS = 2 * 60 * 1000; // 2 minutes
const DATE_FORMATTER = new Intl.DateTimeFormat('sv-SE', { dateStyle: 'short', timeStyle: 'short' });

export default class ContractReviewViewer extends NavigationMixin(LightningElement) {
  @api recordId;
  @wire(IsConsoleNavigation) isConsoleNavigation;
  @wire(EnclosingTabId) enclosingTabId;

  selectedReviewId;
  wiredReviewsResult;
  wiredDetailsResult;
  _detailsStale = false;
  _pendingDetailsRefresh = false;
  _processingReviewId = null;
  _pollingTimer = null;
  _eventSub = null;

  // ─── Inline flow state ───
  _showNewReviewFlow = false;
  _flowError = false;

  // ─── Draft state ───
  _svDraftPending = false;
  _engDraftPending = false;
  _engDraftError = null;

  // ─── Timers ───
  _staleResetTimer = new CancellableTimer(() => {
    if (this._detailsStale) {
      this._detailsStale = false;
    }
  }, 30 * 1000);

  _svDraftTimer = new CancellableTimer(() => {
    this._svDraftPending = false;
  }, DRAFT_TIMEOUT_MS);

  _engDraftTimer = new CancellableTimer(() => {
    this._engDraftPending = false;
    this._engDraftError = 'Generering av svarsutkast tog för lång tid. Ladda om sidan.';
  }, DRAFT_TIMEOUT_MS);

  // ─── Lifecycle ───

  connectedCallback() {
    this._eventSub = createEventSubscriptions({
      recordId: this.recordId,
      getSelectedReviewId: () => this.selectedReviewId,
      handlers: {
        onStarted: (payload) => {
          this.selectedReviewId = payload.ReviewId__c;
          this._detailsStale = true;
          this._showNewReviewFlow = false;
          this._flowError = false;
          this.handleRefresh();
        },
        onCompleted: () => {
          this._detailsStale = true;
          this._staleResetTimer.start();
          this.handleRefresh();
        },
        onDraftCompleted: (payload) => {
          const lang = payload.Language__c;
          const success = payload.Status__c === 'Success';

          if (lang === 'Svenska') {
            this._svDraftPending = false;
            this._svDraftTimer.cancel();
          } else if (lang === 'English') {
            this._engDraftPending = false;
            this._engDraftTimer.cancel();
            if (!success) {
              this._engDraftError = payload.ErrorMessage__c || 'Generering av engelskt svarsutkast misslyckades.';
            }
          }

          if (success) {
            refreshApex(this.wiredDetailsResult).catch((err) => {
              console.error("[ContractReviewViewer] Draft refresh failed:", err);
            });
          }
        }
      }
    });
  }

  disconnectedCallback() {
    this._stopPolling();
    this._staleResetTimer.cancel();
    this._svDraftTimer.cancel();
    this._engDraftTimer.cancel();
    this._eventSub?.destroy();
  }

  // ─── Wire: Contract Reviews list ───

  @wire(getContractReviews, { caseId: "$recordId" })
  wiredReviews(result) {
    this.wiredReviewsResult = result;
    const { data, error } = result;
    if (data) {
      const processingReview = data.find(
        (r) => r.Status__c === "Processing"
      );

      if (processingReview) {
        this._processingReviewId = processingReview.Id;
        this._startPolling();
      } else {
        // If a previously tracked processing review is no longer processing, auto-switch
        if (this._processingReviewId) {
          if (this._processingReviewId !== this.selectedReviewId) {
            this.selectedReviewId = this._processingReviewId;
            this._detailsStale = true;
            this._pendingDetailsRefresh = true;
          }
          this._processingReviewId = null;
        }
        this._stopPolling();
      }

      if (!this.selectedReviewId && data.length) {
        this.selectedReviewId = data[0].Id;
      }
    }
    if (error) {
      console.error("[ContractReviewViewer] Reviews wire error:", error);
    }
  }

  // ─── Wire: Review details (criteria + PDF) ───

  @wire(getReviewDetails, { reviewId: "$selectedReviewId" })
  wiredDetails(result) {
    this.wiredDetailsResult = result;

    // Auto-switch to a just-completed review serves a stale cached payload
    // first (criteria at defaults). Force a server round-trip and keep the
    // spinner up until the refreshed emission lands.
    if (this._pendingDetailsRefresh && result.data) {
      this._pendingDetailsRefresh = false;
      refreshApex(result).catch((err) => {
        console.error("[ContractReviewViewer] Forced details refresh failed:", err);
        this._detailsStale = false;
        this._staleResetTimer.cancel();
      });
      return;
    }
    if (result.data || result.error) {
      this._detailsStale = false;
      this._staleResetTimer.cancel();
    }
    if (result.data) {
      // Infer Swedish draft pending: review succeeded but no draft yet
      if (
        this.selectedStatus === 'Success' &&
        !result.data.responseDraft &&
        !this._svDraftPending
      ) {
        // Only set pending if we haven't already received a draft-completed event
        // and the review was recently completed (within draft timeout window)
        const review = this._selectedReview;
        if (review?.LastModifiedDate) {
          const elapsed = Date.now() - new Date(review.LastModifiedDate).getTime();
          if (elapsed < DRAFT_TIMEOUT_MS) {
            this._svDraftPending = true;
            this._svDraftTimer.start();
          }
        }
      } else if (result.data.responseDraft) {
        this._svDraftPending = false;
        this._svDraftTimer.cancel();
      }
    }
    if (result.error) {
      console.error("[ContractReviewViewer] Details wire error:", result.error);
    }
  }

  // ─── Selected review helper ───

  get _selectedReview() {
    const data = this.wiredReviewsResult?.data;
    if (!data || !this.selectedReviewId) return null;
    return data.find((r) => r.Id === this.selectedReviewId) || null;
  }

  // ─── Status getters ───

  get selectedStatus() {
    return this._selectedReview?.Status__c || null;
  }

  get isProcessing() {
    return this.selectedStatus === "Processing";
  }

  get isFailure() {
    return this.selectedStatus === "Failure";
  }

  get isStale() {
    if (!this.isProcessing) return false;
    const review = this._selectedReview;
    if (!review?.LastModifiedDate) return false;
    const elapsed = Date.now() - new Date(review.LastModifiedDate).getTime();
    return elapsed > STALE_THRESHOLD_MS;
  }

  get errorMessage() {
    return this._selectedReview?.ErrorMessage__c || null;
  }

  get showResults() {
    return !this.isProcessing && !this.isFailure && !this._detailsStale;
  }

  get isRefreshing() {
    return !this.isProcessing && !this.isFailure && this._detailsStale;
  }

  // ─── Background processing getters ───

  get anyProcessingReview() {
    const data = this.wiredReviewsResult?.data;
    if (!data) return null;
    return data.find((r) => r.Status__c === "Processing") || null;
  }

  get hasBackgroundProcessing() {
    const proc = this.anyProcessingReview;
    return proc != null && proc.Id !== this.selectedReviewId;
  }

  get processingReviewName() {
    return this.anyProcessingReview?.Name || "";
  }

  // ─── Derived getters ───

  get reviewOptions() {
    const data = this.wiredReviewsResult?.data;
    if (!data) {
      return [];
    }
    return data.map((r) => {
      const tooltip = r.CreatedDate
        ? DATE_FORMATTER.format(new Date(r.CreatedDate))
        : '';
      return {
        label: r.Name,
        value: r.Id,
        tooltip
      };
    });
  }

  get createdDateFormatted() {
    const val = this._selectedReview?.CreatedDate;
    if (!val) return '\u2014';
    return DATE_FORMATTER.format(new Date(val));
  }

  get criteria() {
    return this.wiredDetailsResult?.data?.criteria || [];
  }

  get contentVersionId() {
    return this.wiredDetailsResult?.data?.contentVersionId || null;
  }

  get responseDraft() {
    return this.wiredDetailsResult?.data?.responseDraft || null;
  }

  get responseDraftEng() {
    return this.wiredDetailsResult?.data?.responseDraftEng || null;
  }

  get isSvDraftPending() {
    return this._svDraftPending;
  }

  get isEngDraftPending() {
    return this._engDraftPending;
  }

  get engDraftError() {
    return this._engDraftError;
  }

  get templateName() {
    if (this._detailsStale) return '\u2014';
    return this.wiredDetailsResult?.data?.templateName || '\u2014';
  }

  get fileName() {
    if (this._detailsStale) return '\u2014';
    return this.wiredDetailsResult?.data?.fileName || '\u2014';
  }

  get reviewRecordUrl() {
    return this.selectedReviewId
      ? `/lightning/r/ContractReview__c/${this.selectedReviewId}/view`
      : null;
  }

  async handleOpenRecord() {
    if (!this.selectedReviewId) {
      return;
    }
    if (this.isConsoleNavigation && this.enclosingTabId) {
      try {
        const tabInfo = await getTabInfo(this.enclosingTabId);
        const primaryTabId = tabInfo.isSubtab ? tabInfo.parentTabId : tabInfo.tabId;
        await openSubtab(primaryTabId, { recordId: this.selectedReviewId, focus: true });
        return;
      } catch (e) {
        // Fall through to fallback navigation
      }
    }
    window.open(this.reviewRecordUrl, '_blank');
  }

  get fileExtension() {
    return this.wiredDetailsResult?.data?.fileExtension || null;
  }

  get isImage() {
    const ext = this.fileExtension;
    return ext != null && ['jpg', 'jpeg', 'png'].includes(ext.toLowerCase());
  }

  get isPdf() {
    return !this.isImage && this.contentVersionId != null;
  }

  get imageUrl() {
    return this.contentVersionId
      ? "/sfc/servlet.shepherd/version/download/" + this.contentVersionId
      : null;
  }

  get pdfUrl() {
    return this.contentVersionId
      ? "/sfc/servlet.shepherd/version/renditionDownload?rendition=ORIGINAL_Pdf&versionId=" +
          this.contentVersionId +
          "&operationContext=CHATTER"
      : null;
  }

  handleImageClick() {
    if (this.wiredDetailsResult?.data?.contentDocumentId) {
      this[NavigationMixin.Navigate]({
        type: 'standard__namedPage',
        attributes: {
          pageName: 'filePreview'
        },
        state: {
          selectedRecordId: this.wiredDetailsResult.data.contentDocumentId
        }
      });
    }
  }

  handleImageKeydown(event) {
    if (event.key === 'Enter' || event.key === ' ') {
      event.preventDefault();
      this.handleImageClick();
    }
  }

  get hasReviews() {
    const data = this.wiredReviewsResult?.data;
    return Array.isArray(data) && data.length > 0;
  }

  get isLoading() {
    return (
      this.wiredReviewsResult?.data === undefined &&
      this.wiredReviewsResult?.error === undefined
    );
  }

  get error() {
    return this.wiredReviewsResult?.error || this.wiredDetailsResult?.error;
  }

  // ─── Event handlers ───

  handleReviewChange(event) {
    this.selectedReviewId = event.detail.value;
    this._detailsStale = true;
    this._resetDraftState();
  }

  // ─── Inline flow ───

  get showNewReviewFlow() {
    return this._showNewReviewFlow;
  }

  get flowInputVariables() {
    return [{ name: 'recordId', type: 'String', value: this.recordId }];
  }

  handleNewReview() {
    this._showNewReviewFlow = true;
    this._flowError = false;
  }

  handleCancelFlow() {
    this._showNewReviewFlow = false;
    this._flowError = false;
  }

  handleFlowStatusChange(event) {
    const { status } = event.detail;
    if (status === "FINISHED" || status === "FINISHED_SCREEN") {
      this._showNewReviewFlow = false;
      this._flowError = false;
      this.handleRefresh();
    } else if (status === "ERROR") {
      this._flowError = true;
    }
  }

  get flowError() {
    return this._flowError;
  }

  // ─── Draft generation ───

  handleGenerateEngDraft() {
    if (this._engDraftPending) return;
    this._engDraftPending = true;
    this._engDraftError = null;
    this._engDraftTimer.start();
    generateDraft({ reviewId: this.selectedReviewId, language: 'English' })
      .catch((error) => {
        this._engDraftPending = false;
        this._engDraftTimer.cancel();
        this._engDraftError = error?.body?.message || 'Generering av engelskt svarsutkast misslyckades.';
        console.error("[ContractReviewViewer] Generate English draft failed:", error);
      });
  }

  handleRefresh() {
    Promise.all([
      refreshApex(this.wiredReviewsResult),
      refreshApex(this.wiredDetailsResult)
    ]).catch((err) => {
      this._detailsStale = false;
      console.error("[ContractReviewViewer] Refresh failed:", err);
    });
  }

  handleCancelStuckReview() {
    cancelStuckReview({ reviewId: this.selectedReviewId })
      .then(() => {
        this.handleRefresh();
      })
      .catch((error) => {
        console.error(
          "[ContractReviewViewer] Cancel stuck review failed:",
          error
        );
      });
  }

  // ─── Polling ───

  _startPolling() {
    if (this._pollingTimer) return;
    // eslint-disable-next-line @lwc/lwc/no-async-operation
    this._pollingTimer = setInterval(() => this.handleRefresh(), POLL_INTERVAL_MS);
  }

  _stopPolling() {
    if (this._pollingTimer) {
      clearInterval(this._pollingTimer);
      this._pollingTimer = null;
    }
  }

  // ─── Draft state reset ───

  _resetDraftState() {
    this._svDraftPending = false;
    this._engDraftPending = false;
    this._engDraftError = null;
    this._svDraftTimer.cancel();
    this._engDraftTimer.cancel();
  }
}