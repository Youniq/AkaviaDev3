import { getDateString } from "c/utils";
import ID_FIELD from "@salesforce/schema/Case.Id";
import CASENUMBER_FIELD from "@salesforce/schema/Case.CaseNumber";
import RECORDTYPEID_FIELD from "@salesforce/schema/Case.RecordTypeId";
import CATEGORY_FIELD from "@salesforce/schema/Case.CategoryCommunity__c";
import STATUS_FIELD from "@salesforce/schema/Case.Status";
import CREATEDDATE_FIELD from "@salesforce/schema/Case.CreatedDate";
import OWNERID_FIELD from "@salesforce/schema/Case.OwnerId";
import SUBJECT_FIELD from "@salesforce/schema/Case.Subject";
import DESCRIPTION_FIELD from "@salesforce/schema/Case.Description";
import CONTACTID_FIELD from "@salesforce/schema/Case.ContactId";
import ORIGIN_FIELD from "@salesforce/schema/Case.Origin";
import PRIOTITY_FIELD from "@salesforce/schema/Case.Priority";
import TYPE_FIELD from "@salesforce/schema/Case.Type";

class Case {
  get formatedCreatedDate() {
    const dateObj = new Date(this[CREATEDDATE_FIELD.fieldApiName] || undefined);
    const dateString = getDateString(dateObj);
    return dateString;
  }

  /**
   * Defaults to {} if no argument is passed.
   * @param {object} obj
   */
  constructor(obj = {}) {
    let currCase;
    if (obj) {
      if (obj.caseRecord) {
        // When loading the caseInfo component we get an object from the apex class CommunityCaseModel {caseRecord, ownerIsOutOfOffice, ownerOooMsg}
        currCase = obj.caseRecord; // caseRecord is derived from Case in Sf.
      } else {
        // If obj isn't null and there's no property called caseRecord we know its an object directly derived from Case in Sf.
        currCase = obj;
      }
    }

    if (currCase) {
      this[ID_FIELD.fieldApiName] = currCase[ID_FIELD.fieldApiName];
      this[CASENUMBER_FIELD.fieldApiName] =
        currCase[CASENUMBER_FIELD.fieldApiName];
      this[RECORDTYPEID_FIELD.fieldApiName] =
        currCase[RECORDTYPEID_FIELD.fieldApiName];
      this.recordType = currCase.RecordType
        ? currCase.RecordType.Name
        : undefined;
      this[CATEGORY_FIELD.fieldApiName] = currCase[CATEGORY_FIELD.fieldApiName];
      this[STATUS_FIELD.fieldApiName] = currCase[STATUS_FIELD.fieldApiName];
      this[CREATEDDATE_FIELD.fieldApiName] =
        currCase[CREATEDDATE_FIELD.fieldApiName];
      this[OWNERID_FIELD.fieldApiName] = currCase[OWNERID_FIELD.fieldApiName];
      this[DESCRIPTION_FIELD.fieldApiName] =
        currCase[DESCRIPTION_FIELD.fieldApiName];
      this[SUBJECT_FIELD.fieldApiName] = currCase[SUBJECT_FIELD.fieldApiName];
      this[CONTACTID_FIELD.fieldApiName] =
        currCase[CONTACTID_FIELD.fieldApiName];
      this[ORIGIN_FIELD.fieldApiName] = currCase[ORIGIN_FIELD.fieldApiName];
      this[PRIOTITY_FIELD.fieldApiName] = currCase[PRIOTITY_FIELD.fieldApiName];
      this[TYPE_FIELD.fieldApiName] = currCase[TYPE_FIELD.fieldApiName];
      this.ContentDocumentLinks = currCase.ContentDocumentLinks;
      this.RecordTypeName = currCase.RecordTypeName; // Added at runtime.

      if (currCase.OwnerId) {
        // if ownerId starts with 005 - its a User
        if (currCase.OwnerId.indexOf("005") === 0) {
          this.ownerName = currCase.Owner
            ? `${currCase.Owner.FirstName} ${currCase.Owner.LastName}`
            : undefined;
        } // Ownerid starts with 005 is a queue/group
        else if (currCase.OwnerId.indexOf("00G") === 0) {
          this.ownerName = currCase.Owner ? currCase.Owner.Name : undefined;
        }
      }

      // Owner Out of Office part. If
      if (obj.ownerIsOutOfOffice) {
        this.ownerIsOoo = obj.ownerIsOutOfOffice;
        if (obj.ownerOooMsg && obj.ownerOooMsg.length > 0) {
          this.oooMsg = obj.ownerOooMsg;
        }
      }
    }
  }
}

export { Case };