/**
 * isParallel=false: TestDataFactory.createTestMemberUsers uppdaterar orgens
 * adminanvändare, vilket ger UNABLE_TO_LOCK_ROW om flera klasser kör samtidigt.
 */
@IsTest(isParallel=false)
private class WebropolSurveyControllerTest {
  @IsTest
  static void getPersonalSurveyLink_withoutContact_returnsError() {
    Test.startTest();
    WebropolSurveyService.LinkResult result = WebropolSurveyController.getPersonalSurveyLink(
      'Default'
    );
    Test.stopTest();

    System.assertEquals(false, result.success);
    System.assert(
      String.isNotBlank(result.message),
      'Ska returnera felmeddelande'
    );
  }

  @IsTest
  static void getPersonalSurveyLink_asMemberUser_returnsLink() {
    TestDataFactory.setupBasicTestData();
    TestDataFactorySetupParams params = new TestDataFactorySetupParams();
    params.numberOfMemberUsers = 1;
    User member = TestDataFactory.createTestMemberUsers(params, true)[0];
    Account person = [
      SELECT Id, MemberNumber__c, PersonEmail
      FROM Account
      WHERE PersonContactId = :member.ContactId
      LIMIT 1
    ];
    person.MemberNumber__c = '8462';
    person.PersonEmail = 'member.portal@example.com';
    update person;

    WebropolClient.clearTokenCacheForTest();
    Test.setMock(
      HttpCalloutMock.class,
      WebropolHttpCalloutMock.successDefaults()
    );

    Test.startTest();
    WebropolSurveyService.LinkResult result;
    System.runAs(member) {
      result = WebropolSurveyController.getPersonalSurveyLink('Default');
    }
    Test.stopTest();

    System.assertEquals(true, result.success, result.message);
    System.assert(
      String.isNotBlank(result.personalLink),
      'Portalanvändare ska få personlig länk'
    );
  }
}