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

  @InvocableMethod(label='Create Invoice in Billecta')
    public static void createInvoice(List<Request> requests) {
        for (Request r : requests) {
            System.debug('Input request: ' + r);

            if (r.retroactiveInvoiceInfo == null || r.retroactiveInvoiceInfo.PeriodStart == null) {
                BillectaDebtorStatusUpdateHelper.sendInvoice(r.accountId);
                continue;
            }

            if (!isDateWithinSixMonths(r.retroactiveInvoiceInfo.PeriodStart)) {
                throw new CustomException(
                    'Bad Period Start Date. It must be between one month ago - 6 months ago.'
                );
            }

            BillectaCreateInvoice invoiceInfo = r.retroactiveInvoiceInfo;

            Date startDate = Date.newInstance(
                invoiceInfo.PeriodStart.year(),
                invoiceInfo.PeriodStart.month(),
                1
            );

            invoiceInfo.PeriodStart = startDate;

            if (isPensionerCategory(invoiceInfo.MembershipCategory)) {
                invoiceInfo.PeriodEnd = startDate.addMonths(12).addDays(-1);
            } else {
                invoiceInfo.PeriodEnd = startDate.addMonths(1).addDays(-1);
            }

            invoiceInfo.DueDate = calculateDueDate(Date.today());

            //if (invoiceInfo.UseDebtorBalance == null) {
                invoiceInfo.UseDebtorBalance = true;
            //}

            BillectaDebtorStatusUpdateHelper.sendRetroactiveInvoice(
                r.accountId,
                invoiceInfo
            );
        }
    }

    private static Boolean isPensionerCategory(String membershipCategory) {
        if (String.isBlank(membershipCategory)) {
            return false;
        }

        String value = membershipCategory.trim().toLowerCase();
        return value.contains('pension');
    }

    private static Date calculateDueDate(Date baseDate) {
        Date current28 = Date.newInstance(baseDate.year(), baseDate.month(), 28);

        if (baseDate > current28) {
            Date nextMonth = baseDate.addMonths(1);
            return Date.newInstance(nextMonth.year(), nextMonth.month(), 28);
        }

        Integer daysUntil28 = baseDate.daysBetween(current28);

        if (daysUntil28 < 14) {
            Date nextMonth = baseDate.addMonths(1);
            return Date.newInstance(nextMonth.year(), nextMonth.month(), 28);
        }

        return current28;
    }

    private static Boolean isDateWithinSixMonths(Date startDate) {
      Date currentDate = Date.today();
      Date sixMonthsAgo = currentDate.addMonths(-6);

      Date currentMonthStart = Date.newInstance(
          currentDate.year(),
          currentDate.month(),
          1
      );

      Date sixMonthsAgoMonthStart = Date.newInstance(
          sixMonthsAgo.year(),
          sixMonthsAgo.month(),
          1
      );

      return startDate >= sixMonthsAgoMonthStart && startDate <= currentMonthStart;
  }
}