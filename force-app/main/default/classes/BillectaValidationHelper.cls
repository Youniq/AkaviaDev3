/**
 * @description       :
 * @author            : Malin Nilsson (Stretch Customer AB)
 * @group             :
 * @last modified on  : 2024-02-26
 * @last modified by  : Malin Nilsson (Stretch Customer AB)
 **/
public without sharing class BillectaValidationHelper {
  public static String ACTION_CREATE = 'create';
  public static String ACTION_UPDATE = 'update';
  public static String ACTION_CREATEORUPDATE = 'createorupdate';

  public static final List<String> BILLECTA_ALLOWEDACTIONS = new List<String>{
    ACTION_CREATE,
    ACTION_UPDATE,
    ACTION_CREATEORUPDATE
  };

  /**
   * @description - helps to validate the inserted apex action input for InvocableVariable: billectaAction
   * @author Malin Nilsson (Stretch Customer AB) | 2024-02-19
   * @param billectaAction - String
   **/
  public static void validateBillectaActionInput(String billectaAction) {
    if (!BILLECTA_ALLOWEDACTIONS.contains(billectaAction.toLowerCase())) {
      // Invalid billecta action inserted to apex Action.
      throw new BillectaException(
        'Cannot sync to Billecta. The billectaAction is faulty: ' +
        billectaAction
      );
    }
  }

  /**
   * @description  - helps to validate that account is accepting the attempted billecta action.
   * @author Malin Nilsson (Stretch Customer AB) | 2024-02-19
   * @param acc - Account record
   * @param billectaAction - String
   **/
  public static void validateAccountForAction(
    Account acc,
    String billectaAction
  ) {
    if (
      billectaAction.toLowerCase() == ACTION_CREATE &&
      acc.BillectaID__c != null
    ) {
      throw new BillectaException(
        'Cannot create debtor in Billecta. Billecta Id already exists on Account: ' +
        '\'' +
        acc.Id +
        '\'.'
      );
    }

    if (
      billectaAction.toLowerCase() == ACTION_UPDATE &&
      acc.BillectaID__c == null
    ) {
      throw new BillectaException(
        'Cannot update debtor in Billecta. Billecta Id missing on Account: ' +
        '\'' +
        acc.Id +
        '\'.'
      );
    }
  }
}