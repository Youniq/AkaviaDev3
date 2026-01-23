@isTest
private class CompanyChangesResponseTest {
  @isTest
  static void testParseResponse() {
    CompanyChangesResponse resp = CompanyChangesResponse.parse(
      MockHttpResponseGenerator.subscribeCompanyString()
    );

    CompanyChangesResponse.cls_changes[] changes = resp.changes;
    String wId = changes[0].companyId;
    String cType = changes[0].changeType;
    CompanyChangesResponse.cls_changedFields[] fList = changes[0].changedFields;
    String jsonPath = fList[0].jsonPath;
    String lastModifiedAt = fList[0].lastModifiedAt;
  }
}