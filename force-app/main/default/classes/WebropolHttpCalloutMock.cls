@IsTest
public class WebropolHttpCalloutMock implements HttpCalloutMock {
  private final Integer tokenStatus;
  private final String tokenBody;
  private final Integer recipientsStatus;
  private final String recipientsBody;

  public WebropolHttpCalloutMock(
    Integer tokenStatus,
    String tokenBody,
    Integer recipientsStatus,
    String recipientsBody
  ) {
    this.tokenStatus = tokenStatus;
    this.tokenBody = tokenBody;
    this.recipientsStatus = recipientsStatus;
    this.recipientsBody = recipientsBody;
  }

  public static WebropolHttpCalloutMock successDefaults() {
    return new WebropolHttpCalloutMock(
      200,
      '{"access_token":"test-token","token_type":"bearer","expires_in":3600}',
      200,
      '[' +
        '{' +
        '"RecipientId":"r1",' +
        '"PersonalLinkToSurvey":"https://link.webropolsurveys.com/R/TEST123",' +
        '"Fields":[' +
        '{"FieldName":"1:1:MemberId","FieldValue":"8462"}' +
        ']' +
        '}' +
        ']'
    );
  }

  public static WebropolHttpCalloutMock emptyRecipients() {
    return new WebropolHttpCalloutMock(
      200,
      '{"access_token":"test-token","token_type":"bearer","expires_in":3600}',
      200,
      '[]'
    );
  }

  public static WebropolHttpCalloutMock tokenFailure() {
    return new WebropolHttpCalloutMock(
      401,
      '{"error":"invalid_grant"}',
      200,
      '[]'
    );
  }

  public static Blob demDataTemplateXlsx() {
    Compression.ZipWriter writer = new Compression.ZipWriter();
    writer.addEntry(
      'xl/worksheets/sheet1.xml',
      Blob.valueOf(
        '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">' +
          '<sheetData>' +
          '<row r="1">' +
          '<c r="A1" t="s"><v>0</v></c>' +
          '<c r="B1" t="s"><v>7</v></c>' +
          '<c r="C1" t="s"><v>5</v></c>' +
          '<c r="D1" t="s"><v>6</v></c>' +
          '<c r="E1" t="s"><v>2</v></c>' +
          '<c r="G1" t="s"><v>3</v></c>' +
          '<c r="H1" t="s"><v>4</v></c>' +
          '<c r="I1" t="s"><v>8</v></c>' +
          '<c r="J1" t="s"><v>9</v></c>' +
          '<c r="K1" t="s"><v>10</v></c>' +
          '<c r="L1" t="s"><v>11</v></c>' +
          '<c r="M1" t="s"><v>12</v></c>' +
          '<c r="N1" t="s"><v>13</v></c>' +
          '<c r="O1" t="s"><v>14</v></c>' +
          '</row>' +
          '<row r="2"><c r="A2" s="7" t="s"><v>1</v></c></row>' +
          '</sheetData></worksheet>'
      )
    );
    writer.addEntry(
      'xl/sharedStrings.xml',
      Blob.valueOf(
        '<sst xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" count="15" uniqueCount="15">' +
          '<si><t>Email</t></si>' +
          '<si><t>(one respondent per row)</t></si>' +
          '<si><t>1:1:MemberId</t></si>' +
          '<si><t>4:1:AktuellArbetsgivare</t></si>' +
          '<si><t>5:1:Examensår</t></si>' +
          '<si><t>FirstName</t></si>' +
          '<si><t>LastName</t></si>' +
          '<si><t>Mobile</t></si>' +
          '<si><t>2:1:ContactId</t></si>' +
          '<si><t>3:1:AccountId</t></si>' +
          '<si><t>6:1:ArChef</t></si>' +
          '<si><t>7:1:Epost</t></si>' +
          '<si><t>8:1:Mobil</t></si>' +
          '<si><t>9:1:Fornamn</t></si>' +
          '<si><t>10:1:Efternamn</t></si>' +
          '</sst>'
      )
    );
    return writer.getArchive();
  }

  public HTTPResponse respond(HTTPRequest req) {
    HttpResponse res = new HttpResponse();
    String endpoint = req.getEndpoint() != null ? req.getEndpoint().toLowerCase() : '';
    if (endpoint.contains('/token') || endpoint.contains('webropol_api/token')) {
      res.setStatusCode(tokenStatus);
      res.setBody(tokenBody);
      res.setHeader('Content-Type', 'application/json');
      return res;
    }
    if (endpoint.contains('getbyemail')) {
      res.setStatusCode(recipientsStatus);
      res.setBody(recipientsBody);
      res.setHeader('Content-Type', 'application/json');
      return res;
    }
    if (endpoint.contains('exportdemdatafile')) {
      res.setStatusCode(200);
      res.setBodyAsBlob(demDataTemplateXlsx());
      res.setHeader(
        'Content-Type',
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
      );
      return res;
    }
    if (endpoint.contains('importrecipientwithdemdata')) {
      res.setStatusCode(200);
      res.setBody(
        '{"RecipientsAdded":["new-recipient-id"],' +
          '"Message":"1 out of 1 recipients uploaded successfully",' +
          '"IsFailed":false,"IsScheduled":true}'
      );
      res.setHeader('Content-Type', 'application/json');
      return res;
    }
    if (
      endpoint.contains('/recipients/') &&
      !endpoint.contains('getbyemail')
    ) {
      res.setStatusCode(200);
      res.setBody(
        '[{"RecipientId":"new-recipient-id",' +
          '"Email":"medlem@example.com",' +
          '"PersonalLinkToSurvey":"https://link.webropolsurveys.com/R/TEST123"}]'
      );
      res.setHeader('Content-Type', 'application/json');
      return res;
    }
    if (
      endpoint.contains('/recipients') &&
      !endpoint.contains('getbyemail')
    ) {
      res.setStatusCode(201);
      res.setBody('{}');
      res.setHeader('Content-Type', 'application/json');
      return res;
    }
    res.setStatusCode(404);
    res.setBody('Unexpected endpoint: ' + req.getEndpoint());
    return res;
  }
}