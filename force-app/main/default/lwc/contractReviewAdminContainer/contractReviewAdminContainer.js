/**
 * Top-level admin page (Avtalsgranskaren Admin) that hosts the template /
 * criteria / assignment management UI. Owns the global console output area
 * and the metadata-deploy lifecycle:
 *
 *   1. Workspace components call `c/contractReviewDeployService.deploy()`.
 *   2. `c/contractReviewDeployTracker` subscribes to
 *      `ContractReviewMetadataDeployResult__e` and falls back to polling
 *      `ContractReviewMetadataService.checkDeployStatus`.
 *   3. The container surfaces success / failure as toasts and refreshes
 *      the relevant tab.
 */
import { LightningElement, track } from "lwc";
import LightningConfirm from "lightning/confirm";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import { subscribe, unsubscribe, onError } from "lightning/empApi";
import getTemplates from "@salesforce/apex/ContractReviewMetadataSelector.getTemplates";
import checkDeployStatus from "@salesforce/apex/ContractReviewMetadataService.checkDeployStatus";
import ContractReviewAdminTemplateModal from "c/contractReviewAdminTemplateModal";
import DeployTracker from "c/contractReviewDeployTracker";

const PROPAGATION_DELAY_MS = 1000;

export default class ContractReviewAdminContainer extends LightningElement {
  templates;
  error;
  selectedTemplate;
  activeTab = "templates";
  isDeploying = false;

  _tracker;

  /* ── Console log state ── */
  @track logEntries = [];
  _logIdCounter = 0;

  get hasLogEntries() {
    return this.logEntries.length > 0;
  }

  log(message, level = "info") {
    const now = new Date();
    const ts = now.toLocaleTimeString("sv-SE", {
      hour: "2-digit",
      minute: "2-digit",
      second: "2-digit"
    });
    this._logIdCounter += 1;
    this.logEntries = [
      ...this.logEntries,
      {
        id: this._logIdCounter,
        timestamp: ts,
        message,
        level,
        cssClass: `log-entry log-${level}`
      }
    ];
    // eslint-disable-next-line @lwc/lwc/no-async-operation
    requestAnimationFrame(() => {
      const body = this.template.querySelector(".console-body");
      if (body) {
        body.scrollTop = body.scrollHeight;
      }
    });
  }

  handleClearLog() {
    this.logEntries = [];
    this._logIdCounter = 0;
  }

  /* ── Tab switching ── */
  get templatesBtnClass() {
    return (
      "tab-btn" + (this.activeTab === "templates" ? " tab-btn-active" : "")
    );
  }

  get criteriaBtnClass() {
    return "tab-btn" + (this.activeTab === "criteria" ? " tab-btn-active" : "");
  }

  get templatesTabClass() {
    return this.activeTab === "templates"
      ? "tab-panel"
      : "tab-panel tab-panel-hidden";
  }

  get criteriaTabClass() {
    return this.activeTab === "criteria"
      ? "tab-panel criteria-panel-body"
      : "tab-panel criteria-panel-body tab-panel-hidden";
  }

  async handleTabSwitch(event) {
    const tab = event.currentTarget.dataset.tab;
    if (tab === this.activeTab) return;

    // Check for unsaved changes in template detail
    if (this.activeTab === "templates") {
      const workspace = this.template.querySelector(
        "c-contract-review-admin-template-workspace"
      );
      if (workspace) {
        const detail = workspace.getDetailComponent();
        if (detail && detail.hasUnsavedChanges) {
          const shouldDiscard = await LightningConfirm.open({
            message:
              "You have unsaved template changes. Discard and switch tabs?",
            variant: "headerless",
            label: "Discard Unsaved Changes"
          });
          if (!shouldDiscard) {
            return;
          }
        }
      }
    }
    this.activeTab = tab;
  }

  /* ── Imperative data loading ── */
  async _loadTemplates() {
    try {
      const data = await getTemplates();
      this.templates = data;
      this.error = undefined;
    } catch (err) {
      console.error(
        "[Container] Load templates error:",
        err?.body?.message || err?.message || JSON.stringify(err)
      );
      this.error = err;
      this.templates = undefined;
    }
  }

  /* ── Lifecycle ── */
  connectedCallback() {
    this._tracker = new DeployTracker({
      empApi: { subscribe, unsubscribe, onError },
      checkDeployStatusFn: (jobId) => checkDeployStatus({ jobId }),
      callbacks: {
        onLog: (msg, level) => this.log(msg, level),
        onSuccess: (detail) => this._handleDeploySuccess(detail),
        onFailure: (detail) => this._handleDeployFailure(detail)
      }
    });
    this._tracker.connect();
    this.log("Console initialized. Listening for deploy events.");
    this._loadTemplates();
  }

  disconnectedCallback() {
    this._tracker.disconnect();
  }

  /* ── Deploy result handlers ── */

  _handleDeploySuccess({ entityType, developerName, verified }) {
    if (verified === false) {
      this.dispatchEvent(
        new ShowToastEvent({
          title: "Distribution skickad",
          message: `${entityType} «${developerName}» distribution skickad — uppdaterar data. Kontrollera Konfiguration > Distributionsstatus om ändringarna inte syns.`,
          variant: "info"
        })
      );
    } else {
      this.dispatchEvent(
        new ShowToastEvent({
          title: "Klart",
          message: `${entityType} «${developerName}» har distribuerats.`,
          variant: "success"
        })
      );
    }
    this._refreshAfterDeploy(entityType, developerName);
  }

  _handleDeployFailure({ title, message, entityType, developerName }) {
    console.error(
      "[Container] Deploy failed for",
      entityType,
      developerName,
      ":",
      message
    );
    this.isDeploying = false;
    this.dispatchEvent(
      new ShowToastEvent({
        title,
        message,
        variant: "error",
        mode: "sticky"
      })
    );

    // Roll back optimistic criterion update on real deploy failure.
    // Skip "Cancelled" pseudo-failures from tracker supersession — the
    // original deploy may still succeed, so the optimistic update should stay.
    if (entityType === "criterion" && title !== "Cancelled") {
      const workspace = this.template.querySelector(
        "c-contract-review-admin-template-workspace"
      );
      if (workspace) {
        workspace.refreshCriteriaOnly();
      }
    }
  }

  _refreshAfterDeploy(entityType, developerName) {
    // Brief delay for custom metadata cache propagation after Metadata API deploy
    this.log("Waiting for metadata propagation (1s)...", "info");
    // eslint-disable-next-line @lwc/lwc/no-async-operation
    setTimeout(async () => {
      try {
        await this._loadTemplates();

        // Re-select current template from fresh data
        if (developerName && this.templates) {
          const found = this.templates.find(
            (t) => t.DeveloperName === developerName
          );
          if (found) {
            this.selectedTemplate = found;
          }
        } else if (this.selectedTemplate) {
          const found = this.templates?.find(
            (t) => t.DeveloperName === this.selectedTemplate.DeveloperName
          );
          this.selectedTemplate = found || null;
        }

        // Explicitly reset edit mode in template detail
        // Note: workspace is always in the DOM (tabs use CSS hiding, not lwc:if).
        // If tabs are refactored to lwc:if, this querySelector may return null.
        const workspace = this.template.querySelector(
          "c-contract-review-admin-template-workspace"
        );
        if (workspace) {
          if (entityType === "template") {
            workspace.resetDetailEditMode();
          }
          if (entityType === "assignment") {
            workspace.refreshAssignments();
          } else {
            workspace.refreshCriteriaOnly();
          }
        }

        // Refresh criteria manager
        const critMgr = this.template.querySelector(
          "c-contract-review-admin-criteria-manager"
        );
        if (critMgr) {
          critMgr.refresh();
        }

        this.log(
          `Metadata refresh complete for ${entityType || "all"}.`,
          "success"
        );
      } finally {
        if (!this._tracker.isTracking) {
          this.isDeploying = false;
        }
      }
    }, PROPAGATION_DELAY_MS);
  }

  async handleTemplateSelected(event) {
    // Check for unsaved changes before switching template
    const workspace = this.template.querySelector(
      "c-contract-review-admin-template-workspace"
    );
    if (workspace) {
      const detail = workspace.getDetailComponent();
      if (detail && detail.hasUnsavedChanges) {
        const shouldDiscard = await LightningConfirm.open({
          message: "You have unsaved template changes. Discard and switch?",
          variant: "headerless",
          label: "Discard Unsaved Changes"
        });
        if (!shouldDiscard) {
          return;
        }
      }
    }
    this.selectedTemplate = event.detail;
  }

  async handleTemplateCreate() {
    const result = await ContractReviewAdminTemplateModal.open({
      size: "small",
      templates: this.templates
    });
    if (result && result.error) {
      this.dispatchEvent(
        new ShowToastEvent({
          title: "Distributionsfel",
          message: result.error,
          variant: "error",
          mode: "sticky"
        })
      );
    } else if (result && result.jobId) {
      this.handleDeployInitiated({
        detail: {
          jobId: result.jobId,
          entityType: "template",
          developerName: result.developerName
        }
      });
    }
  }

  async handleDeployInitiated(event) {
    const {
      jobId,
      entityType,
      developerName,
      addedCount,
      removedCount,
      totalRecords
    } = event.detail;
    this.isDeploying = true;
    await this._tracker.ensureSubscribed();
    const parts = [];
    if (addedCount) parts.push(`${addedCount} added`);
    if (removedCount) parts.push(`${removedCount} deactivated`);
    const summary =
      parts.length > 0
        ? ` | ${parts.join(", ")} (${totalRecords} records total)`
        : "";
    this._tracker.startTracking(jobId, entityType, developerName, summary);
  }
}