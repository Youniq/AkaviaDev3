/**
 *  Returns a function, that, as long as it continues to be invoked, will not
 * be triggered. The function will be called after it stops being called for
 * N milliseconds. If `immediate` is passed, trigger the function on the
 * leading edge, instead of the trailing.
 * @param {function} func
 * @param {int} wait
 * @param {boolean} immediate
 * @returns function
 */
 export function debounce(func, wait, immediate) {
    var timeout;
    return function () {
      var context = this,
        args = arguments;
      var later = function () {
        timeout = null;
        if (!immediate) func.apply(context, args);
      };
      var callNow = immediate && !timeout;
      clearTimeout(timeout);
      timeout = setTimeout(later, wait);
      if (callNow) func.apply(context, args);
    };
  }
  
  /**
   *
   * @param {string[]} values
   * @returns An Enum like Object
   */
  export function createEnum(values) {
    const enumObj = {};
    for (const val of values) {
      enumObj[val] = val;
    }
    return Object.freeze(enumObj);
  }
  

  /**
   * Checks weatcher event was triggered from Mouse click or keybord 'Enter' press.
   * Used when adding sort functionality on table headers.
   * @param {Object} evt 
   * @returns boolean value indicating if evvent was triggered correctly
   */
  export function sortEventTriggeredOk(evt) {
    const isClickEvent = (evt.type === 'click');
    const keyCode = evt.code ? evt.code : evt.keyCode;

     // Enter/Return = 13
    if(keyCode !== 13 && keyCode!== "Enter" && !isClickEvent) { 
         return false; // abort if it was invalid trigger
    }

    const target = evt.currentTarget;
    if(!target.parentNode && !target.parentNode.matches('th[aria-sort]')) {
        return false; // abort if we don't have the correct target
    }
    return true;
}

  /**
   * Sorts an Object array in by one of the properties/fields existing on the objects listed.
   * @param {Object[]} objArray - array of objects to sort
   * @param {string} propertyAsString - what property to sort on
   * @param {boolean} sortAsc - sort order. Ascending by default.
   * @returns Sorted Array of objects
   */
  export function sortObjArrayByProperty(objArray, propertyAsString, sortAsc=true) {
    if (!objArray.length) return objArray;
    const reverse = sortAsc ? 1 : -1;
  
    const sortedArray = objArray.sort((a, b) => {
      var nameA = a[propertyAsString]?.toUpperCase(); // ignore upper and lowercase
      var nameB = b[propertyAsString]?.toUpperCase(); // ignore upper and lowercase
      if (nameA < nameB) {
        return -1 * reverse;
      }
      else if (nameA > nameB) {
        return 1 * reverse;
      }
  
      // names must be equal
      return 0;
    });
    return sortedArray;
  }

  /**
   * 
   * @param {Object[]} objArray - Array of objects to sort
   * @param {string} dateProperty - Property of object holding the date to sort on.
   * @param {boolean} sortAsc - true if list should be sorted ascending. Descening is default. 
   * @returns 
   */
  export function sortObjArrByDateProperty(objArray, dateProperty, sortAsc=false) {
    if (!objArray.length) return objArray;
    const reverse = sortAsc ? -1 : 1;

    const sortedArray = objArray.sort((a,b) => {
      var dateA = new Date(a[dateProperty]).getTime();
      var dateB = new Date(b[dateProperty]).getTime();

      if(dateA < dateB) {
        return 1 * reverse;
      } else if (dateA > dateB) {
        return -1 * reverse;
      }
      // If they are the same
      return 0;
    });
    return sortedArray;
  }

  /**
   * Used in the getDateString in order to have dates formatted as 01 for january instead of just 1.
   * @param {int} i 
   * @returns zero filled integer
   */
  function zerofill(i) {
      return (i < 10 ? '0' : '') + i;
  }

export function getDateString(dateObj) {
    const year = dateObj.getFullYear();
    const month = zerofill(dateObj.getMonth()+1); // Month is 0 based (jan = 0) hance adding 1 for correct format.
    const day = zerofill(dateObj.getDate());
    return `${year}-${month}-${day}`;
}

export function getTimeString(dateObj) {
  const hours = zerofill(dateObj.getHours());
  const mins = zerofill(dateObj.getMinutes());
  return `${hours}:${mins}`;
}

export function getYesterday() {
  const today = new Date();
  const yesterday = new Date();
  yesterday.setDate(today.getDate() - 1);
  return yesterday;
}

export function scrollToTop() {
  var scrollOptions = {
      left: 0,
      top: 0,
      behavior: 'smooth'
  }
  window.scrollTo(scrollOptions);
}

export function scrollToBottom() {
  var scrollOptions = {
    left: 0,
    top: document.body.scrollHeight,
    behavior: 'smooth'
  }
  window.scrollTo(scrollOptions);
}

export function stripHTMLFromText(richText) {
  if (!richText || richText===''){
    return '';
  }  
  // Using Regular expression to identify HTML tags in 
  // the input string. Replacing the identified 
  // HTML tag with a empty string.
  richText = richText.toString();
  // This one removes the whole tag like <p> and not just the tags. 
  return richText.replace( /(<([^>]+)>)/ig, '');

  // This one removes the characters listed in regex - <p> becomes p.
  // return richText.replaceAll(/[<^>+>()\[\]]/gi, "");
}