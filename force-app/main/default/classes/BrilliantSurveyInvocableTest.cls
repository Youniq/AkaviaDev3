@isTest
private class BrilliantSurveyInvocableTest {
    
    
    @isTest
    static void testSendToBrilliant_MissingContact() {
        Case caseWithoutContact = new Case(
            Subject = 'No Contact Case',
            Origin = 'Email',
            Status = 'Closed'
        );
        insert caseWithoutContact;
        
        BrilliantSurveyInvocable.Input input = new BrilliantSurveyInvocable.Input();
        input.CaseId = caseWithoutContact.Id;
        
        BrilliantSurveyInvocable.sendToBrilliant(new List<BrilliantSurveyInvocable.Input>{ input });
        
        List<Callout__c> callouts = [SELECT Id, Status__c FROM Callout__c WHERE Case__c = :caseWithoutContact.Id];
        System.assertEquals(1, callouts.size());
        System.assertEquals('Failed', callouts[0].Status__c);
    }
    
    @isTest
    static void testSendToBrilliant_NullInputs() {
        BrilliantSurveyInvocable.sendToBrilliant(null);
        
        List<Callout__c> callouts = [SELECT Id FROM Callout__c];
        System.assertEquals(0, callouts.size());
    }
}