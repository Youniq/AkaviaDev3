import getUsersActiveEmployment from "@salesforce/apex/CommunityEmploymentController.getUsersActiveEmployment";
import createNewEmployment from "@salesforce/apex/CommunityEmploymentController.createNewEmployment";
import updateEmployment from "@salesforce/apex/CommunityEmploymentController.updateEmployment";
import searchEmployers from "@salesforce/apex/CommunityEmploymentController.searchEmployers";
import getCompanyWorkplaces from "@salesforce/apex/CommunityEmploymentController.getCompanyWorkplaces";
//import { createRecord, updateRecord, generateRecordInputForUpdate } from "lightning/uiRecordApi";

/**
 * Retrieves the employment which is Active on user, if non is found an empty array is returned.
 * @param {string} usrAccountId
 * @returns Array with one current employment
 */
export async function getCurrEmployment(usrAccountId) {
  try {
    const employmentArr = await getUsersActiveEmployment({
      accountId: usrAccountId
    });
    return employmentArr;
  } catch (e) {
    console.error("An error occured ", e);
    return null;
  }
}

/**
 * Creates a new Employment record in Sf
 * @param {object} employmentObj
 * @returns Id if successful /false if not successful.
 */
export async function saveNewEmployment(employmentObj) {
  try {
    // await createRecord(employmentObj);
    // return true;
    const empId = await createNewEmployment({ empRecord: employmentObj });
    return empId;
  } catch (e) {
    console.error("An error occured ", e);
    return false;
  }
}

/**
 * Updates an existing employment record in Sf.
 * @param {object} employmentObj
 * @returns boolean indicating record update was successful or not
 */
export async function editEmployment(employmentObj) {
  try {
    // User doesn't have access to update record with this function. Hence going the apex way.
    // const recordToUpdate = {fields: {...employmentObj}};
    //const updObj = generateRecordInputForUpdate(recordToUpdate,{apiName:"Employment__c"});
    // const result = await updateRecord(recordToUpdate);
    // return true;

    const success = await updateEmployment({ employment: employmentObj });
    return success;
  } catch (ex) {
    console.error("An error occured ", ex);
    return false;
  }
}

/**
 * Search for employers containing a searchphrase.
 * @param {string} searchString
 * @returns Array of employers matching the searchphrase
 */
export async function searchForEmployers(searchString) {
  try {
    const results = await searchEmployers({ searchInput: searchString });
    return results;
  } catch (ex) {
    console.error("An error occured ", ex);
    return null;
  }
}

/**
 * Gets available workplaces for a specific employer
 * @param {string} employerId
 * @returns Array of workplaces
 */
export async function getEmployerWorkplaces(employerId) {
  try {
    const results = await getCompanyWorkplaces({ accountId: employerId });
    return results;
  } catch (ex) {
    console.error("An error occured ", ex);
    return null;
  }
}