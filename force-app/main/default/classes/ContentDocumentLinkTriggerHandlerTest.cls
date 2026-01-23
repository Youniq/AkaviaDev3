/**
 * @description       :
 * @author            : Malin Nilsson (Stretch Customer AB)
 * @group             :
 * @last modified on  : 2024-10-04
 * @last modified by  : Malin Nilsson (Stretch Customer AB)
 **/
@IsTest
private class ContentDocumentLinkTriggerHandlerTest {
  @TestSetup
  private static void methodName() {
    TestDataFactorySetupParams params = new TestDataFactorySetupParams();
    params.numberOfAccounts = 1;
    params.numberOfContentVersions = 1;

    TestDataFactory.setupBasicTestData();
    TestDataFactory.setupTestData(params);
  }

  @IsTest
  static void test_share_file_to_record() {
    // query the generated content document id
    ContentVersion file = [
      SELECT Id, ContentDocumentId
      FROM ContentVersion
      LIMIT 1
    ];

    Account acct = [SELECT Id FROM Account LIMIT 1];

    Test.startTest();

    // share the file to the account
    ContentDocumentLink cdl = new ContentDocumentLink(
      ContentDocumentId = file.ContentDocumentId,
      LinkedEntityId = acct.Id,
      ShareType = 'I'
    );

    insert cdl; // trigger fires

    Test.stopTest();
  }
}