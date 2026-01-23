import ID_FIELD from "@salesforce/schema/ContentVersion.Id";
import CONTENTDOCID_FIELD from "@salesforce/schema/ContentVersion.ContentDocumentId";
import TITLE_FIELD from "@salesforce/schema/ContentVersion.Title";
import FILEEXTENSION_FIELD from "@salesforce/schema/ContentVersion.FileExtension";
import LINKEDENTITYID_FIELD from "@salesforce/schema/ContentDocumentLink.LinkedEntityId";

class File {
  /**
   * Constructor for file
   * @param {object} obj - Content Version record object
   */
  constructor(obj = {}) {
    this[ID_FIELD.fieldApiName] = obj[ID_FIELD.fieldApiName];
    this[CONTENTDOCID_FIELD.fieldApiName] =
      obj[CONTENTDOCID_FIELD.fieldApiName];
    this[TITLE_FIELD.fieldApiName] = obj[TITLE_FIELD.fieldApiName];
    this[FILEEXTENSION_FIELD.fieldApiName] =
      obj[FILEEXTENSION_FIELD.fieldApiName];
    this[LINKEDENTITYID_FIELD.fieldApiName] =
      obj[LINKEDENTITYID_FIELD.fieldApiName];
  }

  getFileDownloadPath(basePath) {
    const fileDownloadEndString = `sfc/servlet.shepherd/document/download/${
      this[CONTENTDOCID_FIELD.fieldApiName]
    }`;

    // The basePath looks like /minasidor/s for Akavia Medlemsportal. We only want the minasidor part
    basePath = basePath.split("/").filter((i) => i !== "" && i !== "s")[0];
    return `${window.location.origin}/${basePath}/${fileDownloadEndString}`;
  }
}
export { File };