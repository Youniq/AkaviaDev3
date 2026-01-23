@isTest
private class WorksiteChangesResponseTest {
  @isTest
  static void testParseResponse() {
    WorksiteChangesResponse resp = WorksiteChangesResponse.parse(
      MockHttpResponseGenerator.subscribeWorksiteString()
    );

    WorksiteChangesResponse.cls_changes[] changes = resp.changes;
    String wId = changes[0].worksiteId;
    String cType = changes[0].changeType;
    WorksiteChangesResponse.cls_changedFields[] fList = changes[0]
      .changedFields;
    String jsonPath = fList[0].jsonPath;
    String lastModifiedAt = fList[0].lastModifiedAt;
  }
}