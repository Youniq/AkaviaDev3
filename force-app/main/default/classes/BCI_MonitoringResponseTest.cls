@isTest
private class BCI_MonitoringResponseTest {
  @isTest
  static void testParseResponse() {
    BCI_MonitoringResponse resp = BCI_MonitoringResponse.parse(
      MockHttpResponseGenerator.BCIMonitoringResponseString()
    );
    PersonData[] changedEntities = resp.changedEntities;
    BCI_MonitoringResponse.cls_errorEntities[] errorEntities = resp.errorEntities;
    boolean hasMoreEntities = resp.hasMoreEntities;
    BCI_MonitoringResponse.cls_cursor cursor = resp.cursor;
    Integer numberOfEntities = resp.numberOfEntities;
  }
}