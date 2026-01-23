/**
 * @description       : Responsible of populating the RandomNo__c field on Account with a number between 1-100. This is used to be able to get a random selection of members
 * @author            : Malin Nilsson (Stretch Customer AB)
 * @group             : 
 * @last modified on  : 2025-01-09
 * @last modified by  : Malin Nilsson (Stretch Customer AB)
**/
public with sharing class SetAccountRandomNoBatch implements Database.Batchable<SObject> {
 
    public Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator('SELECT Id, RandomNo__c FROM Account WHERE RandomNo__c = NULL and IsPersonAccount = true and (membershipstatus__c = \'Aktiv\' or membershipstatus__c = \'Begärt utträde\')');
    }

    public void execute(Database.BatchableContext bc, List<SObject> scope) {
        List<Account> accountsToUpdate = new List<Account>();
        for (Account acc : (List<Account>)scope) {
            acc.RandomNo__c = Math.round(Math.random() * 99) + 1;
            accountsToUpdate.add(acc);
        }
        update accountsToUpdate;
    }

    public void finish(Database.BatchableContext bc) {
        // Optional post-processing
    }
}