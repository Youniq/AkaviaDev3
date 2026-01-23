/**
 * A class to put together the case owners out of office message to the case data.
 * Enables Front End to only make one server call and fetch both.
 */
public with sharing class CommunityCaseModel {
  @auraEnabled
  public Case caseRecord { get; set; }

  @AuraEnabled
  public Boolean ownerIsOutOfOffice { get; set; }

  @auraEnabled
  public String ownerOooMsg { get; set; }

  public CommunityCaseModel(Case caseInput, Boolean isOoo, String oooMsg) {
    this.caseRecord = caseInput;
    this.ownerIsOutOfOffice = isOoo;
    this.ownerOooMsg = oooMsg;
  }

  public CommunityCaseModel(Case caseInput) {
    this.caseRecord = caseInput;
  }
}