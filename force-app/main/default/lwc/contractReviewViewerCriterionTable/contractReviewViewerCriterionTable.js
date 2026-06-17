/**
 * Renders the criterion table on the Resultat tab.
 *
 * Settings (hide met criteria, show tooltips, choose Extract vs AI Comment
 * column) are persisted client-side under the `crv-criterionTableSettings`
 * localStorage key. Opens `c/contractReviewCriterionViewModal` when a row is
 * previewed.
 *
 * Inputs: `@api criteria` (list of ContractReviewRuntimeCriterion__c).
 */
import { LightningElement, api } from "lwc";
import ContractReviewCriterionViewModal from "c/contractReviewCriterionViewModal";
import { FIELD_EXTRACT, FIELD_AI_COMMENT, LABEL_EXTRACT, LABEL_AI_COMMENT } from "c/contractReviewUtils";

const SETTINGS_KEY = 'crv-criterionTableSettings';

export default class ContractReviewViewerCriterionTable extends LightningElement {
  _criteria = [];
  hideMetCriteria = false;
  settingsOpen = false;
  displayField = FIELD_EXTRACT;
  disableTooltip = false;
  _activeTooltip = null;
  _tooltipTop = 0;
  _tooltipLeft = 0;

  constructor() {
    super();
    this._loadSettings();
  }

  _loadSettings() {
    try {
      const raw = localStorage.getItem(SETTINGS_KEY);
      if (raw) {
        const s = JSON.parse(raw);
        if (typeof s.hideMetCriteria === 'boolean') this.hideMetCriteria = s.hideMetCriteria;
        if (s.displayField === FIELD_EXTRACT || s.displayField === FIELD_AI_COMMENT) this.displayField = s.displayField;
        if (typeof s.disableTooltip === 'boolean') this.disableTooltip = s.disableTooltip;
      }
    } catch (e) { // eslint-disable-line no-unused-vars
      // corrupted or inaccessible storage — use defaults
    }
  }

  _saveSettings() {
    try {
      localStorage.setItem(SETTINGS_KEY, JSON.stringify({
        hideMetCriteria: this.hideMetCriteria,
        displayField: this.displayField,
        disableTooltip: this.disableTooltip
      }));
    } catch (e) { // eslint-disable-line no-unused-vars
      // storage full or access denied — in-memory state is still correct
    }
  }

  @api
  get criteria() {
    return this._criteria;
  }
  set criteria(value) {
    this._criteria = value || [];
    this._activeTooltip = null;
  }

  // ─── Derived getters ───

  get filteredCriteria() {
    if (this.hideMetCriteria) {
      return this.criteria.filter((c) => !c.CriterionMet__c);
    }
    return this.criteria;
  }

  get displayedCriteria() {
    const isExtract = this.displayField === FIELD_EXTRACT;
    return this.filteredCriteria.map((c) => ({
      ...c,
      displayValue: isExtract ? c[FIELD_EXTRACT] : c[FIELD_AI_COMMENT],
      tooltipValue: isExtract ? c[FIELD_AI_COMMENT] : c[FIELD_EXTRACT],
      tooltipLabel: isExtract ? LABEL_AI_COMMENT : LABEL_EXTRACT
    }));
  }

  get displayColumnLabel() {
    return this.displayField === FIELD_EXTRACT ? LABEL_EXTRACT : LABEL_AI_COMMENT;
  }

  get isExtractSelected() {
    return this.displayField === FIELD_EXTRACT;
  }

  get isAiCommentSelected() {
    return this.displayField === FIELD_AI_COMMENT;
  }

  // ─── Template-binding getters for shared constants ───

  get fieldExtractValue() { return FIELD_EXTRACT; }
  get fieldAiCommentValue() { return FIELD_AI_COMMENT; }
  get radioExtractLabel() { return LABEL_EXTRACT; }
  get radioAiCommentLabel() { return LABEL_AI_COMMENT; }

  get hasCriteria() {
    return this.criteria.length > 0;
  }

  get hasDisplayedCriteria() {
    return this.displayedCriteria.length > 0;
  }

  get activeTooltip() {
    return this._activeTooltip;
  }

  get showTooltip() {
    return this._activeTooltip !== null;
  }

  get tooltipClass() {
    return 'criterion-tooltip' + (this.showTooltip ? ' criterion-tooltip-visible' : '');
  }

  get tooltipStyle() {
    return `top:${this._tooltipTop}px;left:${this._tooltipLeft}px`;
  }

  // ─── Event handlers ───

  handleToggleHideMet(event) {
    this.hideMetCriteria = event.target.checked;
    this._saveSettings();
  }

  handleToggleDisableTooltip(event) {
    this.disableTooltip = event.target.checked;
    this._activeTooltip = null;
    this._saveSettings();
  }

  handleToggleSettings() {
    this.settingsOpen = !this.settingsOpen;
  }

  handleCloseSettings() {
    this.settingsOpen = false;
  }

  handleDisplayFieldChange(event) {
    this.displayField = event.target.value;
    this._saveSettings();
  }

  handleSettingsKeydown(event) {
    if (event.key === 'Escape') {
      this.settingsOpen = false;
    }
  }

  handleRowMouseEnter(event) {
    if (this.disableTooltip) return;
    const id = event.currentTarget.dataset.id;
    const criterion = this.displayedCriteria.find((c) => c.Id === id);
    if (!criterion || !criterion.tooltipValue) {
      this._activeTooltip = null;
      return;
    }
    const rect = event.currentTarget.getBoundingClientRect();
    this._tooltipTop = rect.bottom + 4;
    this._tooltipLeft = rect.left;
    this._activeTooltip = { label: criterion.tooltipLabel, content: criterion.tooltipValue };
  }

  handleRowMouseLeave() {
    this._activeTooltip = null;
  }

  async handleOpenCriterion(event) {
    const criterionId = event.currentTarget.dataset.id;
    // Use raw criteria — modal expects SObject shape, not the mapped display object
    const criterion = this.criteria.find((c) => c.Id === criterionId);
    if (!criterion) {
      return;
    }
    await ContractReviewCriterionViewModal.open({
      size: "medium",
      criterion
    });
  }
}