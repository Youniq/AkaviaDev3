@IsTest
public with sharing class EmailPublisherForCaseEmailsTest {
  @TestSetup
  static void makeData() {
    TestDataFactorySetupParams setupParams = new TestDataFactorySetupParams();
    setupParams.numberOfCases = 1;
    TestDataFactory.setupTestData(setupParams);
  }

  @IsTest
  static void testCaseEmailQuickAction() {
    Case testCase = [SELECT Id FROM Case LIMIT 1];

    //Create QuickActionDefaults
    // I'm not using the Test.newSendEmailQuickActionDefaults because I cannot control the actionType and actionName from there.
    List<Map<String, Object>> defaultSettingAsObject = new List<Map<String, Object>>{
      new Map<String, Object>{
        'targetSObject' => new EmailMessage(),
        'contextId' => testCase.Id,
        'actionType' => 'SendEmail',
        'actionName' => 'Case.SendEmail',
        'fromAddressList' => new List<String>{ 'salesforce@test.com' }
      }
    };

    List<QuickAction.SendEmailQuickActionDefaults> defaults = (List<QuickAction.SendEmailQuickActionDefaults>) JSON.deserialize(
      JSON.serialize(defaultSettingAsObject),
      List<QuickAction.SendEmailQuickActionDefaults>.class
    );

    Test.startTest();
    EmailPublisherForCaseEmails emailPubl = new EmailPublisherForCaseEmails();
    emailPubl.onInitDefaults(defaults);
    Test.stopTest();
    EmailMessage emailMessage = (EmailMessage) defaults[0].getTargetSObject();
    System.assertNotEquals(null, emailMessage);
  }
}