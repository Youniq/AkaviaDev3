/**
 * @description       : Updates the boolean field Account.IsCustomerPortal to the provided value. This field cannot be updated through flows, hence using apex-action.
 * @author            : Malin Nilsson (Stretch Customer AB)
 * @group             : 
 * @last modified on  : 2025-01-14
 * @last modified by  : Malin Nilsson (Stretch Customer AB)
**/
public with sharing class SetAccountIsCustomerPortalInvocable {
    public class request {
        @InvocableVariable(label='Account Id' description='Account Id' required=true)
         public Id accountId;

         @InvocableVariable(label='Is Customer Portal Value' description='True or False' required=true)
         public Boolean isCustPortalValue;
    }

    @InvocableMethod(label='Update Account.IsCustomerPortal' description='Updates the field IsCustomerPortal to the provided value on the Account record')
    public static void updateAccount(List<Request> requests){
        List<Account> accsToUpdate = new List<Account>();

        for(Request req : requests){
            Account acc = new Account();
            acc.Id = req.accountId;
            acc.IsCustomerPortal = req.isCustPortalValue;
            accsToUpdate.add(acc);
        }

        update accsToUpdate;
    }
}