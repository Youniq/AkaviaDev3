public with sharing class AccountsController
{
    private ApexPages.StandardSetController standardController;
    public AccountsController(ApexPages.StandardSetController standardController)
    {
        this.standardController = standardController;
    }
    public PageReference expelAccounts()
    {
        List<Account> selectedAccounts = (List<Account>) standardController.getSelected();
        if(selectedAccounts.size() > 10) {
            Database.executeBatch(new ExpelAccountBatchable(selectedAccounts), 10);
        } else {
            ExpelAccountsHandler.expel(selectedAccounts);
        }
        return null;
    }
}