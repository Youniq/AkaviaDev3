import ID_FIELD from "@salesforce/schema/Account.Id";
import PERSONEMAIL_FIELD from "@salesforce/schema/Account.PersonEmail";
import SELFEMPLOYEDEVALS_FIELD from "@salesforce/schema/Account.SelfemployedEvaluating__c";
import UNEMPLOYED_FIELD from "@salesforce/schema/Account.UnEmployed__c"; // "Arbetssökande, checkbox"

class Account {
  /**
   * returns true or false depending on if member is marked with self employment is evaluating.
   * This is true meanwhile a member has marked themselves
   *  as self employed until a support agent has performed some manual updates on the member.
   */
  get selfEmployedIsEvaluating() {
    return this[SELFEMPLOYEDEVALS_FIELD.fieldApiName];
  }

  /**
   * returns true or false depending on if member is marked as unemployed (arbetssökande)
   */
  get isUnemployed() {
    return this[UNEMPLOYED_FIELD.fieldApiName];
  }

  /**
   *
   * @param {string} id
   * @param {string} email
   * @param {boolean} selfEmloyedEvaluating
   * @param {boolean} unemployed
   */
  constructor(
    id,
    email = null,
    selfEmloyedEvaluating = null,
    unemployed = null
  ) {
    this[ID_FIELD.fieldApiName] = id;
    if (email) {
      this[PERSONEMAIL_FIELD.fieldApiName] = email;
    }
    this[SELFEMPLOYEDEVALS_FIELD.fieldApiName] = selfEmloyedEvaluating;
    this[UNEMPLOYED_FIELD.fieldApiName] = unemployed;
  }
}

export { Account };