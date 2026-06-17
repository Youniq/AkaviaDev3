/**
 * Manages the `ContractReviewTemplateAssignment__mdt` rows for a selected
 * template. Loads available criteria + current assignments via
 * `ContractReviewMetadataSelector`, drives the dual-list picker, and emits
 * a `deploy` custom event with the bundle built by
 * `c/contractReviewDeployService.buildAssignmentPayload`.
 */
import { LightningElement, api, track } from "lwc";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import getCriteria from "@salesforce/apex/ContractReviewMetadataSelector.getCriteria";
import getTemplateAssignments from "@salesforce/apex/ContractReviewMetadataSelector.getTemplateAssignments";
import {
  deploy,
  buildCriterionRecord,
  buildAssignmentPayload,
  extractDeployError
} from "c/contractReviewDeployService";

export default class ContractReviewAdminAssignmentManager extends LightningElement {
  _templateDevName;

  @api
  get templateDevName() {
    return this._templateDevName;
  }
  set templateDevName(value) {
    const changed = this._templateDevName !== value;
    this._templateDevName = value;
    if (changed && this._connected) {
      this.selectedCriterion = undefined;
      this.selectedItemValue = undefined;
      this._loadData();
    }
  }

  error;
  isSaving = false;
  _isLoadingAssignments = false;
  _isLoadingCriteria = false;
  _connected = false;

  @api isDeploying = false;
  @api templateLabel = "";

  /* ── State owned by manager, passed to children ── */
  @track assignedItems = [];
  @track availableItems = [];
  selectedCriterion;
  selectedItemValue;

  /* ── Internal data ── */
  _criteriaMap = new Map();
  _baselineAssigned = new Map();

  /* ── Computed ── */

  get isLoading() {
    return this._isLoadingAssignments || this._isLoadingCriteria;
  }

  get isInteractionDisabled() {
    return this.isSaving || this.isDeploying;
  }

  get assignmentCount() {
    return this.assignedItems.length;
  }

  get hasChanges() {
    if (this.assignedItems.length !== this._baselineAssigned.size) return true;
    for (const item of this.assignedItems) {
      const baseline = this._baselineAssigned.get(item.value);
      if (!baseline) return true;
      if (baseline.sequence !== item.sequence) return true;
    }
    for (const key of this._baselineAssigned.keys()) {
      if (!this.assignedItems.some((i) => i.value === key)) return true;
    }
    return false;
  }

  get isSaveDisabled() {
    return this.isSaving || this.isDeploying || !this.hasChanges;
  }

  /* ── Lifecycle ── */

  connectedCallback() {
    this._connected = true;
    this._loadData();
  }

  /* ── Data loading ── */

  async _loadData() {
    await Promise.all([this._loadCriteria(), this._loadAssignments()]);
    this._rebuildAvailable();
  }

  async _loadCriteria() {
    this._isLoadingCriteria = true;
    try {
      const data = await getCriteria();
      this._criteriaMap = new Map();
      if (data) {
        for (const c of data) {
          this._criteriaMap.set(c.DeveloperName, c);
        }
      }
    } catch (err) {
      console.error(
        "[AssignmentManager] Load criteria error:",
        err?.body?.message || err?.message || JSON.stringify(err)
      );
    } finally {
      this._isLoadingCriteria = false;
    }
  }

  async _loadAssignments() {
    if (!this.templateDevName) return;
    this._isLoadingAssignments = true;
    try {
      const data = await getTemplateAssignments({
        templateDeveloperName: this.templateDevName
      });
      this.error = undefined;

      this._baselineAssigned = new Map();
      const assigned = [];

      if (data) {
        for (let i = 0; i < data.length; i++) {
          const a = data[i];
          const critDevName = a.ContractReviewCriterion__r.DeveloperName;
          const seq = a.Sequence__c != null ? a.Sequence__c : i + 1;
          this._baselineAssigned.set(critDevName, {
            assignmentDevName: a.DeveloperName,
            sequence: seq
          });
          assigned.push({
            value: critDevName,
            label: a.ContractReviewCriterion__r.MasterLabel,
            sequence: seq
          });
        }
      }

      assigned.sort((a, b) => a.sequence - b.sequence);
      this._renumber(assigned);
      this.assignedItems = assigned;
    } catch (err) {
      console.error(
        "[AssignmentManager] Load error:",
        err?.body?.message || err?.message || JSON.stringify(err)
      );
      this.error = err;
      this.assignedItems = [];
      this.availableItems = [];
      this._baselineAssigned = new Map();
    } finally {
      this._isLoadingAssignments = false;
    }
  }

  _rebuildAvailable() {
    const assignedSet = new Set(this.assignedItems.map((i) => i.value));
    const available = [];
    for (const [devName, crit] of this._criteriaMap) {
      if (!assignedSet.has(devName)) {
        available.push({ value: devName, label: crit.MasterLabel });
      }
    }
    available.sort((a, b) => a.label.localeCompare(b.label));
    this.availableItems = available;
  }

  _renumber(items) {
    for (let i = 0; i < items.length; i++) {
      items[i].sequence = i + 1;
    }
  }

  /* ── Picker event handlers ── */

  handleAssign(event) {
    const values = new Set(event.detail.values);
    const newItems = this.availableItems
      .filter((i) => values.has(i.value))
      .map((i) => ({ value: i.value, label: i.label, sequence: 0 }));

    const merged = [...this.assignedItems, ...newItems];
    this._renumber(merged);
    this.assignedItems = merged;
    this._rebuildAvailable();
  }

  handleUnassign(event) {
    const values = new Set(event.detail.values);
    const remaining = this.assignedItems.filter((i) => !values.has(i.value));
    this._renumber(remaining);
    this.assignedItems = remaining;
    this._rebuildAvailable();

    if (this.selectedItemValue && values.has(this.selectedItemValue)) {
      this.selectedCriterion = undefined;
      this.selectedItemValue = undefined;
    }
  }

  handleReorder(event) {
    const { value, direction } = event.detail;
    const items = [...this.assignedItems];
    const idx = items.findIndex((i) => i.value === value);
    if (idx < 0) return;

    const swapIdx = direction === "up" ? idx - 1 : idx + 1;
    if (swapIdx < 0 || swapIdx >= items.length) return;

    [items[idx], items[swapIdx]] = [items[swapIdx], items[idx]];
    this._renumber(items);
    this.assignedItems = items;
  }

  handleAssignToIndex(event) {
    const { value, targetIndex } = event.detail;
    const item = this.availableItems.find((i) => i.value === value);
    if (!item) return;

    const newItem = { value: item.value, label: item.label, sequence: 0 };
    const items = [...this.assignedItems];
    items.splice(targetIndex, 0, newItem);
    this._renumber(items);
    this.assignedItems = items;
    this._rebuildAvailable();
  }

  handleReorderToIndex(event) {
    const { value, targetIndex } = event.detail;
    const items = [...this.assignedItems];
    const currentIdx = items.findIndex((i) => i.value === value);
    if (currentIdx < 0 || currentIdx === targetIndex) return;

    const [moved] = items.splice(currentIdx, 1);
    items.splice(targetIndex, 0, moved);
    this._renumber(items);
    this.assignedItems = items;
  }

  handleItemClick(event) {
    const { value } = event.detail;
    this.selectedItemValue = value;
    this.selectedCriterion = this._criteriaMap.get(value) || undefined;
  }

  /* ── Criterion edit (from info panel) ── */

  async handleCriterionSave(event) {
    const { developerName, label, fields } = event.detail;
    const record = buildCriterionRecord(developerName, label, fields);

    this.isSaving = true;

    try {
      const jobId = await deploy([record]);

      // Optimistic update: merge edited values into local state
      const existing = this._criteriaMap.get(developerName);
      if (existing) {
        const updated = {
          ...existing,
          MasterLabel: label,
          Definition__c: fields.Definition__c,
          Display_Title_Eng__c: fields.Display_Title_Eng__c,
          Display_Title__c: fields.Display_Title__c,
          Output_when_True_Eng__c: fields.Output_when_True_Eng__c,
          Output_When_True_sv__c: fields.Output_When_True_sv__c,
          Output_When_False_eng__c: fields.Output_When_False_eng__c,
          Output_When_False_sv__c: fields.Output_When_False_sv__c
        };
        this._criteriaMap.set(developerName, updated);
        if (this.selectedItemValue === developerName) {
          this.selectedCriterion = updated;
        }
        // Update label in assigned/available lists
        this.assignedItems = this.assignedItems.map((i) => {
          return i.value === developerName ? { ...i, label } : i;
        });
        this._rebuildAvailable();
      }

      this.dispatchEvent(
        new CustomEvent("deployinitiated", {
          detail: {
            jobId,
            entityType: "criterion",
            developerName
          }
        })
      );
    } catch (err) {
      console.error(
        "[AssignmentManager] Criterion deploy error:",
        err?.body?.message || err?.message || JSON.stringify(err)
      );
      this.dispatchEvent(
        new ShowToastEvent({
          title: "Distributionsfel",
          message: extractDeployError(err),
          variant: "error",
          mode: "sticky"
        })
      );
    } finally {
      this.isSaving = false;
    }
  }

  /* ── Save / Deploy ── */

  async handleSaveAssignments() {
    const { records, addedCount, removedCount } = buildAssignmentPayload(
      this.assignedItems,
      this._baselineAssigned,
      this.templateDevName,
      this.templateLabel
    );

    if (records.length === 0) {
      this.dispatchEvent(
        new ShowToastEvent({
          title: "Inga ändringar",
          message: "Inga tilldelningsändringar att distribuera.",
          variant: "info"
        })
      );
      return;
    }

    this.isSaving = true;

    try {
      const jobId = await deploy(records);
      this.dispatchEvent(
        new CustomEvent("deployinitiated", {
          detail: {
            jobId,
            entityType: "assignment",
            developerName: this.templateDevName,
            addedCount,
            removedCount,
            totalRecords: records.length
          }
        })
      );
    } catch (err) {
      console.error(
        "[AssignmentManager] Deploy error:",
        err?.body?.message || err?.message || JSON.stringify(err)
      );
      this.dispatchEvent(
        new ShowToastEvent({
          title: "Distributionsfel",
          message: extractDeployError(err),
          variant: "error",
          mode: "sticky"
        })
      );
    } finally {
      this.isSaving = false;
    }
  }

  /* ── Public API ── */

  @api
  async refresh() {
    await this._loadData();
    // Re-resolve selected criterion from refreshed data
    if (this.selectedItemValue) {
      this.selectedCriterion =
        this._criteriaMap.get(this.selectedItemValue) || undefined;
    } else {
      this.selectedCriterion = undefined;
    }
  }

  /**
   * Refreshes the criteria map from the server without touching assignment
   * state (assignedItems / _baselineAssigned). This preserves any pending
   * assignment edits while ensuring criterion labels and field data are
   * up-to-date after a non-assignment deploy.
   *
   * Note: updating selectedCriterion is safe because the info panel's
   * set criterion() only resets _isEditing when DeveloperName changes.
   * After a criterion save, handleSave() clears _isEditing before the
   * deploy event propagates, so the edit form is already closed.
   */
  @api
  async refreshCriteriaOnly() {
    await this._loadCriteria();
    // Reconcile labels in the assigned list against fresh criteria data
    this.assignedItems = this.assignedItems.map((item) => {
      const fresh = this._criteriaMap.get(item.value);
      return fresh ? { ...item, label: fresh.MasterLabel } : item;
    });
    this._rebuildAvailable();
    if (this.selectedItemValue) {
      this.selectedCriterion =
        this._criteriaMap.get(this.selectedItemValue) || undefined;
    } else {
      this.selectedCriterion = undefined;
    }
  }
}