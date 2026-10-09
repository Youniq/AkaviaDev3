/**
 * HTTP-klient mot Webropol REST API (token + recipients/getByEmail).
 */
public with sharing class WebropolClient {
  private static final String DEFAULT_TOKEN_URL = 'https://rest.webropolsurveys.com/token';
  private static final String DEFAULT_API_BASE_URL = 'https://rest.webropolsurveys.com/api/v1';
  private static final String DEFAULT_NAMED_CREDENTIAL = 'Webropol_API';
  private static final String DEFAULT_EXTERNAL_CREDENTIAL = 'Webropol_Ext_Cred';
  private static final String TOKEN_BODY_NAMED_CREDENTIAL =
    'grant_type=password' +
    '&username={!$Credential.' +
    DEFAULT_EXTERNAL_CREDENTIAL +
    '.username}' +
    '&password={!$Credential.' +
    DEFAULT_EXTERNAL_CREDENTIAL +
    '.password}';
  private static final Integer TOKEN_EXPIRY_BUFFER_SEC = 120;
  @TestVisible
  static Integer recipientPollAttempts = 90;
  @TestVisible
  static Integer recipientPollCpuWaitMs = 700;

  @TestVisible
  private static String cachedToken;

  @TestVisible
  private static Long tokenExpiresAtEpochMs;

  public class Settings {
    public String username;
    public String password;
    public String surveyId;
    public String tokenUrl;
    public String apiBaseUrl;
    public String memberIdFieldMatch;
    public Boolean useNamedCredential;
    public String namedCredentialName;
    public Boolean autoCreateRecipient;
    public Boolean savePersonalLinkToAccount;
    public String accountPersonalLinkFieldApiName;
  }

  public class TokenResponse {
    public String access_token;
    public String token_type;
    public Integer expires_in;
    public String error;
    public String error_description;
  }

  public static Settings getSettings(String developerName) {
    String key = String.isBlank(developerName) ? 'Default' : developerName.trim();
    List<Webropol_Settings__mdt> rows = [
      SELECT
        Username__c,
        Password__c,
        SurveyId__c,
        TokenUrl__c,
        ApiBaseUrl__c,
        MemberIdFieldMatch__c,
        IsActive__c,
        UseNamedCredential__c,
        NamedCredential__c,
        AutoCreateRecipient__c,
        SavePersonalLinkToAccount__c,
        AccountPersonalLinkFieldApiName__c
      FROM Webropol_Settings__mdt
      WHERE DeveloperName = :key
      LIMIT 1
    ];
    if (rows.isEmpty()) {
      throw new WebropolException(
        'Webropol_Settings__mdt saknas: ' + key
      );
    }
    Webropol_Settings__mdt row = rows[0];
    if (row.IsActive__c == false) {
      throw new WebropolException(
        'Webropol-inställningen är inaktiv: ' + key
      );
    }

    Settings settings = new Settings();
    settings.username = row.Username__c;
    settings.password = row.Password__c;
    settings.surveyId = row.SurveyId__c;
    settings.tokenUrl = String.isNotBlank(row.TokenUrl__c)
      ? row.TokenUrl__c
      : DEFAULT_TOKEN_URL;
    settings.apiBaseUrl = String.isNotBlank(row.ApiBaseUrl__c)
      ? row.ApiBaseUrl__c
      : DEFAULT_API_BASE_URL;
    settings.memberIdFieldMatch = String.isNotBlank(row.MemberIdFieldMatch__c)
      ? row.MemberIdFieldMatch__c
      : 'MemberId';
    settings.useNamedCredential = row.UseNamedCredential__c != false;
    settings.namedCredentialName = String.isNotBlank(row.NamedCredential__c)
      ? row.NamedCredential__c.trim()
      : DEFAULT_NAMED_CREDENTIAL;
    settings.autoCreateRecipient = row.AutoCreateRecipient__c != false;
    settings.savePersonalLinkToAccount = row.SavePersonalLinkToAccount__c == true;
    settings.accountPersonalLinkFieldApiName = row.AccountPersonalLinkFieldApiName__c;

    if (String.isBlank(settings.surveyId)) {
      throw new WebropolException(
        'SurveyId saknas i Webropol_Settings__mdt: ' + key
      );
    }
    if (
      settings.useNamedCredential != true &&
      (String.isBlank(settings.username) || String.isBlank(settings.password))
    ) {
      throw new WebropolException(
        'Username, Password eller SurveyId saknas i Webropol_Settings__mdt: ' +
        key
      );
    }
    return settings;
  }

  @TestVisible
  private static void clearTokenCacheForTest() {
    cachedToken = null;
    tokenExpiresAtEpochMs = null;
  }

  public static String getAccessToken(Settings settings) {
    if (
      cachedToken != null &&
      tokenExpiresAtEpochMs != null &&
      System.currentTimeMillis() < tokenExpiresAtEpochMs
    ) {
      return cachedToken;
    }

    HttpRequest req = new HttpRequest();
    req.setMethod(GlobalConstants.HTTP_METHOD_POST);
    req.setHeader(
      GlobalConstants.HTTP_HEADER_FIELD_NAME_CONTENT_TYPE,
      GlobalConstants.HTTP_HEADER_FIELD_CONTENT_TYPE_VALUE_APPLICATION_URLENCODED
    );
    req.setTimeout(120000);

    if (settings.useNamedCredential == true) {
      req.setEndpoint(
        'callout:' + settings.namedCredentialName + '/token'
      );
      req.setBody(TOKEN_BODY_NAMED_CREDENTIAL);
    } else {
      req.setEndpoint(settings.tokenUrl);
      req.setBody(
        'grant_type=password' +
          '&username=' +
          EncodingUtil.urlEncode(
            settings.username,
            GlobalConstants.URL_ENCODING_SCHEME_DEFAULT
          ) +
          '&password=' +
          EncodingUtil.urlEncode(
            settings.password,
            GlobalConstants.URL_ENCODING_SCHEME_DEFAULT
          )
      );
    }

    HttpResponse res = new Http().send(req);
    if (res.getStatusCode() != GlobalConstants.HTTP_RESPONSE_CODE_SUCCESS) {
      throw new WebropolException(
        'Webropol token misslyckades (' +
          res.getStatusCode() +
          '): ' +
          res.getBody()
      );
    }

    TokenResponse token = (TokenResponse) JSON.deserialize(
      res.getBody(),
      TokenResponse.class
    );
    if (String.isBlank(token.access_token)) {
      throw new WebropolException('Webropol token saknas i svar');
    }

    Integer expiresIn = token.expires_in != null ? token.expires_in : 3600;
    cachedToken = token.access_token;
    tokenExpiresAtEpochMs =
      System.currentTimeMillis() +
      ((expiresIn - TOKEN_EXPIRY_BUFFER_SEC) * 1000L);
    return cachedToken;
  }

  public static String getRecipientsByEmailJson(
    Settings settings,
    String email
  ) {
    if (String.isBlank(email)) {
      throw new WebropolException('E-postadress krävs');
    }

    return sendBearerJson(
      settings,
      buildSurveyPath(settings, '/recipients/getByEmail'),
      new Map<String, Object>{ 'Email' => email.trim() }
    );
  }

  /**
   * Skapar respondent med e-post + MemberId via Webropols DemData-import.
   * Mallen måste hämtas från ExportDemDataFile (UI-mall ger 400 Invalid file format).
   * Returnerar PersonalLinkToSurvey från GET /recipients/{id} (getByEmail är tom direkt efter import).
   */
  public static String addRecipient(
    Settings settings,
    String email,
    String memberId,
    String memberIdFieldName
  ) {
    return addRecipient(settings, email, memberId, memberIdFieldName, null);
  }

  public static String addRecipient(
    Settings settings,
    String email,
    String memberId,
    String memberIdFieldName,
    Map<String, String> extraFields
  ) {
    String importBody = importRecipientBody(settings, email, memberId, extraFields);
    return personalLinkAfterImport(settings, importBody);
  }

  /**
   * Som addRecipient men väntar inte på personlig länk. Returnerar RecipientId.
   */
  public static String importRecipient(
    Settings settings,
    String email,
    String memberId,
    Map<String, String> extraFields
  ) {
    String importBody = importRecipientBody(settings, email, memberId, extraFields);
    List<String> recipientIds = parseRecipientsAdded(importBody);
    if (recipientIds.isEmpty()) {
      throw new WebropolException(
        'Webropol import returnerade inga RecipientsAdded: ' + importBody
      );
    }
    return recipientIds[0];
  }

  private static String importRecipientBody(
    Settings settings,
    String email,
    String memberId,
    Map<String, String> extraFields
  ) {
    if (String.isBlank(email)) {
      throw new WebropolException('E-postadress krävs');
    }
    if (String.isBlank(memberId)) {
      throw new WebropolException('MemberID krävs');
    }

    Blob template = exportDemDataFile(settings);
    Blob filled = fillDemDataTemplate(
      template,
      email.trim(),
      String.valueOf(memberId).trim(),
      extraFields
    );
    return importRecipientWithDemData(settings, filled);
  }

  public static String getRecipientByIdJson(
    Settings settings,
    String recipientId
  ) {
    if (String.isBlank(recipientId)) {
      throw new WebropolException('RecipientId krävs');
    }
    HttpResponse res = sendBearer(
      settings,
      buildSurveyPath(settings, '/recipients/' + recipientId.trim()),
      'GET',
      null,
      null
    );
    if (res.getStatusCode() != GlobalConstants.HTTP_RESPONSE_CODE_SUCCESS) {
      throw new WebropolException(
        'Webropol GET recipient misslyckades (' +
          res.getStatusCode() +
          '): ' +
          res.getBody()
      );
    }
    return res.getBody();
  }

  @TestVisible
  public static Blob exportDemDataFile(Settings settings) {
    HttpResponse res = sendBearer(
      settings,
      buildSurveyPath(settings, '/ExportDemDataFile'),
      'GET',
      null,
      null
    );
    if (res.getStatusCode() != GlobalConstants.HTTP_RESPONSE_CODE_SUCCESS) {
      throw new WebropolException(
        'Webropol ExportDemDataFile misslyckades (' +
          res.getStatusCode() +
          '): ' +
          res.getBody()
      );
    }
    Blob fileBody = res.getBodyAsBlob();
    if (fileBody == null || fileBody.size() == 0) {
      throw new WebropolException('Webropol ExportDemDataFile returnerade tom fil');
    }
    return fileBody;
  }

  @TestVisible
  public static Blob fillDemDataTemplate(
    Blob templateXlsx,
    String email,
    String memberId
  ) {
    return fillDemDataTemplate(templateXlsx, email, memberId, null);
  }

  public static Blob fillDemDataTemplate(
    Blob templateXlsx,
    String email,
    String memberId,
    Map<String, String> extraFields
  ) {
    Compression.ZipReader reader = new Compression.ZipReader(templateXlsx);
    Compression.ZipEntry sheetEntry = reader.getEntry('xl/worksheets/sheet1.xml');
    Compression.ZipEntry sstEntry = reader.getEntry('xl/sharedStrings.xml');
    if (sheetEntry == null || sstEntry == null) {
      throw new WebropolException(
        'ExportDemDataFile saknar sheet1.xml eller sharedStrings.xml'
      );
    }

    String sheetXml = keepTemplateRowsOnly(reader.extract(sheetEntry).toString());
    String sstXml = reader.extract(sstEntry).toString();
    Map<String, String> valuesByFragment = extraFields == null
      ? new Map<String, String>()
      : extraFields.clone();
    valuesByFragment.put('email', email);
    valuesByFragment.put('memberid', memberId);
    List<String> sharedStrings = parseSharedStrings(sstXml);
    Map<String, String> colToHeader = parseHeaderColumns(sheetXml, sharedStrings);
    Map<String, Integer> colToIndex = new Map<String, Integer>();
    for (String fragment : valuesByFragment.keySet()) {
      String value = valuesByFragment.get(fragment);
      if (String.isBlank(value)) {
        continue;
      }
      String col = columnForHeader(colToHeader, fragment);
      if (String.isBlank(col)) {
        continue;
      }
      Integer stringIndex = countSharedStringItems(sstXml);
      sstXml = appendSharedString(sstXml, value.trim());
      colToIndex.put(col, stringIndex);
    }
    sheetXml = insertRecipientRow(sheetXml, colToIndex);

    Compression.ZipWriter writer = new Compression.ZipWriter();
    for (Compression.ZipEntry entry : reader.getEntries()) {
      String name = entry.getName();
      if (String.isBlank(name) || name.endsWith('/')) {
        continue;
      }
      Blob data;
      if (name == 'xl/worksheets/sheet1.xml') {
        data = Blob.valueOf(sheetXml);
      } else if (name == 'xl/sharedStrings.xml') {
        data = Blob.valueOf(sstXml);
      } else {
        data = reader.extract(entry);
      }
      writer.addEntry(name, data);
    }
    return writer.getArchive();
  }

  /**
   * Exporten innehåller redan importerade respondenter. Behåll bara header (rad 1)
   * och mallens platshållarrad (rad 2); Webropol hoppar över rad 2. Ny respondent
   * skrivs som rad 3. Annars återimporteras alla rader som dubbletter.
   */
  @TestVisible
  static String keepTemplateRowsOnly(String sheetXml) {
    Integer dataStart = sheetXml.indexOf('<sheetData');
    Integer dataOpenEnd = sheetXml.indexOf('>', dataStart);
    Integer dataClose = sheetXml.indexOf('</sheetData>');
    if (dataStart < 0 || dataOpenEnd < 0 || dataClose < 0) {
      throw new WebropolException('ExportDemDataFile saknar sheetData');
    }
    String sheetDataInner = sheetXml.substring(dataOpenEnd + 1, dataClose);
    String headerRow = extractSheetRow(sheetDataInner, '1');
    if (String.isBlank(headerRow)) {
      throw new WebropolException('ExportDemDataFile saknar header-rad');
    }
    String placeholderRow = extractSheetRow(sheetDataInner, '2');
    String keptRows = headerRow + (placeholderRow == null ? '' : placeholderRow);
    return sheetXml.substring(0, dataOpenEnd + 1) +
      keptRows +
      sheetXml.substring(dataClose);
  }

  @TestVisible
  static String extractSheetRow(String sheetXml, String rowNum) {
    String startToken = '<row r="' + rowNum + '"';
    Integer start = sheetXml.indexOf(startToken);
    if (start < 0) {
      return null;
    }
    Integer gt = sheetXml.indexOf('>', start);
    if (gt < 0) {
      return null;
    }
    if (sheetXml.substring(gt - 1, gt) == '/') {
      return sheetXml.substring(start, gt + 1);
    }
    Integer close = sheetXml.indexOf('</row>', gt);
    if (close < 0) {
      return null;
    }
    return sheetXml.substring(start, close + 6);
  }

  @TestVisible
  static List<String> parseSharedStrings(String sstXml) {
    List<String> items = new List<String>();
    Integer fromIndex = 0;
    while (true) {
      Integer siStart = sstXml.indexOf('<si>', fromIndex);
      if (siStart < 0) {
        break;
      }
      Integer siEnd = sstXml.indexOf('</si>', siStart);
      if (siEnd < 0) {
        break;
      }
      String chunk = sstXml.substring(siStart, siEnd);
      Integer tOpen = chunk.indexOf('<t');
      if (tOpen < 0) {
        items.add('');
      } else {
        Integer tGt = chunk.indexOf('>', tOpen);
        if (tGt > 0 && chunk.substring(tGt - 1, tGt) == '/') {
          items.add('');
        } else {
          Integer tClose = chunk.indexOf('</t>', tGt);
          items.add(
            tClose < 0
              ? ''
              : unescapeXml(chunk.substring(tGt + 1, tClose))
          );
        }
      }
      fromIndex = siEnd + 5;
    }
    return items;
  }

  @TestVisible
  static Map<String, String> parseHeaderColumns(
    String sheetXml,
    List<String> sharedStrings
  ) {
    Map<String, String> colToHeader = new Map<String, String>();
    String headerRow = extractSheetRow(sheetXml, '1');
    if (String.isBlank(headerRow)) {
      return colToHeader;
    }
    Matcher cellMatcher = Pattern.compile(
      '<c r="([A-Z]+)1"[^>]*t="s"[^>]*>\\s*<v>(\\d+)</v>'
    )
      .matcher(headerRow);
    while (cellMatcher.find()) {
      Integer idx = Integer.valueOf(cellMatcher.group(2));
      if (idx >= 0 && idx < sharedStrings.size()) {
        colToHeader.put(cellMatcher.group(1), sharedStrings.get(idx));
      }
    }
    return colToHeader;
  }

  @TestVisible
  static String columnForHeader(
    Map<String, String> colToHeader,
    String fragment
  ) {
    if (String.isBlank(fragment) || colToHeader == null) {
      return null;
    }
    String needle = fragment.trim().toLowerCase();
    // Exakt träff på frågenamnet efter Webropols "n:m:"-prefix måste gå före
    // delsträngsträff, annars tar fragmentet "mobil" standardkolumnen "Mobile".
    for (String col : colToHeader.keySet()) {
      String header = colToHeader.get(col);
      if (String.isNotBlank(header) && headerName(header).equals(needle)) {
        return col;
      }
    }
    for (String col : colToHeader.keySet()) {
      String header = colToHeader.get(col);
      if (String.isNotBlank(header) && header.toLowerCase().contains(needle)) {
        return col;
      }
    }
    return null;
  }

  private static String headerName(String header) {
    String value = header.trim().toLowerCase();
    Integer separator = value.lastIndexOf(':');
    return separator >= 0 ? value.substring(separator + 1) : value;
  }

  @TestVisible
  static String insertRecipientRow(
    String sheetXml,
    Map<String, Integer> colToSstIndex
  ) {
    Integer nextRow = nextSheetRowNumber(sheetXml);
    String rowNum = String.valueOf(nextRow);
    List<String> cols = new List<String>();
    if (colToSstIndex != null) {
      cols.addAll(colToSstIndex.keySet());
    }
    cols.sort();
    String cells = '';
    String maxCol = 'A';
    for (String col : cols) {
      cells +=
        '<c r="' +
        col +
        rowNum +
        '" t="s"><v>' +
        String.valueOf(colToSstIndex.get(col)) +
        '</v></c>';
      if (col.length() > maxCol.length() ||
        (col.length() == maxCol.length() && col > maxCol)) {
        maxCol = col;
      }
    }
    String row = '<row r="' + rowNum + '">' + cells + '</row>';
    if (!sheetXml.contains('</sheetData>')) {
      throw new WebropolException(
        'ExportDemDataFile saknar sheetData'
      );
    }
    String withRow = sheetXml.replace('</sheetData>', row + '</sheetData>');
    Pattern dimPattern = Pattern.compile('ref="A1:[A-Z]+\\d+"');
    Matcher dimMatcher = dimPattern.matcher(withRow);
    if (dimMatcher.find()) {
      return dimMatcher.replaceFirst('ref="A1:' + maxCol + rowNum + '"');
    }
    return withRow;
  }

  @TestVisible
  static Integer nextSheetRowNumber(String sheetXml) {
    Integer maxRow = 1;
    Matcher rowMatcher = Pattern.compile('<row r="(\\d+)"').matcher(sheetXml);
    while (rowMatcher.find()) {
      Integer rowNum = Integer.valueOf(rowMatcher.group(1));
      if (rowNum > maxRow) {
        maxRow = rowNum;
      }
    }
    return maxRow + 1;
  }

  @TestVisible
  static Integer countSharedStringItems(String sstXml) {
    Integer count = 0;
    Integer fromIndex = 0;
    while (true) {
      Integer found = sstXml.indexOf('<si>', fromIndex);
      if (found < 0) {
        break;
      }
      count++;
      fromIndex = found + 4;
    }
    return count;
  }

  @TestVisible
  static String appendSharedString(String sstXml, String value) {
    Integer uniqueCount = countSharedStringItems(sstXml);
    String withItem = sstXml.replace(
      '</sst>',
      '<si><t>' + escapeXml(value) + '</t></si></sst>'
    );
    return bumpSstCounts(withItem, uniqueCount + 1);
  }

  private static String bumpSstCounts(String sstXml, Integer uniqueCount) {
    Pattern countPattern = Pattern.compile(
      'count="\\d+" uniqueCount="\\d+"'
    );
    Matcher matcher = countPattern.matcher(sstXml);
    if (!matcher.find()) {
      return sstXml;
    }
    return matcher.replaceFirst(
      'count="' + uniqueCount + '" uniqueCount="' + uniqueCount + '"'
    );
  }

  @TestVisible
  static String setSharedStringCell(
    String sheetXml,
    String cellRef,
    Integer stringIndex
  ) {
    Pattern cellPattern = Pattern.compile(
      '<c r="' + cellRef + '"[^>]*(/>|>.*?</c>)'
    );
    Matcher matcher = cellPattern.matcher(sheetXml);
    if (!matcher.find()) {
      throw new WebropolException(
        'ExportDemDataFile saknar cell ' + cellRef
      );
    }
    return matcher.replaceFirst(
      '<c r="' +
        cellRef +
        '" t="s"><v>' +
        String.valueOf(stringIndex) +
        '</v></c>'
    );
  }

  private static String escapeXml(String value) {
    if (value == null) {
      return '';
    }
    return value
      .replace('&', '&amp;')
      .replace('<', '&lt;')
      .replace('>', '&gt;')
      .replace('"', '&quot;')
      .replace('\'', '&apos;');
  }

  private static String unescapeXml(String value) {
    if (value == null) {
      return '';
    }
    return value
      .replace('&lt;', '<')
      .replace('&gt;', '>')
      .replace('&quot;', '"')
      .replace('&apos;', '\'')
      .replace('&amp;', '&');
  }

  @TestVisible
  static String personalLinkAfterImport(Settings settings, String importBody) {
    List<String> recipientIds = parseRecipientsAdded(importBody);
    if (recipientIds.isEmpty()) {
      throw new WebropolException(
        'Webropol import returnerade inga RecipientsAdded: ' + importBody
      );
    }
    String lastError = 'tomt svar från GET recipient';
    Integer attempts = recipientPollAttempts != null && recipientPollAttempts > 0
      ? recipientPollAttempts
      : 1;
    Integer cpuWaitMs = recipientPollCpuWaitMs != null ? recipientPollCpuWaitMs : 0;
    for (Integer attempt = 1; attempt <= attempts; attempt++) {
      try {
        String recipientJson = getRecipientByIdJson(settings, recipientIds[0]);
        String link = firstPersonalLink(recipientJson);
        if (String.isNotBlank(link)) {
          return link;
        }
        lastError = 'PersonalLinkToSurvey saknas';
      } catch (WebropolException ex) {
        lastError = ex.getMessage();
      }
      if (attempt < attempts && cpuWaitMs > 0 && Math.mod(attempt, 10) == 0) {
        waitCpu(cpuWaitMs);
      }
    }
    throw new WebropolException(
      'Respondent skapades men personlig länk kunde inte hämtas: ' + lastError
    );
  }

  @TestVisible
  static void waitCpu(Integer millis) {
    if (millis == null || millis <= 0) {
      return;
    }
    Long stopAt = System.now().getTime() + millis;
    Integer acc = 0;
    while (System.now().getTime() < stopAt) {
      acc += Crypto.getRandomInteger();
    }
  }

  @TestVisible
  static List<String> parseRecipientsAdded(String importBody) {
    List<String> ids = new List<String>();
    if (String.isBlank(importBody)) {
      return ids;
    }
    Object parsed = JSON.deserializeUntyped(importBody);
    if (!(parsed instanceof Map<String, Object>)) {
      return ids;
    }
    Map<String, Object> root = (Map<String, Object>) parsed;
    if (root.get('IsFailed') == true) {
      throw new WebropolException(
        'Webropol importRecipientWithDemData misslyckades: ' + importBody
      );
    }
    Object added = root.get('RecipientsAdded');
    if (!(added instanceof List<Object>)) {
      return ids;
    }
    for (Object value : (List<Object>) added) {
      if (value != null && String.isNotBlank(String.valueOf(value))) {
        ids.add(String.valueOf(value));
      }
    }
    return ids;
  }

  @TestVisible
  static String firstPersonalLink(String recipientJson) {
    if (String.isBlank(recipientJson)) {
      return null;
    }
    Object parsed = JSON.deserializeUntyped(recipientJson);
    List<Object> rows = new List<Object>();
    if (parsed instanceof List<Object>) {
      rows = (List<Object>) parsed;
    } else if (parsed instanceof Map<String, Object>) {
      rows.add(parsed);
    }
    for (Object rowObj : rows) {
      if (!(rowObj instanceof Map<String, Object>)) {
        continue;
      }
      Map<String, Object> row = (Map<String, Object>) rowObj;
      Object link = row.get('PersonalLinkToSurvey');
      if (link == null) {
        link = row.get('personalLinkToSurvey');
      }
      if (link != null && String.isNotBlank(String.valueOf(link))) {
        return String.valueOf(link);
      }
    }
    return null;
  }

  @TestVisible
  private static String importRecipientWithDemData(
    Settings settings,
    Blob xlsx
  ) {
    String boundary = '----WebropolBoundary' + String.valueOf(Crypto.getRandomLong());
    String header =
      '--' +
      boundary +
      '\r\nContent-Disposition: form-data; name="File"; filename="Recipient_Demographic_Data.xlsx"\r\nContent-Type: application/vnd.openxmlformats-officedocument.spreadsheetml.sheet\r\n\r\n';
    String mid =
      '\r\n--' +
      boundary +
      '\r\nContent-Disposition: form-data; name="allowDuplicates"\r\n\r\nTrue\r\n--' +
      boundary +
      '--';
    Blob body = concatBlobs(
      new List<Blob>{ Blob.valueOf(header), xlsx, Blob.valueOf(mid) }
    );

    HttpResponse res = sendBearer(
      settings,
      buildSurveyPath(settings, '/importRecipientWithDemData'),
      GlobalConstants.HTTP_METHOD_POST,
      body,
      'multipart/form-data; boundary=' + boundary
    );
    Integer statusCode = res.getStatusCode();
    if (
      statusCode != GlobalConstants.HTTP_RESPONSE_CODE_SUCCESS &&
      statusCode != 201
    ) {
      throw new WebropolException(
        'Webropol importRecipientWithDemData misslyckades (' +
          statusCode +
          '): ' +
          res.getBody()
      );
    }
    return res.getBody();
  }

  private static Blob concatBlobs(List<Blob> parts) {
    String hex = '';
    for (Blob part : parts) {
      hex += EncodingUtil.convertToHex(part);
    }
    return EncodingUtil.convertFromHex(hex);
  }

  @TestVisible
  private static String buildSurveyPath(Settings settings, String suffix) {
    if (settings.useNamedCredential == true) {
      return 'callout:' +
        settings.namedCredentialName +
        '/api/v1/surveys/' +
        settings.surveyId +
        suffix;
    }
    String base = settings.apiBaseUrl.removeEnd('/');
    return base + '/surveys/' + settings.surveyId + suffix;
  }

  @TestVisible
  private static String sendBearerJson(
    Settings settings,
    String endpoint,
    Map<String, Object> body
  ) {
    return sendBearerJson(settings, endpoint, body, false);
  }

  @TestVisible
  private static String sendBearerJson(
    Settings settings,
    String endpoint,
    Map<String, Object> body,
    Boolean allowCreatedStatus
  ) {
    HttpResponse res = sendBearer(
      settings,
      endpoint,
      GlobalConstants.HTTP_METHOD_POST,
      Blob.valueOf(JSON.serialize(body)),
      GlobalConstants.HTTP_HEADER_FIELD_CONTENT_TYPE_VALUE_APPLICATION_JSON
    );
    Integer statusCode = res.getStatusCode();
    Boolean ok = statusCode == GlobalConstants.HTTP_RESPONSE_CODE_SUCCESS;
    if (allowCreatedStatus == true && statusCode == 201) {
      ok = true;
    }
    if (ok != true) {
      throw new WebropolException(
        'Webropol-anrop misslyckades (' +
          statusCode +
          ') ' +
          endpoint +
          ': ' +
          res.getBody()
      );
    }
    return res.getBody();
  }

  private static HttpResponse sendBearer(
    Settings settings,
    String endpoint,
    String method,
    Blob body,
    String contentType
  ) {
    String token = getAccessToken(settings);
    HttpRequest req = new HttpRequest();
    req.setEndpoint(endpoint);
    req.setMethod(method);
    req.setHeader(
      GlobalConstants.HTTP_HEADER_FIELD_NAME_AUTHORIZATION,
      GlobalConstants.HTTP_HEADER_FIELD_AUTHORIZATION_VALUE_BEARER + token
    );
    if (String.isNotBlank(contentType)) {
      req.setHeader(
        GlobalConstants.HTTP_HEADER_FIELD_NAME_CONTENT_TYPE,
        contentType
      );
    }
    if (body != null) {
      req.setBodyAsBlob(body);
    }
    req.setTimeout(120000);
    return new Http().send(req);
  }
}