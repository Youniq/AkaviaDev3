@IsTest
private class WebropolClientTest {
  @IsTest
  static void getAccessToken_cachesUntilExpiry() {
    WebropolClient.clearTokenCacheForTest();
    Test.setMock(
      HttpCalloutMock.class,
      WebropolHttpCalloutMock.successDefaults()
    );
    WebropolClient.Settings settings = WebropolClient.getSettings('Default');

    Test.startTest();
    String token1 = WebropolClient.getAccessToken(settings);
    String token2 = WebropolClient.getAccessToken(settings);
    Test.stopTest();

    System.assertEquals('test-token', token1);
    System.assertEquals(token1, token2, 'Token ska cachas inom samma transaktion');
  }

  @IsTest
  static void getAccessToken_usesNamedCredentialWhenEnabled() {
    WebropolClient.clearTokenCacheForTest();
    Test.setMock(
      HttpCalloutMock.class,
      WebropolHttpCalloutMock.successDefaults()
    );
    WebropolClient.Settings settings = WebropolClient.getSettings('Default');
    settings.useNamedCredential = true;
    settings.namedCredentialName = 'Webropol_API';

    Test.startTest();
    String token = WebropolClient.getAccessToken(settings);
    Test.stopTest();

    System.assertEquals('test-token', token);
  }

  @IsTest
  static void fillDemDataTemplate_setsEmailAndMemberId() {
    Blob filled = WebropolClient.fillDemDataTemplate(
      WebropolHttpCalloutMock.demDataTemplateXlsx(),
      'ny.medlem@example.com',
      '9999912'
    );
    Compression.ZipReader reader = new Compression.ZipReader(filled);
    String sst = reader.extract(reader.getEntry('xl/sharedStrings.xml'))
      .toString();
    String sheet = reader.extract(reader.getEntry('xl/worksheets/sheet1.xml'))
      .toString();
    System.assert(
      sst.contains('ny.medlem@example.com'),
      'E-post ska ligga i sharedStrings'
    );
    System.assert(
      sst.contains('9999912'),
      'MemberId ska ligga i sharedStrings'
    );
    System.assert(sheet.contains('r="A3"'), 'Ny respondent ska ligga på rad 3 efter mallens platshållare');
    System.assert(sheet.contains('r="E3"'), 'MemberId ska ligga på rad 3');
    System.assert(!sheet.contains('r="4"'), 'Befintliga exportrader ska inte återimporteras');
  }

  @IsTest
  static void fillDemDataTemplate_setsBackgroundColumns() {
    Blob filled = WebropolClient.fillDemDataTemplate(
      WebropolHttpCalloutMock.demDataTemplateXlsx(),
      'ny.medlem@example.com',
      '9999912',
      new Map<String, String>{
        'aktuellarbetsgivare' => 'Testbolaget AB',
        'examens' => '2019',
        'firstname' => 'Anna',
        'lastname' => 'Andersson',
        'mobile' => '0701234567',
        'contactid' => '003xx0000000001AAA',
        'accountid' => '001xx0000000001AAA',
        'archef' => 'Ja',
        'epost' => 'ny.medlem@example.com',
        'mobil' => '0701234567',
        'fornamn' => 'Anna',
        'efternamn' => 'Andersson'
      }
    );
    Compression.ZipReader reader = new Compression.ZipReader(filled);
    String sst = reader.extract(reader.getEntry('xl/sharedStrings.xml'))
      .toString();
    String sheet = reader.extract(reader.getEntry('xl/worksheets/sheet1.xml'))
      .toString();
    System.assert(sst.contains('Testbolaget AB'), 'Arbetsgivare ska med');
    System.assert(sst.contains('2019'), 'Examensår ska med');
    System.assert(sst.contains('Anna'), 'Förnamn ska med');
    System.assert(sst.contains('Andersson'), 'Efternamn ska med');
    System.assert(sst.contains('0701234567'), 'Mobil ska med');
    System.assert(sst.contains('003xx0000000001AAA'), 'ContactId ska med');
    System.assert(sst.contains('001xx0000000001AAA'), 'AccountId ska med');
    System.assert(sst.contains('Ja'), 'ArChef ska med');
    System.assert(sheet.contains('r="B3"'), 'Mobile på kolumn B');
    System.assert(sheet.contains('r="C3"'), 'FirstName på kolumn C');
    System.assert(sheet.contains('r="D3"'), 'LastName på kolumn D');
    System.assert(sheet.contains('r="G3"'), 'AktuellArbetsgivare på kolumn G');
    System.assert(sheet.contains('r="H3"'), 'Examensår på kolumn H');
    System.assert(sheet.contains('r="I3"'), 'ContactId på kolumn I');
    System.assert(sheet.contains('r="J3"'), 'AccountId på kolumn J');
    System.assert(sheet.contains('r="K3"'), 'ArChef på kolumn K');
    System.assert(sheet.contains('r="L3"'), 'Epost på kolumn L');
    System.assert(sheet.contains('r="M3"'), 'Mobil på kolumn M');
    System.assert(sheet.contains('r="N3"'), 'Fornamn på kolumn N');
    System.assert(sheet.contains('r="O3"'), 'Efternamn på kolumn O');
  }

  @IsTest
  static void addRecipient_postsRecipientsEndpoint() {
    WebropolClient.clearTokenCacheForTest();
    Test.setMock(
      HttpCalloutMock.class,
      WebropolHttpCalloutMock.successDefaults()
    );
    WebropolClient.Settings settings = WebropolClient.getSettings('Default');

    Test.startTest();
    String link = WebropolClient.addRecipient(
      settings,
      'medlem@example.com',
      '8462',
      'MemberId'
    );
    Test.stopTest();

    System.assertEquals(
      'https://link.webropolsurveys.com/R/TEST123',
      link,
      'Add recipient ska returnera personlig länk från GET recipient'
    );
  }

  @IsTest
  static void importRecipient_returnsRecipientIdWithoutPolling() {
    WebropolClient.clearTokenCacheForTest();
    Test.setMock(
      HttpCalloutMock.class,
      WebropolHttpCalloutMock.successDefaults()
    );
    WebropolClient.Settings settings = WebropolClient.getSettings('Default');

    Test.startTest();
    String recipientId = WebropolClient.importRecipient(
      settings,
      'medlem@example.com',
      '8462',
      null
    );
    Integer callouts = Limits.getCallouts();
    Test.stopTest();

    System.assertEquals('new-recipient-id', recipientId);
    System.assert(callouts <= 3, 'Token, export och import – ingen polling');
  }

  @IsTest
  static void getRecipientsByEmailJson_returnsBody() {
    WebropolClient.clearTokenCacheForTest();
    Test.setMock(
      HttpCalloutMock.class,
      WebropolHttpCalloutMock.successDefaults()
    );
    WebropolClient.Settings settings = WebropolClient.getSettings('Default');

    Test.startTest();
    String body = WebropolClient.getRecipientsByEmailJson(
      settings,
      'medlem@example.com'
    );
    Test.stopTest();

    System.assert(body.contains('PersonalLinkToSurvey'), 'Ska returnera JSON-body');
  }

  @IsTest
  static void getRecipientsByEmailJson_throwsOnApiError() {
    WebropolClient.clearTokenCacheForTest();
    Test.setMock(
      HttpCalloutMock.class,
      new WebropolHttpCalloutMock(
        200,
        '{"access_token":"test-token","expires_in":3600}',
        500,
        'Server error'
      )
    );
    WebropolClient.Settings settings = WebropolClient.getSettings('Default');
    Boolean thrown = false;

    Test.startTest();
    try {
      WebropolClient.getRecipientsByEmailJson(settings, 'medlem@example.com');
    } catch (WebropolException ex) {
      thrown = true;
      System.assert(ex.getMessage().contains('500'));
    }
    Test.stopTest();

    System.assert(thrown, 'Ska kasta vid API-fel');
  }

  @IsTest
  static void parseRecipientsAdded_readsIdsAndRejectsFailure() {
    List<String> ids = WebropolClient.parseRecipientsAdded(
      '{"RecipientsAdded":["aaa","bbb"],"IsFailed":false}'
    );
    System.assertEquals(2, ids.size());
    System.assertEquals('aaa', ids[0]);

    Boolean thrown = false;
    try {
      WebropolClient.parseRecipientsAdded('{"RecipientsAdded":[],"IsFailed":true}');
    } catch (WebropolException ex) {
      thrown = true;
      System.assert(ex.getMessage().contains('importRecipientWithDemData'));
    }
    System.assert(thrown, 'Ska kasta när IsFailed=true');
  }

  @IsTest
  static void personalLinkAfterImport_pollsUntilLinkExists() {
    WebropolClient.clearTokenCacheForTest();
    WebropolClient.recipientPollAttempts = 3;
    WebropolClient.recipientPollCpuWaitMs = 0;
    Test.setMock(
      HttpCalloutMock.class,
      new WebropolRecipientPollCalloutMock()
    );
    WebropolClient.Settings settings = WebropolClient.getSettings('Default');

    Test.startTest();
    String link = WebropolClient.personalLinkAfterImport(
      settings,
      '{"RecipientsAdded":["new-recipient-id"],"IsFailed":false}'
    );
    Test.stopTest();

    System.assertEquals(
      'https://link.webropolsurveys.com/R/POLLED',
      link
    );
  }

  @IsTest
  static void firstPersonalLink_readsArrayAndObject() {
    System.assertEquals(
      'https://link.webropolsurveys.com/R/ONE',
      WebropolClient.firstPersonalLink(
        '[{"PersonalLinkToSurvey":"https://link.webropolsurveys.com/R/ONE"}]'
      )
    );
    System.assertEquals(
      'https://link.webropolsurveys.com/R/TWO',
      WebropolClient.firstPersonalLink(
        '{"personalLinkToSurvey":"https://link.webropolsurveys.com/R/TWO"}'
      )
    );
    System.assertEquals(null, WebropolClient.firstPersonalLink('[]'));
  }

  @IsTest
  static void getAccessToken_withoutNamedCredential_usesManualCredentials() {
    WebropolClient.clearTokenCacheForTest();
    Test.setMock(
      HttpCalloutMock.class,
      WebropolHttpCalloutMock.successDefaults()
    );
    WebropolClient.Settings settings = WebropolClient.getSettings('Default');
    settings.useNamedCredential = false;
    settings.username = 'api-user';
    settings.password = 'api-pass';

    Test.startTest();
    String token = WebropolClient.getAccessToken(settings);
    Test.stopTest();

    System.assertEquals('test-token', token);
  }
}