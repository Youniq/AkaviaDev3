/**
 * Dual-list picker with drag-and-drop used by the assignment manager. Pure
 * presentation: takes left/right item arrays via `@api`, emits `change` with
 * the new selection ordering.
 */
import { LightningElement, api, track } from "lwc";

export default class ContractReviewAdminAssignmentPicker extends LightningElement {
  @api availableItems = [];
  @api assignedItems = [];
  @api selectedItemValue;
  @api disabled = false;

  @track _checkedAvailable = [];
  @track _checkedAssigned = [];

  /* ── Drag-and-drop state (non-reactive — no re-renders during drag) ── */
  _dragSource = null; // 'available' | 'assigned'
  _dragValue = null;
  _pendingDropIndex = null;
  _availDragEnterCount = 0;
  _assignDragEnterCount = 0;

  /* ── Computed ── */

  get draggableValue() {
    return this.disabled ? "false" : "true";
  }

  get hasAvailable() {
    return this.availableItems && this.availableItems.length > 0;
  }

  get hasAssigned() {
    return this.assignedItems && this.assignedItems.length > 0;
  }

  get decoratedAvailable() {
    const checkedSet = new Set(this._checkedAvailable);
    const sel = this.selectedItemValue;
    return this.availableItems.map((item) => ({
      ...item,
      isChecked: checkedSet.has(item.value),
      isSelected: item.value === sel,
      rowClass:
        "picker-row" + (item.value === sel ? " picker-row-selected" : "")
    }));
  }

  get decoratedAssigned() {
    const checkedSet = new Set(this._checkedAssigned);
    const sel = this.selectedItemValue;
    const len = this.assignedItems.length;
    return this.assignedItems.map((item, idx) => ({
      ...item,
      isChecked: checkedSet.has(item.value),
      isSelected: item.value === sel,
      isFirst: idx === 0,
      isLast: idx === len - 1,
      rowClass:
        "picker-row" + (item.value === sel ? " picker-row-selected" : "")
    }));
  }

  get isAssignDisabled() {
    return this.disabled || this._checkedAvailable.length === 0;
  }

  get isUnassignDisabled() {
    return this.disabled || this._checkedAssigned.length === 0;
  }

  /* ── Checkbox handlers ── */

  handleAvailableCheck(event) {
    const value = event.currentTarget.dataset.value;
    const checked = event.target.checked;
    if (checked) {
      this._checkedAvailable = [...this._checkedAvailable, value];
    } else {
      this._checkedAvailable = this._checkedAvailable.filter(
        (v) => v !== value
      );
    }
  }

  handleAssignedCheck(event) {
    const value = event.currentTarget.dataset.value;
    const checked = event.target.checked;
    if (checked) {
      this._checkedAssigned = [...this._checkedAssigned, value];
    } else {
      this._checkedAssigned = this._checkedAssigned.filter(
        (v) => v !== value
      );
    }
  }

  /* ── Row click → detail ── */

  handleCheckboxClick(event) {
    event.stopPropagation();
  }

  handleRowClick(event) {
    const value = event.currentTarget.dataset.value;
    this.dispatchEvent(new CustomEvent("itemclick", { detail: { value } }));
  }

  /* ── Assign / Unassign (button-driven) ── */

  handleAssign() {
    if (this._checkedAvailable.length === 0) return;
    this.dispatchEvent(
      new CustomEvent("assign", {
        detail: { values: [...this._checkedAvailable] }
      })
    );
    this._checkedAvailable = [];
  }

  handleUnassign() {
    if (this._checkedAssigned.length === 0) return;
    this.dispatchEvent(
      new CustomEvent("unassign", {
        detail: { values: [...this._checkedAssigned] }
      })
    );
    this._checkedAssigned = [];
  }

  /* ── Reorder (button-driven) ── */

  handleMoveUp(event) {
    event.stopPropagation();
    const value = event.currentTarget.dataset.value;
    this.dispatchEvent(
      new CustomEvent("reorder", { detail: { value, direction: "up" } })
    );
  }

  handleMoveDown(event) {
    event.stopPropagation();
    const value = event.currentTarget.dataset.value;
    this.dispatchEvent(
      new CustomEvent("reorder", { detail: { value, direction: "down" } })
    );
  }

  /* ── Drag-and-drop ── */

  handleDragStart(event) {
    if (this.disabled) {
      event.preventDefault();
      return;
    }
    // Checkbox interaction takes precedence over drag
    const target = event.target;
    if (
      target.tagName === "INPUT" ||
      target.closest(".picker-checkbox")
    ) {
      event.preventDefault();
      return;
    }

    const row = event.currentTarget;
    this._dragSource = row.dataset.list;
    this._dragValue = row.dataset.value;
    event.dataTransfer.effectAllowed = "move";
    event.dataTransfer.setData("text/plain", this._dragValue);

    // Defer so the browser captures the row before we dim it
    // eslint-disable-next-line @lwc/lwc/no-async-operation
    requestAnimationFrame(() => {
      row.classList.add("is-dragging");
    });
  }

  handleDragEnd() {
    this._cleanupDragState();
  }

  /* ── Available list drag events ── */

  handleDragOverAvailable(event) {
    if (!this._dragValue) return;
    event.preventDefault();
    event.dataTransfer.dropEffect = "move";
  }

  handleDragEnterAvailable() {
    if (!this._dragValue) return;
    this._availDragEnterCount++;
    if (this._availDragEnterCount === 1) {
      const list = this.template.querySelector(
        '.picker-list[aria-label="Tillgängliga kriterier"]'
      );
      if (list) list.classList.add("drag-over");
    }
  }

  handleDragLeaveAvailable() {
    if (!this._dragValue) return;
    this._availDragEnterCount--;
    if (this._availDragEnterCount <= 0) {
      this._availDragEnterCount = 0;
      const list = this.template.querySelector(
        '.picker-list[aria-label="Tillgängliga kriterier"]'
      );
      if (list) list.classList.remove("drag-over");
    }
  }

  handleDropOnAvailable(event) {
    event.preventDefault();
    if (!this._dragValue) return;

    if (this._dragSource === "assigned") {
      this.dispatchEvent(
        new CustomEvent("unassign", {
          detail: { values: [this._dragValue] }
        })
      );
    }
    this._cleanupDragState();
  }

  /* ── Assigned list drag events ── */

  handleDragOverAssigned(event) {
    if (!this._dragValue) return;
    event.preventDefault();
    event.dataTransfer.dropEffect = "move";
    this._updateDropIndicator(event);
  }

  handleDragEnterAssigned() {
    if (!this._dragValue) return;
    this._assignDragEnterCount++;
    if (this._assignDragEnterCount === 1) {
      const list = this.template.querySelector(
        '.picker-list[aria-label="Tilldelade kriterier"]'
      );
      if (list) list.classList.add("drag-over");
    }
  }

  handleDragLeaveAssigned() {
    if (!this._dragValue) return;
    this._assignDragEnterCount--;
    if (this._assignDragEnterCount <= 0) {
      this._assignDragEnterCount = 0;
      const list = this.template.querySelector(
        '.picker-list[aria-label="Tilldelade kriterier"]'
      );
      if (list) list.classList.remove("drag-over");
      this._clearDropIndicators();
    }
  }

  handleDropOnAssigned(event) {
    event.preventDefault();
    if (!this._dragValue) return;

    const targetIndex = this._calcDropIndex(event);

    if (this._dragSource === "available") {
      this.dispatchEvent(
        new CustomEvent("assigntoindex", {
          detail: { value: this._dragValue, targetIndex }
        })
      );
    } else if (this._dragSource === "assigned") {
      const currentIndex = this.assignedItems.findIndex(
        (i) => i.value === this._dragValue
      );
      // Adjust for removal shift: if dragging downward, the target shifts
      let adjustedIndex = targetIndex;
      if (currentIndex >= 0 && currentIndex < targetIndex) {
        adjustedIndex = targetIndex - 1;
      }
      if (currentIndex !== adjustedIndex) {
        this.dispatchEvent(
          new CustomEvent("reordertoindex", {
            detail: { value: this._dragValue, targetIndex: adjustedIndex }
          })
        );
      }
    }
    this._cleanupDragState();
  }

  /* ── Drag helpers (imperative DOM — no reactive re-renders) ── */

  _calcDropIndex(event) {
    const rows = this.template.querySelectorAll(
      '.picker-list[aria-label="Tilldelade kriterier"] [data-list="assigned"]'
    );
    if (!rows || rows.length === 0) return 0;

    const y = event.clientY;
    for (let i = 0; i < rows.length; i++) {
      const rect = rows[i].getBoundingClientRect();
      const midpoint = (rect.top + rect.bottom) / 2;
      if (y < midpoint) return i;
    }
    return rows.length;
  }

  _updateDropIndicator(event) {
    const rows = this.template.querySelectorAll(
      '.picker-list[aria-label="Tilldelade kriterier"] [data-list="assigned"]'
    );
    if (!rows || rows.length === 0) return;

    const y = event.clientY;
    let targetIdx = rows.length;
    for (let i = 0; i < rows.length; i++) {
      const rect = rows[i].getBoundingClientRect();
      const midpoint = (rect.top + rect.bottom) / 2;
      if (y < midpoint) {
        targetIdx = i;
        break;
      }
    }

    // Apply indicator classes imperatively
    for (let i = 0; i < rows.length; i++) {
      rows[i].classList.remove(
        "drop-indicator-above",
        "drop-indicator-below"
      );
    }
    if (targetIdx === 0) {
      rows[0].classList.add("drop-indicator-above");
    } else if (targetIdx <= rows.length) {
      rows[targetIdx - 1].classList.add("drop-indicator-below");
    }
  }

  _clearDropIndicators() {
    const rows = this.template.querySelectorAll(
      ".drop-indicator-above, .drop-indicator-below"
    );
    rows.forEach((r) =>
      r.classList.remove("drop-indicator-above", "drop-indicator-below")
    );
  }

  _cleanupDragState() {
    this._dragSource = null;
    this._dragValue = null;
    this._pendingDropIndex = null;
    this._availDragEnterCount = 0;
    this._assignDragEnterCount = 0;

    // Remove all drag-related CSS classes imperatively
    const dragging = this.template.querySelectorAll(".is-dragging");
    dragging.forEach((el) => el.classList.remove("is-dragging"));

    const dragOver = this.template.querySelectorAll(".drag-over");
    dragOver.forEach((el) => el.classList.remove("drag-over"));

    this._clearDropIndicators();
  }

  /* ── Public API ── */

  @api
  clearChecked() {
    this._checkedAvailable = [];
    this._checkedAssigned = [];
  }
}