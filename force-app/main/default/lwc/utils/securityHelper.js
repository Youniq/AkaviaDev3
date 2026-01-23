/* eslint-disable @lwc/lwc/no-inner-html */
// Escape & Unescape HTML:
export function encode(string){
    const escapeEl = document.createElement('textarea');
    escapeEl.textContent = string;
    return escapeEl.innerHTML;
}

export function decode(string) {
    const escapeEl = document.createElement('textarea');
    escapeEl.innerHTML = string;
    return escapeEl.textContent;
}