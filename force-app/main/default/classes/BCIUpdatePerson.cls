/**
 * Invocable method to be used by flow (Account_Screen_Flow_Update_SPAR)
 * to add or remove  person from portfolio in SPAR
 * @author Ahamad Amiri 
 * @since 2021-01-01
 */
public with sharing class BCIUpdatePerson {
  
  public class FlowInputs {
    @InvocableVariable
    public Account accountRecord;

    @InvocableVariable
    public String portfolioId;
  }
  
  @InvocableMethod(label='Get Person info' description='Update person account from BCI')
  public static void getPersonInfo(List<FlowInputs> request) {
    Account acct = request[0].accountRecord;
    String accountJson = Json.serialize(acct);
    String protfolioId = request[0].portfolioId;
    SparCallout.addRecordToPortfolio(accountJson, protfolioId);
  }
}