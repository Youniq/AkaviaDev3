@IsTest
public with sharing class BillectaCreateInvoiceTest {

  @IsTest
  static void testParseCreatedView() {
    String jsonBody = '{"PublicId":"invoice-public-id-123"}';

    BillectaCreateInvoice.CreatedView result =
      BillectaCreateInvoice.parse(jsonBody);

    Assert.isNotNull(result);
    Assert.areEqual('invoice-public-id-123', result.PublicId);
  }

  @IsTest
  static void testCreateInvoiceDtoFieldsCanBeSet() {
    BillectaCreateInvoice invoice = new BillectaCreateInvoice();

    invoice.CreditorPublicId = 'creditor-id';
    invoice.ExternalId = 'external-id';
    invoice.SocialSecurityNumber = '740121-0674';
    invoice.MemberNumber = '12345';
    invoice.MembershipCategory = 'Yrkesverksam';
    invoice.FeeCategory = 'Fullbetalande';
    invoice.HaveAkassa = false;
    invoice.IsCreditInvoice = false;
    invoice.HaveIncomeInsurance = true;
    invoice.UseDebtorBalance = true;
    invoice.PeriodStart = Date.newInstance(2026, 6, 1);
    invoice.PeriodEnd = Date.newInstance(2026, 6, 30);
    invoice.DueDate = Date.newInstance(2026, 6, 28);

    Assert.areEqual('creditor-id', invoice.CreditorPublicId);
    Assert.areEqual('external-id', invoice.ExternalId);
    Assert.areEqual('740121-0674', invoice.SocialSecurityNumber);
    Assert.areEqual('12345', invoice.MemberNumber);
    Assert.areEqual('Yrkesverksam', invoice.MembershipCategory);
    Assert.areEqual('Fullbetalande', invoice.FeeCategory);
    Assert.areEqual(false, invoice.HaveAkassa);
    Assert.areEqual(false, invoice.IsCreditInvoice);
    Assert.areEqual(true, invoice.HaveIncomeInsurance);
    Assert.areEqual(true, invoice.UseDebtorBalance);
    Assert.areEqual(Date.newInstance(2026, 6, 1), invoice.PeriodStart);
    Assert.areEqual(Date.newInstance(2026, 6, 30), invoice.PeriodEnd);
    Assert.areEqual(Date.newInstance(2026, 6, 28), invoice.DueDate);
  }

  @IsTest
  static void testParseEmptyJson() {
    BillectaCreateInvoice.CreatedView result =
      BillectaCreateInvoice.parse('{}');

    Assert.isNotNull(result);
    Assert.areEqual(null, result.PublicId);
  }
}