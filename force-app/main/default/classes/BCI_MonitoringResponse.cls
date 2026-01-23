public class BCI_MonitoringResponse {
  public PersonData[] changedEntities;
  public cls_errorEntities[] errorEntities;
  public boolean hasMoreEntities;
  public cls_cursor cursor;
  public Integer numberOfEntities; //5

  public class cls_errorEntities {
    public String gedi;
    public String errorValue;
    public String errorMessage;
  }
  public class cls_cursor {
    public String next; //5fbe20d9a57bb0e4f1282848
  }
  public static BCI_MonitoringResponse parse(String json) {
    return (BCI_MonitoringResponse) System.JSON.deserialize(
      json,
      BCI_MonitoringResponse.class
    );
  }
}