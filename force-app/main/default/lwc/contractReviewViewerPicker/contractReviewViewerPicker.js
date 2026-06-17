/**
 * Custom dropdown that lets the user switch between historic reviews on a
 * Case. Keyboard-navigable. Tooltip shows the review CreatedDate.
 *
 * Inputs: `@api reviews`, `@api selectedReviewId`. Emits a `select` custom
 * event when the user picks a row.
 */
import { LightningElement, api } from "lwc";

export default class ContractReviewViewerPicker extends LightningElement {
  _options = [];
  _value = null;
  _open = false;
  _focusedIndex = -1;

  @api
  get options() {
    return this._options;
  }
  set options(val) {
    this._options = val || [];
    this._focusedIndex = Math.min(this._focusedIndex, this._options.length - 1);
  }

  @api
  get value() {
    return this._value;
  }
  set value(val) {
    if (val !== this._value) {
      this._open = false;
      this._focusedIndex = -1;
    }
    this._value = val;
  }

  // ─── Derived getters ───

  get selectedLabel() {
    const opt = this._options.find((o) => o.value === this._value);
    return opt ? opt.label : 'Välj granskning';
  }

  get isOpen() {
    return this._open;
  }

  get ariaExpanded() {
    return String(this._open);
  }

  get focusedOptionId() {
    if (this._focusedIndex < 0 || this._focusedIndex >= this._options.length) {
      return undefined;
    }
    return 'opt-' + this._options[this._focusedIndex].value;
  }

  get optionsWithState() {
    return this._options.map((o, idx) => ({
      ...o,
      id: 'opt-' + o.value,
      optionClass: 'picker-option'
        + (o.value === this._value ? ' picker-option-selected' : '')
        + (idx === this._focusedIndex ? ' picker-option-focused' : ''),
      ariaSelected: o.value === this._value ? 'true' : 'false'
    }));
  }

  // ─── Handlers ───

  handleToggle() {
    this._open = !this._open;
    this._focusedIndex = -1;
  }

  handleClose() {
    this._open = false;
    this._focusedIndex = -1;
  }

  handleSelect(event) {
    const value = event.currentTarget.dataset.value;
    if (value && value !== this._value) {
      this.dispatchEvent(new CustomEvent('change', { detail: { value } }));
    }
    this._open = false;
    this._focusedIndex = -1;
  }

  handleKeydown(event) {
    const opts = this._options;
    if (!opts.length) return;

    switch (event.key) {
      case 'ArrowDown':
        event.preventDefault();
        this._focusedIndex = Math.min(this._focusedIndex + 1, opts.length - 1);
        this._scrollFocusedIntoView();
        break;
      case 'ArrowUp':
        event.preventDefault();
        this._focusedIndex = Math.max(this._focusedIndex - 1, 0);
        this._scrollFocusedIntoView();
        break;
      case 'Enter':
      case ' ':
        event.preventDefault();
        if (this._focusedIndex >= 0 && this._focusedIndex < opts.length) {
          const opt = opts[this._focusedIndex];
          if (opt.value !== this._value) {
            this.dispatchEvent(new CustomEvent('change', { detail: { value: opt.value } }));
          }
        }
        this._open = false;
        this._focusedIndex = -1;
        this.template.querySelector('.picker-trigger')?.focus();
        break;
      case 'Escape':
        event.preventDefault();
        this._open = false;
        this._focusedIndex = -1;
        this.template.querySelector('.picker-trigger')?.focus();
        break;
      case 'Tab':
        this._open = false;
        this._focusedIndex = -1;
        break;
      default:
        break;
    }
  }

  _scrollFocusedIntoView() {
    Promise.resolve().then(() => {
      const focused = this.template.querySelector('.picker-option-focused');
      if (focused) {
        focused.scrollIntoView({ block: 'nearest' });
      }
    });
  }
}