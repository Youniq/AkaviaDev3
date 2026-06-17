/**
 * Tracks the lifecycle of one metadata deployment kicked off by the admin
 * LWCs. Subscribes to `/event/ContractReviewMetadataDeployResult__e` for
 * push notifications and falls back to polling
 * `ContractReviewMetadataService.checkDeployStatus` if the event does not
 * arrive within `DEFAULT_DEPLOY_TIMEOUT_MS` (30 s) after up to
 * `DEFAULT_MAX_RETRIES` (5) attempts.
 *
 * Callbacks: `onSuccess(jobId)`, `onFailure(jobId, errorMessage)`.
 */
const CHANNEL_NAME = "/event/ContractReviewMetadataDeployResult__e";
const DEFAULT_DEPLOY_TIMEOUT_MS = 30000;
const DEFAULT_MAX_RETRIES = 5;

export default class DeployTracker {
  /* ── Injected dependencies ── */
  _empApi;
  _checkDeployStatusFn;
  _callbacks;

  /* ── Config ── */
  _deployTimeoutMs;
  _maxRetries;

  /* ── Connection state ── */
  _subscribePromise = null;
  _subscription = null;

  /* ── Tracking state ── */
  _currentJobId = null;
  _entityType = null;
  _developerName = null;
  _timeoutId = null;
  _retryCount = 0;
  _authFailureCount = 0;

  constructor({ empApi, checkDeployStatusFn, callbacks, config } = {}) {
    this._empApi = empApi;
    this._checkDeployStatusFn = checkDeployStatusFn;
    this._callbacks = callbacks || {};

    const cfg = config || {};
    this._deployTimeoutMs = cfg.deployTimeoutMs ?? DEFAULT_DEPLOY_TIMEOUT_MS;
    this._maxRetries = cfg.maxRetries ?? DEFAULT_MAX_RETRIES;
  }

  /* ── Public getters ── */

  get isTracking() {
    return this._currentJobId !== null;
  }

  get pendingEntityType() {
    return this._entityType;
  }

  get pendingDeveloperName() {
    return this._developerName;
  }

  /* ── Connection lifecycle ── */

  connect() {
    if (this._subscribePromise) {
      return this._subscribePromise;
    }

    this._subscribePromise = this._empApi.subscribe(
      CHANNEL_NAME,
      -1,
      (event) => {
        this._handlePlatformEvent(event);
      }
    );
    this._subscribePromise.then((response) => {
      this._subscription = response;
    });

    this._empApi.onError(() => {
      this._log(
        "Streaming reconnect detected \u2014 empApi will recover automatically.",
        "warning"
      );
    });

    return this._subscribePromise;
  }

  ensureSubscribed() {
    return this._subscribePromise || Promise.resolve();
  }

  disconnect() {
    this._clearTimeout();

    if (this._subscription) {
      this._empApi.unsubscribe(this._subscription);
    } else if (this._subscribePromise) {
      this._subscribePromise.then((sub) => this._empApi.unsubscribe(sub));
    }

    this._subscription = null;
    this._subscribePromise = null;
  }

  /* ── Tracking ── */

  startTracking(jobId, entityType, developerName, summary = "") {
    if (this._currentJobId) {
      this._log(
        `New deploy requested while tracking Job ${this._currentJobId}. Cancelling previous tracking.`,
        "warning"
      );
      this._resolveFailure(
        "Cancelled",
        "Superseded by a new deployment request."
      );
    }

    this._currentJobId = jobId;
    this._entityType = entityType || "assignment";
    this._developerName = developerName;
    this._retryCount = 0;
    this._authFailureCount = 0;

    this._log(
      `Deployment initiated \u2014 Job: ${jobId}, Entity: ${this._entityType}, Name: ${developerName || "\u2014"}${summary}`
    );
    this._startTimeout();
  }

  /* ── Platform event handling ── */

  _handlePlatformEvent(event) {
    const payload = event.data.payload;
    const eventName = event.data.event?.replayId
      ? `ContractReviewMetadataDeployResult__e (replayId: ${event.data.event.replayId})`
      : "ContractReviewMetadataDeployResult__e";
    const entityLabel = this._entityType || "unknown";
    const devNameLabel = this._developerName || "\u2014";

    this._log(
      `Platform event \u00AB${eventName}\u00BB received \u2014 Job: ${payload.JobId__c}, Status: ${payload.Status__c}, Entity: ${entityLabel}, Name: ${devNameLabel}`
    );

    if (payload.JobId__c !== this._currentJobId) {
      this._log(
        `Event ignored \u2014 Job ID ${payload.JobId__c} does not match pending Job ID ${this._currentJobId}`,
        "warning"
      );
      return;
    }

    this._clearTimeout("event received");
    this._currentJobId = null;

    if (payload.Status__c === "Success") {
      this._resolveSuccess();
    } else {
      const errMsg = payload.ErrorMessage__c || "An unknown error occurred.";
      this._resolveFailure("Deployment Failed", errMsg);
    }
  }

  /* ── Timeout / polling ── */

  _startTimeout() {
    this._clearTimeout();
    // eslint-disable-next-line @lwc/lwc/no-async-operation
    this._timeoutId = setTimeout(() => {
      this._handleTimeout();
    }, this._deployTimeoutMs);
  }

  _clearTimeout(reason) {
    if (this._timeoutId) {
      if (reason) {
        this._log(`Deploy timeout cancelled \u2014 ${reason}.`);
      }
      clearTimeout(this._timeoutId);
      this._timeoutId = null;
    }
  }

  async _handleTimeout() {
    this._timeoutId = null;
    const jobId = this._currentJobId;
    if (!jobId) return;

    this._retryCount++;

    if (this._retryCount > this._maxRetries) {
      this._log(
        `Max status check retries (${this._maxRetries}) exceeded for Job ${jobId}. Giving up.`,
        "error"
      );
      this._currentJobId = null;
      if (this._authFailureCount >= this._retryCount - 1) {
        this._resolveSuccess({ verified: false });
      } else {
        this._resolveFailure(
          "Deployment Timeout",
          `No response received after ${this._maxRetries} status checks. The deployment may still be processing \u2014 check Setup > Deployment Status.`
        );
      }
      return;
    }

    this._log(
      `No platform event received within ${this._deployTimeoutMs / 1000}s. Checking deploy status for Job ${jobId} (attempt ${this._retryCount}/${this._maxRetries})...`,
      "warning"
    );

    try {
      const result = await this._checkDeployStatusFn(jobId);

      // Guard: platform event may have resolved this job while Apex call was in-flight
      if (this._currentJobId !== jobId) {
        this._log(
          `Status check for Job ${jobId} returned, but job was already resolved by platform event. Ignoring.`
        );
        return;
      }

      const status = result.status;

      if (status === "Succeeded") {
        this._log(
          `Status check: Job ${jobId} succeeded (event was missed). Processing success...`,
          "success"
        );
        this._currentJobId = null;
        this._resolveSuccess();
      } else if (status === "Failed" || status === "Canceled") {
        const errMsg = result.errorMessage || "An unknown error occurred.";
        this._log(
          `Status check: Job ${jobId} ${status.toLowerCase()} \u2014 ${errMsg}`,
          "error"
        );
        this._currentJobId = null;
        this._resolveFailure("Deployment " + status, errMsg);
      } else if (status === "NotFound") {
        const errMsg = result.errorMessage || "";
        const isAuthError =
          errMsg.includes("HTTP 401") || errMsg.includes("HTTP 403");
        if (isAuthError) {
          this._authFailureCount++;
          this._log(
            `Status check: Job ${jobId} not accessible (auth error). Will retry in ${this._deployTimeoutMs / 1000}s...`,
            "warning"
          );
        } else {
          this._log(
            `Status check: Job ${jobId} not found \u2014 ${errMsg}`,
            "error"
          );
        }
        this._startTimeout();
      } else {
        // Still in progress (Pending, InProgress, Canceling)
        this._log(
          `Status check: Job ${jobId} still ${status}. Will check again in ${this._deployTimeoutMs / 1000}s...`,
          "warning"
        );
        this._startTimeout();
      }
    } catch (err) {
      // Guard: platform event may have resolved while Apex errored
      if (this._currentJobId !== jobId) return;

      this._log(
        `Status check failed: ${err.body?.message || err.message || "Unknown error"}. Will retry in ${this._deployTimeoutMs / 1000}s...`,
        "error"
      );
      this._startTimeout();
    }
  }

  /* ── Resolution ── */

  _resolveSuccess({ verified = true } = {}) {
    const entityType = this._entityType;
    const developerName = this._developerName;
    this._log(
      verified
        ? `\u2713 Deployment succeeded for ${entityType || "unknown"} \u00AB${developerName || "\u2014"}\u00BB. Refreshing metadata...`
        : `Deployment submitted for ${entityType || "unknown"} \u00AB${developerName || "\u2014"}\u00BB. Status could not be verified \u2014 refreshing metadata...`,
      verified ? "success" : "warning"
    );
    this._resetTrackingState();
    this._callbacks.onSuccess?.({ entityType, developerName, verified });
  }

  _resolveFailure(title, message) {
    const entityType = this._entityType;
    const developerName = this._developerName;
    this._log(
      `\u2717 ${title} for ${entityType || "unknown"} \u00AB${developerName || "\u2014"}\u00BB: ${message}`,
      "error"
    );
    this._resetTrackingState();
    this._callbacks.onFailure?.({ title, message, entityType, developerName });
  }

  _resetTrackingState() {
    this._entityType = null;
    this._developerName = null;
    // _currentJobId is cleared by the caller before calling resolve
  }

  /* ── Logging ── */

  _log(message, level = "info") {
    this._callbacks.onLog?.(message, level);
  }
}