public with sharing class ScheduleDeleteInvoices implements Schedulable {
  private static String CRON_EXPR = '0 30 03 ? * *'; // every day at 03:30 AM

  public static String scheduleIt() {
    ScheduleDeleteInvoices job = new ScheduleDeleteInvoices();
    String jobName;
    if (Test.isRunningTest()) {
      jobName = 'Invoices_-_Test_Schedule_Delete';
    } else {
      jobName = 'Invoices_-_Schedule_Delete';
    }
    return System.schedule(jobName, CRON_EXPR, job);
  }

  public void execute(SchedulableContext ctx) {
    /* Collects invoices which
     * is created more than one year ago and has the paymentStatus 'Betald'/'Makulerad'/'Pausad'
     * or if the invoice is older than 5 years (1827 days = 365*5 + 2, 2 for leapyears) and has a payment status = 'Ej betald'/'Delbetald'
     */
    String query = 'select id from Invoice__c where (CreatedDate < N_DAYS_AGO:365 AND (PaymentStatus__c  = \'Betald\' OR PaymentStatus__c = \'Makulerad\' OR PaymentStatus__c = \'Pausad\')) OR (CreatedDate < N_DAYS_AGO:1827 AND (PaymentStatus__c = \'Ej betald\' OR PaymentStatus__c = \'Delbetald\')) order by CreatedDate asc limit 100000';
    TEMP_BatchDelete b = new TEMP_BatchDelete(query);
    Database.executeBatch(b);
  }
}