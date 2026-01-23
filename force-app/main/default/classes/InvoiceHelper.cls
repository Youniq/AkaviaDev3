/**
 * @description       : Retrives a list of Invoices for the current user (Used in LWC InvoiceOverview)
 * @author            : Håkon Kavli
 * @group             : Stretch
 * @last modified on  : 2025-04-28
 * @last modified by  : Malin Nilsson (Stretch Customer AB)
 **/
public with sharing class InvoiceHelper {
  @AuraEnabled(cacheable=true)
  public static List<Invoice__c> getInvoices(String person, Integer maxRows) {
    List<Invoice__c> invoices = [
      SELECT Id, Name, ExpirationDate__c, PaymentStatus__c, InvoiceLink__c
      FROM Invoice__c
      WHERE Person__c = :person AND PaymentStatus__c = 'Betald'
      ORDER BY ExpirationDate__c DESC
      LIMIT :maxRows
    ];
    return invoices;
  }

  @AuraEnabled(cacheable=true)
  public static List<Invoice__c> getUnpaidInvoices(String person) {
    List<Invoice__c> unpaid = [
      SELECT Id, Name, ExpirationDate__c, PaymentStatus__c, InvoiceLink__c
      FROM Invoice__c
      WHERE Person__c = :person AND (PaymentStatus__c = 'Ej betald' OR PaymentStatus__c = 'Delbetald')
      ORDER BY ExpirationDate__c DESC
    ];
    return unpaid;
  }
}