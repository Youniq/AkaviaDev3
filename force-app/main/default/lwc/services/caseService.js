import getCaseRecordTypeIdByDeveloperName from "@salesforce/apex/CommunityCaseControllerWSharing.getCaseRecordTypeIdByDeveloperName";
import getCaseRecordTypeNameById from "@salesforce/apex/CommunityCaseControllerWSharing.getCaseRecordTypeNameById";
import createNewCase from "@salesforce/apex/CommunityCaseControllerWSharing.createNewCase";
import getFeedItemsByCase from "@salesforce/apex/CommunityCaseController.getFeedItemsByCase";
import getSubCommentByCase from "@salesforce/apex/CommunityCaseController.getSubCommentByCase";
import getCase from "@salesforce/apex/CommunityCaseControllerWSharing.getCase";
import addFeedItemToCase from "@salesforce/apex/CommunityCaseControllerWSharing.addFeedItemToCase";
import getAccountCases from "@salesforce/apex/CommunityCaseControllerWSharing.getAccountCases";
import getAccountNewestCase from "@salesforce/apex/CommunityCaseControllerWSharing.getAccountNewestCase";
import getFilesContentVersion from "@salesforce/apex/CommunityCaseControllerWSharing.getFilesContentVersion";
import getActiveQuickCaseSettings from "@salesforce/apex/CommunityCaseController.getActiveQuickCaseSettings";

/**
 * Gets the Record Type with the ServiceCase Id.
 * @returns Array
 */
export async function getServiceCaseId() {
  try {
    const recordType = await getCaseRecordTypeIdByDeveloperName({
      developerName: "ServiceCase"
    });
    return recordType;
  } catch (e) {
    console.error("An error occured ", e);
    return null;
  }
}

/**
 * Gets the Record Type with the LegalCase Id.
 * @returns Array
 */
export async function getLegalCaseId() {
  try {
    const recordType = await getCaseRecordTypeIdByDeveloperName({
      developerName: "LegalCase"
    });
    return recordType;
  } catch (e) {
    console.error("An error occured ", e);
    return null;
  }
}

/**
 * Gets the Record Type by Developername
 * @returns Array
 */
export async function getRecordTypeByDeveloperName(devName) {
  try {
    const recordTypeId = await getCaseRecordTypeIdByDeveloperName({
      developerName: devName
    });
    return recordTypeId;
  } catch (e) {
    console.error("An error occured ", e);
    return null;
  }
}

export async function getRtNameByRtId(rtId) {
  try {
    const recordType = await getCaseRecordTypeNameById({ recordTypeId: rtId });
    return recordType;
  } catch (e) {
    console.error("An error occured ", e);
    return null;
  }
}

/**
 * Gets case record by case id
 * @param {string} caseId
 * @returns case Object
 */
export async function getCaseById(caseId) {
  try {
    const caseObj = await getCase({ caseId: caseId });
    return caseObj;
  } catch (e) {
    console.error("An error occured ", e);
    return null;
  }
}

/**
 * Creates a new Case record in Sf.
 * @param {Object} caseObj
 * @returns boolean indicating record creation was successful or not
 */
export async function addNewCase(caseObj) {
  try {
    const success = await createNewCase({ caseRecord: caseObj });
    return success;
  } catch (e) {
    console.error("An error occured ", e);
    return false;
  }
}

/**
 * Retrieves comments on a specific case
 * @param {string} caseId
 * @returns Array of comments [Case].
 */
export async function getCommentsByCaseId(caseId) {
  try {
    const feedItems = await getFeedItemsByCase({ caseId: caseId });
    const feedComments = await getSubCommentByCase({ caseId: caseId });
    return [...feedItems, ...feedComments];
  } catch (e) {
    console.error("An error occured ", e);
    return null;
  }
}

/**
 * Adds a new feed item record to a specific case.
 * @param {string} caseId
 * @param {string} commentBody
 * @returns the new comment.
 */
export async function addNewCaseComment(caseId, commentBody) {
  try {
    const success = await addFeedItemToCase({
      caseId: caseId,
      comment: commentBody
    });
    return success ? true : false;
  } catch (e) {
    console.error("An error occured ", e);
    return null;
  }
}

/**
 * Retrieved cases for specified account
 * @param {string} accId
 * @returns array of cases
 */
export async function getCasesByAccount(accId) {
  try {
    const cases = await getAccountCases({ accountId: accId });
    return cases;
  } catch (e) {
    console.error("An error occured ", e);
    return null;
  }
}

/**
 * Retrieves the most recent created Case by the specified contact.
 * @param {string} contactId
 * @returns Case object
 */
export async function getNewestCaseByAccount(accountId) {
  try {
    const caseItem = await getAccountNewestCase({ accountId: accountId });
    return caseItem;
  } catch (e) {
    console.error("An error occured", e);
    return null;
  }
}

/**
 * Fetch details on files, such as title and file extension
 * @param {string[]} contentDocIds - Array of ContentDocumentIds
 * @returns Object[] - Array of FileContent records.
 */
export async function getFilesContentVersionById(contentDocIds) {
  try {
    const files = await getFilesContentVersion({
      contentDocIds: contentDocIds
    });
    return files;
  } catch (e) {
    console.error("An error occured", e);
    return null;
  }
}

/**
 *
 * @returns Object[] - Array of settings used by the ContactForm Component /Quick Case component
 */
export async function getActivePortalQuickCaseSettingRecords() {
  try {
    const componentSettings = await getActiveQuickCaseSettings();
    return componentSettings;
  } catch (e) {
    console.error("An error occured: ", e);
    return null;
  }
}