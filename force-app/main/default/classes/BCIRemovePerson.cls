/**
 * @description       : 
 * @author            : Malin Nilsson (Stretch Customer AB)
 * @group             : 
 * @last modified on  : 2024-12-09
 * @last modified by  : Malin Nilsson (Stretch Customer AB)
**/
public with sharing class BCIRemovePerson {
  
  @InvocableMethod(
    label='Remove Person'
    description='Remove Person from Monitoring'
  )
  public static void removePersonFromBCI(List<FlowInputs> request) {
    Account acct = request[0].accountRecord;
    String accountJson = Json.serialize(acct);
    String protfolioId = request[0].portfolioId;
    System.debug('removePersonFromBCI');
    SparCallout.deletePersonFromProtfolio(accountJson, protfolioId);
  }

  public class FlowInputs {
    @InvocableVariable
    public Account accountRecord;

    @InvocableVariable
    public String portfolioId;
  }
}