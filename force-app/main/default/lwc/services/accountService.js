import updateAccount from "@salesforce/apex/CommunityAccountController.updateAccount";

/**
 * Updates an existing account record in Sf.
 * @param {object} accountObj
 * @returns boolean indicating record update was successful or not
 */
export async function editAccount(accountObj) {
  try {
    const success = await updateAccount({ account: accountObj });
    return success;
  } catch (ex) {
    console.error("An error occured ", ex);
    return false;
  }
}