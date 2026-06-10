/**
 * @description       : Creates an invoice in Billecta for the member. Create 'normal' 
 * invoice for current month As of june 2024 - The 'normal' invoice is not used at Akavia. 
 * Create 'retroactive' invoice (Account - ScreenFlow - CreateInvoiceInBillecta) use Billecta public API 
 * with an extended Json Blob. The reason is that the Due date for the invoice needs to be set to 28th of 
 * current month IF creation is 14 days before the 28th ELSE DueDate is set to 28th of next month.
 * @author            : Malin Nilsson (Stretch Customer AB)
 * @group             :
 * @last modified on  : 2026-06-05
 * @last modified by  : Stefan Trieton (Stretch Customer AB)
 **/
public with sharing class BillectaDebtorInvoiceInvocable {

    public class CustomException extends Exception {}

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

            BillectaCreateInvoice invoiceInfo = r.retroactiveInvoiceInfo;

            /** 
             * if (r.retroactiveInvoiceInfo == null || r.retroactiveInvoiceInfo.PeriodStart == null) {
                BillectaDebtorStatusUpdateHelper.sendInvoice(r.accountId);
                continue;
            }

            if (!isDateWithinSixMonths(r.retroactiveInvoiceInfo.PeriodStart)) {
                throw new CustomException(
                    'Bad Period Start Date. It must be between one month ago - 6 months ago.'
                );
            }

            if (invoiceInfo.Amount == null || invoiceInfo.Amount <= 0) {
                throw new CustomException('Amount saknas eller är 0 för retroaktiv faktura.');
            }

            if (String.isBlank(invoiceInfo.ProductPublicId)) {
                throw new CustomException('ProductPublicId saknas för retroaktiv faktura.');
            }

            // invoiceInfo.DueDate = calculateDueDate(Date.today());
            */

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

            invoiceInfo.UseDebtorBalance = true;

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

    // Not in use currently, DueDate is set to 28th of current or next month depending on creation date.
    private static Date calculateDueDate(Date baseDate) {

        //baseDate = baseDate.addDays(22); // TEST, REMOVE! if we are within 14 days from 28th, 
                                        // if so we set due date to 28th of next month, 
                                        //otherwise we set it to 28th of current month
        System.debug('Invoice date: ' + baseDate);

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