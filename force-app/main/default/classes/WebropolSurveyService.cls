/**
 * Matchar MemberID mot Webropol getByEmail och returnerar personlig enkätlänk.
 */
public with sharing class WebropolSurveyService {
  public class LinkResult {
    @AuraEnabled
    public Boolean success;
    @AuraEnabled
    public String personalLink;
    @AuraEnabled
    public String message;
    @AuraEnabled
    public Boolean createdRecipient;
    @AuraEnabled
    public Boolean pending;
  }

  public class RecipientPendingException extends Exception {
  }

  @TestVisible
  static final String PENDING_MESSAGE = 'Respondenten förbereds i Webropol, försök igen om några sekunder';

  public static LinkResult getPersonalLink(
    String settingsDeveloperName,
    String memberId,
    String email
  ) {
    LinkResult result = new LinkResult();
    result.success = false;
    result.pending = false;
    try {
      WebropolClient.Settings settings = WebropolClient.getSettings(
        settingsDeveloperName
      );
      String responseJson = WebropolClient.getRecipientsByEmailJson(
        settings,
        email
      );
      result.personalLink = resolvePersonalLink(
        responseJson,
        memberId,
        settings.memberIdFieldMatch
      );
      result.success = true;
      result.message = 'OK';
    } catch (RecipientPendingException ex) {
      result.pending = true;
      result.message = PENDING_MESSAGE;
    } catch (Exception ex) {
      result.message = ex.getMessage();
    }
    return result;
  }

  public static LinkResult getPersonalLinkForAccount(
    Id accountId,
    String settingsDeveloperName
  ) {
    if (accountId == null) {
      LinkResult err = new LinkResult();
      err.success = false;
      err.message = 'Account Id saknas';
      return err;
    }

    List<Account> accounts = [
      SELECT
        FirstName,
        LastName,
        MemberNumber__c,
        PersonEmail,
        PersonMobilePhone,
        PersonContactId,
        GraduationYear__c,
        CurrentEmployer__r.Name,
        IsManager__c
      FROM Account
      WHERE Id = :accountId AND IsPersonAccount = TRUE
      LIMIT 1
    ];
    if (accounts.isEmpty()) {
      LinkResult err = new LinkResult();
      err.success = false;
      err.message = 'Personkonto hittades inte';
      return err;
    }

    Account acct = accounts[0];
    if (String.isBlank(acct.MemberNumber__c)) {
      LinkResult err = new LinkResult();
      err.success = false;
      err.message = 'Medlemsnummer (MemberNumber__c) saknas på kontot';
      return err;
    }
    if (String.isBlank(acct.PersonEmail)) {
      LinkResult err = new LinkResult();
      err.success = false;
      err.message = 'E-post (PersonEmail) saknas på kontot';
      return err;
    }

    return getPersonalLink(
      settingsDeveloperName,
      acct.MemberNumber__c,
      acct.PersonEmail
    );
  }

  /**
   * Hämtar personlig länk och skapar respondent i Webropol om den saknas (on-demand).
   */
  public static LinkResult ensurePersonalLink(
    String settingsDeveloperName,
    String memberId,
    String email,
    Boolean createIfMissing
  ) {
    return ensurePersonalLink(
      settingsDeveloperName,
      memberId,
      email,
      createIfMissing,
      null
    );
  }

  public static LinkResult ensurePersonalLink(
    String settingsDeveloperName,
    String memberId,
    String email,
    Boolean createIfMissing,
    Map<String, String> extraFields
  ) {
    LinkResult result = getPersonalLink(
      settingsDeveloperName,
      memberId,
      email
    );
    if (result.success == true || result.pending == true) {
      result.createdRecipient = false;
      return result;
    }
    if (!shouldCreateRecipient(settingsDeveloperName, createIfMissing, result.message)) {
      result.createdRecipient = false;
      return result;
    }

    try {
      WebropolClient.Settings settings = WebropolClient.getSettings(
        settingsDeveloperName
      );
      WebropolClient.importRecipient(settings, email, memberId, extraFields);
      // Webropol kopplar inte svar till respondenten förrän importen är klar
      // (upp emot en minut); en länk som öppnas innan dess ger en okopplad svarsrad.
      LinkResult created = new LinkResult();
      created.success = false;
      created.pending = true;
      created.createdRecipient = true;
      created.message = PENDING_MESSAGE;
      return created;
    } catch (Exception ex) {
      LinkResult err = new LinkResult();
      err.success = false;
      err.createdRecipient = false;
      err.message =
        'Kunde inte skapa respondent i Webropol: ' + ex.getMessage();
      return err;
    }
  }

  public static LinkResult ensurePersonalLinkForAccount(
    Id accountId,
    String settingsDeveloperName,
    Boolean createIfMissing
  ) {
    if (accountId == null) {
      LinkResult err = new LinkResult();
      err.success = false;
      err.message = 'Account Id saknas';
      return err;
    }

    List<Account> accounts = [
      SELECT
        FirstName,
        LastName,
        MemberNumber__c,
        PersonEmail,
        PersonMobilePhone,
        PersonContactId,
        GraduationYear__c,
        CurrentEmployer__r.Name,
        IsManager__c
      FROM Account
      WHERE Id = :accountId AND IsPersonAccount = TRUE
      LIMIT 1
    ];
    if (accounts.isEmpty()) {
      LinkResult err = new LinkResult();
      err.success = false;
      err.message = 'Personkonto hittades inte';
      return err;
    }

    Account acct = accounts[0];
    if (String.isBlank(acct.MemberNumber__c)) {
      LinkResult err = new LinkResult();
      err.success = false;
      err.message = 'Medlemsnummer (MemberNumber__c) saknas på kontot';
      return err;
    }
    if (String.isBlank(acct.PersonEmail)) {
      LinkResult err = new LinkResult();
      err.success = false;
      err.message = 'E-post (PersonEmail) saknas på kontot';
      return err;
    }

    LinkResult result = ensurePersonalLink(
      settingsDeveloperName,
      acct.MemberNumber__c,
      acct.PersonEmail,
      createIfMissing,
      backgroundFieldsFromAccount(acct)
    );
    if (result.success == true) {
      savePersonalLinkToAccount(accountId, result.personalLink, settingsDeveloperName);
    }
    return result;
  }

  public static LinkResult ensurePersonalLinkForCurrentUser(
    String settingsDeveloperName,
    Boolean createIfMissing
  ) {
    List<User> users = [
      SELECT Contact.AccountId
      FROM User
      WHERE Id = :UserInfo.getUserId() AND ContactId != NULL
      LIMIT 1
    ];
    if (users.isEmpty() || users[0].Contact.AccountId == null) {
      LinkResult err = new LinkResult();
      err.success = false;
      err.message = 'Ingen medlemskoppling (Contact/Account) för inloggad användare';
      return err;
    }
    return ensurePersonalLinkForAccount(
      users[0].Contact.AccountId,
      settingsDeveloperName,
      createIfMissing
    );
  }

  @TestVisible
  static Map<String, String> backgroundFieldsFromAccount(Account acct) {
    Map<String, String> extras = new Map<String, String>();
    if (acct == null) {
      return extras;
    }
    if (acct.CurrentEmployer__r != null &&
      String.isNotBlank(acct.CurrentEmployer__r.Name)) {
      extras.put('aktuellarbetsgivare', acct.CurrentEmployer__r.Name);
    }
    if (acct.GraduationYear__c != null &&
      String.isNotBlank(String.valueOf(acct.GraduationYear__c))) {
      extras.put('examens', String.valueOf(acct.GraduationYear__c));
    }
    if (String.isNotBlank(acct.FirstName)) {
      extras.put('firstname', acct.FirstName);
    }
    if (String.isNotBlank(acct.LastName)) {
      extras.put('lastname', acct.LastName);
    }
    if (String.isNotBlank(acct.PersonEmail)) {
      extras.put('epost', acct.PersonEmail);
    }
    if (String.isNotBlank(acct.PersonMobilePhone)) {
      extras.put('mobile', acct.PersonMobilePhone);
      extras.put('mobil', acct.PersonMobilePhone);
    }
    if (String.isNotBlank(acct.FirstName)) {
      extras.put('fornamn', acct.FirstName);
    }
    if (String.isNotBlank(acct.LastName)) {
      extras.put('efternamn', acct.LastName);
    }
    if (String.isNotBlank(acct.PersonContactId)) {
      extras.put('contactid', String.valueOf(acct.PersonContactId));
    }
    if (acct.Id != null) {
      extras.put('accountid', String.valueOf(acct.Id));
    }
    if (acct.IsManager__c == true) {
      extras.put('archef', 'Ja');
    } else if (acct.IsManager__c == false) {
      extras.put('archef', 'Nej');
    }
    return extras;
  }

  @TestVisible
  private static Boolean shouldCreateRecipient(
    String settingsDeveloperName,
    Boolean createIfMissing,
    String errorMessage
  ) {
    if (createIfMissing == false) {
      return false;
    }
    WebropolClient.Settings settings = WebropolClient.getSettings(
      settingsDeveloperName
    );
    if (settings.autoCreateRecipient != true) {
      return false;
    }
    if (String.isBlank(errorMessage)) {
      return false;
    }
    String msg = errorMessage.toLowerCase();
    return msg.contains('ingen webropol-respondent') ||
      msg.contains('getbyemail misslyckades');
  }

  @TestVisible
  private static void savePersonalLinkToAccount(
    Id accountId,
    String personalLink,
    String settingsDeveloperName
  ) {
    if (accountId == null || String.isBlank(personalLink)) {
      return;
    }
    WebropolClient.Settings settings = WebropolClient.getSettings(
      settingsDeveloperName
    );
    if (
      settings.savePersonalLinkToAccount != true ||
      String.isBlank(settings.accountPersonalLinkFieldApiName)
    ) {
      return;
    }

    Schema.SObjectField field = Account.SObjectType.getDescribe()
      .fields.getMap()
      .get(settings.accountPersonalLinkFieldApiName.toLowerCase());
    if (field == null) {
      throw new WebropolException(
        'Account-fält saknas: ' + settings.accountPersonalLinkFieldApiName
      );
    }

    Account acct = new Account(Id = accountId);
    acct.put(settings.accountPersonalLinkFieldApiName, personalLink);
    update acct;
  }

  public static LinkResult getPersonalLinkForCurrentUser(
    String settingsDeveloperName
  ) {
    List<User> users = [
      SELECT Contact.AccountId
      FROM User
      WHERE Id = :UserInfo.getUserId() AND ContactId != NULL
      LIMIT 1
    ];
    if (users.isEmpty() || users[0].Contact.AccountId == null) {
      LinkResult err = new LinkResult();
      err.success = false;
      err.message = 'Ingen medlemskoppling (Contact/Account) för inloggad användare';
      return err;
    }
    return getPersonalLinkForAccount(
      users[0].Contact.AccountId,
      settingsDeveloperName
    );
  }

  /**
   * Parsar getByEmail-JSON och returnerar PersonalLinkToSurvey för matchande MemberID.
   */
  public static String resolvePersonalLink(
    String responseJson,
    String memberId,
    String memberIdFieldMatch
  ) {
    String wanted = String.valueOf(memberId).trim();
    if (String.isBlank(wanted)) {
      throw new WebropolException('MemberID krävs');
    }
    String matchFragment = String.isNotBlank(memberIdFieldMatch)
      ? memberIdFieldMatch.trim().toLowerCase()
      : 'memberid';

    Object parsed = JSON.deserializeUntyped(responseJson);
    List<Object> recipients = normalizeRecipients(parsed);

    for (Object recipientObj : recipients) {
      Map<String, Object> recipient = (Map<String, Object>) recipientObj;
      if (!recipientMatchesMemberId(recipient, wanted, matchFragment)) {
        continue;
      }
      String link = readPersonalLink(recipient);
      if (String.isBlank(link)) {
        throw new WebropolException(
          'MemberID ' +
            wanted +
            ' matchade men PersonalLinkToSurvey saknas'
        );
      }
      return link;
    }

    // getByEmail kan returnera en respondent utan MemberId i svaret (e-post redan filtrerad)
    if (recipients.size() == 1) {
      Map<String, Object> only = (Map<String, Object>) recipients[0];
      if (
        !recipientHasMemberIdFields(only, matchFragment) &&
        String.isNotBlank(readPersonalLink(only))
      ) {
        // Saknas all bakgrundsdata är importen inte klar än. Respondenter som
        // läggs in helt utan bakgrundsdata blir därför aldrig klara.
        if (!hasRespondentAnswers(only)) {
          throw new RecipientPendingException(PENDING_MESSAGE);
        }
        return readPersonalLink(only);
      }
    }

    throw new WebropolException(
      'Ingen Webropol-respondent med MemberID ' + wanted
    );
  }

  @TestVisible
  private static List<Object> normalizeRecipients(Object parsed) {
    if (parsed instanceof List<Object>) {
      return (List<Object>) parsed;
    }
    if (!(parsed instanceof Map<String, Object>)) {
      return new List<Object>();
    }
    Map<String, Object> root = (Map<String, Object>) parsed;
    for (String key : new List<String>{
      'Recipients',
      'recipients',
      'Data',
      'data',
      'Items',
      'items'
    }) {
      Object value = root.get(key);
      if (value instanceof List<Object>) {
        return (List<Object>) value;
      }
    }
    if (isRecipientObject(root)) {
      return new List<Object>{ root };
    }
    return new List<Object>();
  }

  @TestVisible
  private static Boolean isRecipientObject(Map<String, Object> root) {
    return root.containsKey('RecipientId') ||
      root.containsKey('recipientId') ||
      root.containsKey('PersonalLinkToSurvey') ||
      root.containsKey('personalLinkToSurvey') ||
      root.containsKey('Email');
  }

  private static Boolean recipientMatchesMemberId(
    Map<String, Object> recipient,
    String wanted,
    String matchFragment
  ) {
    if (directMemberIdMatches(recipient, wanted, matchFragment)) {
      return true;
    }
    if (respondentAnswerMatches(recipient, wanted, matchFragment)) {
      return true;
    }
    for (Object fieldObj : extractAllFieldEntries(recipient)) {
      Map<String, Object> field = (Map<String, Object>) fieldObj;
      String fieldName = stringValue(field, 'FieldName', 'fieldName');
      if (String.isBlank(fieldName)) {
        fieldName = stringValue(field, 'Name', 'name');
      }
      if (String.isBlank(fieldName) ||
        !fieldName.toLowerCase().contains(matchFragment)) {
        continue;
      }
      String fieldValue = readFieldValue(field);
      if (wanted == String.valueOf(fieldValue).trim()) {
        return true;
      }
    }
    return false;
  }

  private static Boolean recipientHasMemberIdFields(
    Map<String, Object> recipient,
    String matchFragment
  ) {
    if (directMemberIdMatches(recipient, null, matchFragment)) {
      return true;
    }
    if (respondentAnswerMatches(recipient, null, matchFragment)) {
      return true;
    }
    for (Object fieldObj : extractAllFieldEntries(recipient)) {
      Map<String, Object> field = (Map<String, Object>) fieldObj;
      String fieldName = stringValue(field, 'FieldName', 'fieldName');
      if (String.isBlank(fieldName)) {
        fieldName = stringValue(field, 'Name', 'name');
      }
      if (
        String.isNotBlank(fieldName) &&
        fieldName.toLowerCase().contains(matchFragment)
      ) {
        return true;
      }
    }
    return false;
  }

  private static Boolean hasRespondentAnswers(Map<String, Object> recipient) {
    for (String key : new List<String>{
      'RespondentAnswers',
      'respondentAnswers'
    }) {
      Object raw = recipient.get(key);
      if (raw instanceof List<Object> && !((List<Object>) raw).isEmpty()) {
        return true;
      }
    }
    return false;
  }

  private static Boolean respondentAnswerMatches(
    Map<String, Object> recipient,
    String wanted,
    String matchFragment
  ) {
    for (String key : new List<String>{
      'RespondentAnswers',
      'respondentAnswers'
    }) {
      Object raw = recipient.get(key);
      if (!(raw instanceof List<Object>)) {
        continue;
      }
      for (Object answerObj : (List<Object>) raw) {
        if (!(answerObj instanceof Map<String, Object>)) {
          continue;
        }
        Map<String, Object> answer = (Map<String, Object>) answerObj;
        String title = stringValue(answer, 'QuestionTitle', 'questionTitle');
        if (String.isBlank(title) || !title.toLowerCase().contains(matchFragment)) {
          continue;
        }
        if (wanted == null) {
          return true;
        }
        Object questionAnswers = answer.get('QuestionAnswers');
        if (questionAnswers == null) {
          questionAnswers = answer.get('questionAnswers');
        }
        if (!(questionAnswers instanceof List<Object>)) {
          continue;
        }
        for (Object optionObj : (List<Object>) questionAnswers) {
          if (!(optionObj instanceof Map<String, Object>)) {
            continue;
          }
          Map<String, Object> option = (Map<String, Object>) optionObj;
          String optionAnswer = stringValue(option, 'OptionAnswer', 'optionAnswer');
          if (wanted == String.valueOf(optionAnswer).trim()) {
            return true;
          }
        }
      }
    }
    return false;
  }

  private static Boolean directMemberIdMatches(
    Map<String, Object> recipient,
    String wanted,
    String matchFragment
  ) {
    for (String key : recipient.keySet()) {
      if (!key.toLowerCase().contains(matchFragment)) {
        continue;
      }
      if (wanted == null) {
        return true;
      }
      Object value = recipient.get(key);
      if (wanted == String.valueOf(value).trim()) {
        return true;
      }
    }
    return false;
  }

  private static List<Object> extractAllFieldEntries(
    Map<String, Object> recipient
  ) {
    List<Object> entries = new List<Object>();
    for (String key : new List<String>{
      'Fields',
      'fields',
      'RespondentFields',
      'respondentFields',
      'Answers',
      'answers',
      'DemData',
      'demData',
      'RespondentAnswers',
      'respondentAnswers'
    }) {
      entries.addAll(coerceToFieldEntryList(recipient.get(key)));
    }
    return entries;
  }

  private static List<Object> coerceToFieldEntryList(Object value) {
    List<Object> entries = new List<Object>();
    if (value instanceof List<Object>) {
      return (List<Object>) value;
    }
    if (!(value instanceof Map<String, Object>)) {
      return entries;
    }
    Map<String, Object> mapValue = (Map<String, Object>) value;
    if (mapValue.containsKey('FieldName') || mapValue.containsKey('fieldName')) {
      entries.add(mapValue);
      return entries;
    }
    for (String key : mapValue.keySet()) {
      entries.add(
        new Map<String, Object>{
          'FieldName' => key,
          'FieldValue' => mapValue.get(key)
        }
      );
    }
    return entries;
  }

  private static String readFieldValue(Map<String, Object> field) {
    String value = stringValue(field, 'FieldValue', 'fieldValue');
    if (String.isNotBlank(value)) {
      return value;
    }
    return stringValue(field, 'Value', 'value');
  }

  private static String readPersonalLink(Map<String, Object> recipient) {
    return stringValue(
      recipient,
      'PersonalLinkToSurvey',
      'personalLinkToSurvey'
    );
  }

  private static String stringValue(
    Map<String, Object> row,
    String primaryKey,
    String alternateKey
  ) {
    Object value = row.containsKey(primaryKey)
      ? row.get(primaryKey)
      : row.get(alternateKey);
    return value == null ? null : String.valueOf(value).trim();
  }
}