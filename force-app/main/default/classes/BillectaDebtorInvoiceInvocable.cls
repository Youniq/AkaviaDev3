/**
 * @description       : Creates an invoice in Billecta for the member. Create retroactive invoice or 'normal' invoice for current month
 *  As of june 2024 - The 'normal' invoice is not used at Akavia. They create invoices for current month using the same logic as for Retroactive invoices.
 * @author            : Malin Nilsson (Stretch Customer AB)
 * @group             :
 * @last modified on  : 2024-06-18
 * @last modified by  : Malin Nilsson (Stretch Customer AB)
 **/
public with sharing class BillectaDebtorInvoiceInvocable {
  public class Request {
    @invocableVariable(label='Account Id' Required=true)
    public String accountId;

    @invocableVariable(
      label='Retroactive Invoice Info'
      Description='Mapped to apex type: BillectaCreateInvoice.'
      Required=false
    )
    public BillectaCreateInvoice retroactiveInvoiceInfo;
  }

  @invocableMethod(label='Create Invoice in Billecta')
  public static void createInvoice(List<Request> requests) {
    for (Request r : requests) {
      System.debug('Input request: ' + r);

      if (
        r.retroactiveInvoiceInfo == null ||
        r.retroactiveInvoiceInfo.PeriodStart == null
      ) {
        BillectaDebtorStatusUpdateHelper.sendInvoice(r.accountId);
      } else if (
        r.retroactiveInvoiceInfo != null &&
        r.retroactiveInvoiceInfo.PeriodStart != null
      ) {
        // Validera datum så att de är från 6-1 månad sedan.
        if (isDateWithinSixMonths(r.retroactiveInvoiceInfo.PeriodStart)) {
          Date startDate = Date.newInstance(
            r.retroactiveInvoiceInfo.PeriodStart.year(),
            r.retroactiveInvoiceInfo.PeriodStart.month(),
            1
          );

          // End date shall always be the last day of the month, same month as the startDate.
          Date endDate = Date.newInstance(
              startDate.year(),
              startDate.month() + 1,
              1
            )
            .addDays(-1);
          r.retroactiveInvoiceInfo.PeriodEnd = endDate;
          r.retroactiveInvoiceInfo.PeriodStart = startDate;

          BillectaDebtorStatusUpdateHelper.sendRetroactiveInvoice(
            r.accountId,
            r.retroactiveInvoiceInfo
          );
        } else {
          throw new CustomException(
            'Bad Period Start Date. It must be between one month ago - 6 months ago.'
          );
        }
      }
    }
  }

  private static Boolean isDateWithinSixMonths(Date startDate) {
    // Get the current date
    Date currentDate = Date.today();

    // Calculate the date 6 months ago
    Date sixMonthsAgo = currentDate.addMonths(-6);

    // First day of current month
    Date currMonth = Date.newInstance(
      currentDate.year(),
      currentDate.month(),
      1
    );

    // Adjust sixMonthsAgo to the first day of the month
    sixMonthsAgo = Date.newInstance(
      sixMonthsAgo.year(),
      sixMonthsAgo.month(),
      1
    );

    // Check if the incoming date is within 6 months ago - current month. (Don't accept future invoices or inv older than 6 months)
    return startDate >= sixMonthsAgo && startDate <= currMonth;
  }
}