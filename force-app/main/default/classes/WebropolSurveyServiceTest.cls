/**
 * isParallel=false: TestDataFactory.createTestMemberUsers uppdaterar orgens
 * adminanvändare, vilket ger UNABLE_TO_LOCK_ROW om flera klasser kör samtidigt.
 */
@IsTest(isParallel=false)
private class WebropolSurveyServiceTest {
  @IsTest
  static void resolvePersonalLink_matchesMemberId() {
    String json =
      '[{"PersonalLinkToSurvey":"https://link.webropolsurveys.com/R/ABC",' +
      '"Fields":[{"FieldName":"1:1:MemberId","FieldValue":"8462"}]}]';

    Test.startTest();
    String link = WebropolSurveyService.resolvePersonalLink(
      json,
      '8462',
      'MemberId'
    );
    Test.stopTest();

    System.assertEquals(
      'https://link.webropolsurveys.com/R/ABC',
      link,
      'Ska returnera matchad personlig länk'
    );
  }

  @IsTest
  static void resolvePersonalLink_noMatchThrows() {
    String json =
      '[{"PersonalLinkToSurvey":"https://link.webropolsurveys.com/R/ABC",' +
      '"Fields":[{"FieldName":"1:1:MemberId","FieldValue":"9999"}]}]';
    Boolean thrown = false;
    Test.startTest();
    try {
      WebropolSurveyService.resolvePersonalLink(json, '8462', 'MemberId');
    } catch (WebropolException ex) {
      thrown = true;
      System.assert(
        ex.getMessage().contains('8462'),
        'Felmeddelande ska nämna MemberID'
      );
    }
    Test.stopTest();
    System.assert(thrown, 'Ska kasta vid ingen träff');
  }

  @IsTest
  static void resolvePersonalLink_singleRecipientWithoutBackgroundDataIsPending() {
    String json =
      '{"RecipientId":"baf8f886-fbb4-475d-8b0a-4a3ff7a9bda0",' +
      '"Email":"jesper.johansson@akavia.se",' +
      '"PersonalLinkToSurvey":"https://link.webropolsurveys.com/R/0D03FC8228D0B915",' +
      '"DemData":null,"RespondentAnswers":null}';

    Boolean pending = false;
    Test.startTest();
    try {
      WebropolSurveyService.resolvePersonalLink(json, '851288', 'MemberId');
    } catch (WebropolSurveyService.RecipientPendingException ex) {
      pending = true;
    }
    Test.stopTest();

    System.assert(pending, 'Länken får inte lämnas ut innan importen är klar');
  }

  @IsTest
  static void resolvePersonalLink_singleRecipientWithoutMemberIdQuestion() {
    String json =
      '{"RecipientId":"baf8f886-fbb4-475d-8b0a-4a3ff7a9bda0",' +
      '"PersonalLinkToSurvey":"https://link.webropolsurveys.com/R/0D03FC8228D0B915",' +
      '"RespondentAnswers":[{"QuestionTitle":"ContactId",' +
      '"QuestionAnswers":[{"OptionAnswer":"003xx"}]}]}';

    Test.startTest();
    String link = WebropolSurveyService.resolvePersonalLink(
      json,
      '851288',
      'MemberId'
    );
    Test.stopTest();

    System.assertEquals(
      'https://link.webropolsurveys.com/R/0D03FC8228D0B915',
      link,
      'Ska acceptera ensam respondent nar MemberId saknas i API-svar'
    );
  }

  @IsTest
  static void ensurePersonalLink_pendingRecipientIsNotRecreated() {
    WebropolClient.clearTokenCacheForTest();
    Test.setMock(
      HttpCalloutMock.class,
      new WebropolHttpCalloutMock(
        200,
        '{"access_token":"t","expires_in":3600}',
        200,
        '[{"RecipientId":"r1","RespondentAnswers":null,' +
          '"PersonalLinkToSurvey":"https://link.webropolsurveys.com/R/PENDING"}]'
      )
    );

    Test.startTest();
    WebropolSurveyService.LinkResult result = WebropolSurveyService.ensurePersonalLink(
      'Default',
      '8462',
      'medlem@example.com',
      true
    );
    Test.stopTest();

    System.assertEquals(false, result.success);
    System.assertEquals(true, result.pending);
    System.assertEquals(false, result.createdRecipient);
    System.assertEquals(null, result.personalLink);
  }

  @IsTest
  static void resolvePersonalLink_matchesRespondentAnswers() {
    String json =
      '[{"PersonalLinkToSurvey":"https://link.webropolsurveys.com/R/NEW",' +
      '"RespondentAnswers":[{' +
      '"QuestionTitle":"MemberId",' +
      '"QuestionAnswers":[{"OptionAnswer":"9999994"}]}]}]';

    Test.startTest();
    String link = WebropolSurveyService.resolvePersonalLink(
      json,
      '9999994',
      'MemberId'
    );
    Test.stopTest();

    System.assertEquals(
      'https://link.webropolsurveys.com/R/NEW',
      link,
      'Ska matcha MemberId i RespondentAnswers'
    );
  }

  @IsTest
  static void resolvePersonalLink_nullLinkThrows() {
    String json =
      '[{"PersonalLinkToSurvey":null,' +
      '"Fields":[{"FieldName":"1:1:MemberId","FieldValue":"8462"}]}]';
    Boolean thrown = false;
    Test.startTest();
    try {
      WebropolSurveyService.resolvePersonalLink(json, '8462', 'MemberId');
    } catch (WebropolException ex) {
      thrown = true;
      System.assert(
        ex.getMessage().contains('PersonalLinkToSurvey'),
        'Ska förklara saknad länk'
      );
    }
    Test.stopTest();
    System.assert(thrown, 'Ska kasta när länk saknas');
  }

  @IsTest
  static void backgroundFieldsFromAccount_mapsGraduationYear() {
    Account acct = (Account) JSON.deserialize(
      '{"FirstName":"Anna","LastName":"Andersson","GraduationYear__c":"2018",' +
        '"PersonMobilePhone":"0701234567","PersonContactId":"003xx0000000001AAA",' +
        '"PersonEmail":"anna@example.com","IsManager__c":true}',
      Account.class
    );
    Map<String, String> extras = WebropolSurveyService.backgroundFieldsFromAccount(
      acct
    );
    System.assertEquals('2018', extras.get('examens'));
    System.assertEquals('Anna', extras.get('firstname'));
    System.assertEquals('Andersson', extras.get('lastname'));
    System.assertEquals('0701234567', extras.get('mobile'));
    System.assertEquals('003xx0000000001AAA', extras.get('contactid'));
    System.assertEquals('Ja', extras.get('archef'));
    System.assertEquals('anna@example.com', extras.get('epost'));
    System.assertEquals('0701234567', extras.get('mobil'));
    System.assertEquals('Anna', extras.get('fornamn'));
    System.assertEquals('Andersson', extras.get('efternamn'));
  }

  @IsTest
  static void ensurePersonalLink_createsRecipientWhenMissing() {
    WebropolClient.clearTokenCacheForTest();
    Test.setMock(
      HttpCalloutMock.class,
      new WebropolEnsureLinkCalloutMock(
        '8462',
        'https://link.webropolsurveys.com/R/CREATED'
      )
    );

    Test.startTest();
    WebropolSurveyService.LinkResult result = WebropolSurveyService.ensurePersonalLink(
      'Default',
      '8462',
      'medlem@example.com',
      true
    );
    Test.stopTest();

    System.assertEquals(false, result.success);
    System.assertEquals(true, result.pending, result.message);
    System.assertEquals(true, result.createdRecipient);
    System.assertEquals(
      null,
      result.personalLink,
      'Nyskapad respondent ska inte få länk förrän importen är klar'
    );
  }

  @IsTest
  static void ensurePersonalLinkForAccount_createsWhenMissing() {
    Account person = preparePersonAccount('8462', 'ensure.account@example.com');
    WebropolClient.clearTokenCacheForTest();
    Test.setMock(
      HttpCalloutMock.class,
      new WebropolEnsureLinkCalloutMock(
        '8462',
        'https://link.webropolsurveys.com/R/ACC-CREATE'
      )
    );

    Test.startTest();
    WebropolSurveyService.LinkResult result = WebropolSurveyService.ensurePersonalLinkForAccount(
      person.Id,
      'Default',
      true
    );
    Test.stopTest();

    System.assertEquals(true, result.pending, result.message);
    System.assertEquals(true, result.createdRecipient);
  }

  @IsTest
  static void ensurePersonalLink_skipsCreateWhenDisabled() {
    WebropolClient.clearTokenCacheForTest();
    Test.setMock(
      HttpCalloutMock.class,
      new WebropolHttpCalloutMock(
        200,
        '{"access_token":"t","expires_in":3600}',
        200,
        '[]'
      )
    );

    Test.startTest();
    WebropolSurveyService.LinkResult result = WebropolSurveyService.ensurePersonalLink(
      'Default',
      '8462',
      'medlem@example.com',
      false
    );
    Test.stopTest();

    System.assertEquals(false, result.success);
    System.assertEquals(false, result.createdRecipient);
  }

  @IsTest
  static void getPersonalLinkForAccount_missingMemberNumber() {
    Account person = preparePersonAccount('7001', 'missing.member@example.com');
    person.MemberNumber__c = null;
    update person;

    Test.startTest();
    WebropolSurveyService.LinkResult result = WebropolSurveyService.getPersonalLinkForAccount(
      person.Id,
      'Default'
    );
    Test.stopTest();

    System.assertEquals(false, result.success);
    System.assert(result.message.contains('Medlemsnummer'));
  }

  @IsTest
  static void getPersonalLinkForAccount_missingEmail() {
    Account person = preparePersonAccount('7002', 'has.email@example.com');
    person.PersonEmail = null;
    update person;

    Test.startTest();
    WebropolSurveyService.LinkResult result = WebropolSurveyService.getPersonalLinkForAccount(
      person.Id,
      'Default'
    );
    Test.stopTest();

    System.assertEquals(false, result.success);
    System.assert(result.message.contains('E-post'));
  }

  @IsTest
  static void ensurePersonalLinkForCurrentUser_asMemberUser() {
    TestDataFactory.setupBasicTestData();
    TestDataFactorySetupParams setupParams = new TestDataFactorySetupParams();
    setupParams.numberOfMemberUsers = 1;
    User member = TestDataFactory.createTestMemberUsers(setupParams, true)[0];
    Account person = [
      SELECT Id, MemberNumber__c, PersonEmail
      FROM Account
      WHERE PersonContactId = :member.ContactId
      LIMIT 1
    ];
    person.MemberNumber__c = '8462';
    person.PersonEmail = 'current.user@example.com';
    update person;

    WebropolClient.clearTokenCacheForTest();
    Test.setMock(
      HttpCalloutMock.class,
      WebropolHttpCalloutMock.successDefaults()
    );

    Test.startTest();
    WebropolSurveyService.LinkResult result;
    System.runAs(member) {
      result = WebropolSurveyService.ensurePersonalLinkForCurrentUser(
        'Default',
        true
      );
    }
    Test.stopTest();

    System.assertEquals(true, result.success, result.message);
  }

  @IsTest
  static void getPersonalLinkForCurrentUser_withoutContact_returnsError() {
    Test.startTest();
    WebropolSurveyService.LinkResult result = WebropolSurveyService.getPersonalLinkForCurrentUser(
      'Default'
    );
    Test.stopTest();

    System.assertEquals(false, result.success);
  }

  @IsTest
  static void ensurePersonalLink_addRecipientFailure() {
    WebropolClient.clearTokenCacheForTest();
    Test.setMock(
      HttpCalloutMock.class,
      new WebropolAddRecipientFailCalloutMock()
    );

    Test.startTest();
    WebropolSurveyService.LinkResult result = WebropolSurveyService.ensurePersonalLink(
      'Default',
      '8462',
      'medlem@example.com',
      true
    );
    Test.stopTest();

    System.assertEquals(false, result.success);
    System.assertEquals(false, result.createdRecipient);
    System.assert(result.message.contains('Kunde inte skapa respondent'));
  }

  @IsTest
  static void resolvePersonalLink_recipientsWrapperObject() {
    String json =
      '{"Recipients":[{"PersonalLinkToSurvey":"https://link.webropolsurveys.com/R/WRAP",' +
      '"Fields":[{"FieldName":"1:1:MemberId","FieldValue":"8462"}]}]}';

    Test.startTest();
    String link = WebropolSurveyService.resolvePersonalLink(
      json,
      '8462',
      'MemberId'
    );
    Test.stopTest();

    System.assertEquals('https://link.webropolsurveys.com/R/WRAP', link);
  }

  @IsTest
  static void ensurePersonalLinkForAccount_nullAccountId() {
    Test.startTest();
    WebropolSurveyService.LinkResult result = WebropolSurveyService.ensurePersonalLinkForAccount(
      null,
      'Default',
      true
    );
    Test.stopTest();

    System.assertEquals(false, result.success);
  }

  @IsTest
  static void getPersonalLink_successWithMock() {
    WebropolClient.clearTokenCacheForTest();
    Test.setMock(
      HttpCalloutMock.class,
      WebropolHttpCalloutMock.successDefaults()
    );

    Test.startTest();
    WebropolSurveyService.LinkResult result = WebropolSurveyService.getPersonalLink(
      'Default',
      '8462',
      'medlem@example.com'
    );
    Test.stopTest();

    System.assertEquals(true, result.success, result.message);
    System.assertEquals(
      'https://link.webropolsurveys.com/R/TEST123',
      result.personalLink
    );
  }

  @IsTest
  static void getPersonalLinkForAccount_usesMemberNumberAndEmail() {
    Account person = preparePersonAccount('7001', 'webropol.test@example.com');
    WebropolClient.clearTokenCacheForTest();
    Test.setMock(
      HttpCalloutMock.class,
      new WebropolHttpCalloutMock(
        200,
        '{"access_token":"t","expires_in":3600}',
        200,
        '[{"PersonalLinkToSurvey":"https://link.webropolsurveys.com/R/ACC",' +
          '"Fields":[{"FieldName":"1:1:MemberId","FieldValue":"7001"}]}]'
      )
    );

    Test.startTest();
    WebropolSurveyService.LinkResult result = WebropolSurveyService.getPersonalLinkForAccount(
      person.Id,
      'Default'
    );
    Test.stopTest();

    System.assertEquals(true, result.success, result.message);
    System.assertEquals(
      'https://link.webropolsurveys.com/R/ACC',
      result.personalLink
    );
  }

  @IsTest
  static void invocable_returnsLink() {
    WebropolClient.clearTokenCacheForTest();
    Test.setMock(
      HttpCalloutMock.class,
      WebropolHttpCalloutMock.successDefaults()
    );

    WebropolSurveyInvocable.Request req = new WebropolSurveyInvocable.Request();
    req.settingsDeveloperName = 'Default';
    req.memberId = '8462';
    req.email = 'medlem@example.com';

    Test.startTest();
    List<WebropolSurveyInvocable.Response> responses = WebropolSurveyInvocable.getPersonalLinks(
      new List<WebropolSurveyInvocable.Request>{ req }
    );
    Test.stopTest();

    System.assertEquals(1, responses.size());
    System.assertEquals(true, responses[0].success);
    System.assert(
      String.isNotBlank(responses[0].personalLink),
      'Flow ska få personlig länk'
    );
  }

  @IsTest
  static void invocable_nullRequestsReturnsEmpty() {
    System.assertEquals(
      0,
      WebropolSurveyInvocable.getPersonalLinks(null).size()
    );
  }

  @IsTest
  static void invocable_accountIdReturnsLink() {
    Account person = preparePersonAccount('7001', 'webropol.test@example.com');
    WebropolClient.clearTokenCacheForTest();
    Test.setMock(
      HttpCalloutMock.class,
      new WebropolHttpCalloutMock(
        200,
        '{"access_token":"t","expires_in":3600}',
        200,
        '[{"PersonalLinkToSurvey":"https://link.webropolsurveys.com/R/ACC",' +
          '"Fields":[{"FieldName":"1:1:MemberId","FieldValue":"7001"}]}]'
      )
    );

    WebropolSurveyInvocable.Request req = new WebropolSurveyInvocable.Request();
    req.settingsDeveloperName = 'Default';
    req.accountId = person.Id;

    Test.startTest();
    List<WebropolSurveyInvocable.Response> responses = WebropolSurveyInvocable.getPersonalLinks(
      new List<WebropolSurveyInvocable.Request>{ req }
    );
    Test.stopTest();

    System.assertEquals(true, responses[0].success);
    System.assertEquals(
      'https://link.webropolsurveys.com/R/ACC',
      responses[0].personalLink
    );
    System.assertEquals(null, responses[0].errorMessage);
  }

  @IsTest
  static void invocable_failureReturnsErrorMessage() {
    WebropolSurveyInvocable.Request req = new WebropolSurveyInvocable.Request();
    req.settingsDeveloperName = 'Default';
    req.memberId = '8462';

    Test.startTest();
    List<WebropolSurveyInvocable.Response> responses = WebropolSurveyInvocable.getPersonalLinks(
      new List<WebropolSurveyInvocable.Request>{ req }
    );
    Test.stopTest();

    System.assertEquals(false, responses[0].success);
    System.assertEquals(null, responses[0].personalLink);
    System.assert(
      String.isNotBlank(responses[0].errorMessage),
      'Flow ska få ett felmeddelande'
    );
  }

  private static Account preparePersonAccount(
    String memberNumber,
    String personEmail
  ) {
    TestDataFactory.setupBasicTestData();
    TestDataFactorySetupParams params = new TestDataFactorySetupParams();
    params.numberOfAccounts = 1;
    Account acct = TestDataFactory.createTestAccounts(params, true)[0];
    acct.MemberNumber__c = memberNumber;
    acct.PersonEmail = personEmail;
    update acct;
    return acct;
  }
}