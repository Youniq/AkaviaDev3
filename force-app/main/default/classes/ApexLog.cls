/**
 * @author: Ahmad Amiri
 * @date 2019-10-30
 * @description: This Apex Class exposes method(s) that can be utilized by <br>
 * other Apex Classes to create Persistent Logs of type Error or<br>
 * Information as opposed to native Debug Logs. <br>
 */

global class ApexLog {
  /****************************************************************
   * @author:Ahmad Amiri
   * @date: 2019-10-30
   * A Virtual Class that Defines the Structure of a Log <br>
   *****************************************************************/
  public virtual class Log {
    public String Type;
    public String ApexClass;
    public String Function;
    public Boolean Urgent;
    public String Message;
    public String StackTrace;
    public String ExMessage;
    public String recordId;
  }

  /****************************************************************
   * @author:Ahmad Amiri
   * @date: 2019-10-30
   * A Class that Extends the Virtual Class - Log to define a log of type - Error <br>
   *****************************************************************/
  public class Error extends Log {
    public Error(
      String className,
      String function,
      Boolean urgent,
      Exception ex
    ) {
      this.Type = 'Error';
      this.ApexClass = className;
      this.Function = function;
      this.Urgent = urgent;
      this.Message = ex.getMessage();
      this.StackTrace = ex.getStackTraceString();
    }

    public Error(
      String className,
      String function,
      Boolean urgent,
      Database.Error err
    ) {
      this.Type = 'Error';
      this.ApexClass = className;
      this.Function = function;
      this.Urgent = urgent;
      this.Message = err.getStatusCode() + ' - ' + err.getMessage();
      this.ExMessage = String.join(err.getFields(), ', ');
    }
  }

  /****************************************************************
   * @author:Ahmad Amiri
   * @date: 2018-08-28
   * A Class that Extends the Virtual Class - Log to define a log of type - Information <br>
   *****************************************************************/
  public class Information extends Log {
    public Information(
      String className,
      String function,
      Boolean urgent,
      String msg
    ) {
      this.Type = 'Information';
      this.ApexClass = className;
      this.Function = function;
      this.Urgent = urgent;
      this.Message = msg;
      this.StackTrace = null;
    }

    // Add new cinstructure with new field exMessage to handle BCI daily
    public Information(
      String className,
      String function,
      Boolean urgent,
      String msg,
      String exMsg
    ) {
      this.Type = 'Information';
      this.ApexClass = className;
      this.Function = function;
      this.Urgent = urgent;
      this.Message = msg;
      this.StackTrace = null;
      this.ExMessage = exMsg;
    }
  }

  /****************************************************************
   * @author:Ahmad Amiri
   * @date: 2019-10-30
   * @param: Instance of Log class as json string <br>
   * @return: void <br>
   * @description: A Public Method that can be utilized by other Apex Classes to create a record into <br>
   * the Debug Log object stating the Error or Information. <br>
   *****************************************************************/
  @future
  public static void createLogDebugFuture(String jsonLog) {
    try {
      Log logToCreate = (Log) JSON.deserialize(jsonLog, Log.class);
      logToConsole(logToCreate);
      /*
Ensure that we're well within the Governor Limits.
The creation of the Log shouldn't disturb the execution
of that Apex Class that utilizes this method to
create a log.
*/
      if (
        (Limits.getDMLRows() < Limits.getLimitDMLRows()) &&
        (Limits.getDMLStatements() < Limits.getLimitDMLStatements())
      ) {
        DebugLog__c debuglog = new DebugLog__c(
          Type__c = logToCreate.Type,
          ApexClass__c = logToCreate.ApexClass,
          functionName__c = logToCreate.Function,
          Urgent__c = logToCreate.Urgent,
          Message__c = logToCreate.Message,
          StackTrace__c = logToCreate.StackTrace,
          recordId__c = logToCreate.recordId
        );
        Database.SaveResult srList = Database.insert(debuglog, false);
      } else {
        System.debug(
          'The Governor Limits have already been exhausted and hence failed to create a Log!'
        );
      }
    } catch (DMLException ex) {
      System.debug(
        'Something fatal has occurred and hence failed to create a Log! Error:' +
        ex.getMessage()
      );
    }
  }

  /****************************************************************
   * @author:Ahmad Amiri
   * @date: 2019-10-30
   * @param: Instance of Log class <br>
   * @return: void <br>
   * @description: A Public Method that can be utilized by other Apex Classes to create a record into <br>
   * the Debug Log object stating the Error or Information. <br>
   *****************************************************************/
  public static void createLogDebug(Log log) {
    logToConsole(log);
    DebugLog__c dl = createAndReturnDebugLog(log);
  }

  /****************************************************************
   * @author:Ahmad Amiri
   * @date: 2019-10-30
   * @param: Instance of Log class <br>
   * @return: DebugLog__c
   * @description: A Public Method that can be utilized by other Apex Classes to create a record into <br>
   * the Debug Log object stating the Error or Information. <br>
   *****************************************************************/
  public static DebugLog__c createAndReturnDebugLog(Log log) {
    DebugLog__c debuglog = new DebugLog__c();
    try {
      /*
      Ensure that we're well within the Governor Limits.
      The creation of the Log shouldn't disturb the execution
      of that Apex Class that utilizes this method to
      create a log.
      */
      if (
        (Limits.getDMLRows() < Limits.getLimitDMLRows()) &&
        (Limits.getDMLStatements() < Limits.getLimitDMLStatements())
      ) {
        debuglog = new DebugLog__c(
          Type__c = log.Type,
          ApexClass__c = log.ApexClass,
          functionName__c = log.Function,
          Urgent__c = log.Urgent,
          Message__c = log.Message,
          StackTrace__c = log.StackTrace,
          ExtraMessage__c = log.ExMessage,
          RecordId__c = log.recordId
        );
        insert debuglog;
      } else {
        System.debug(
          'The Governor Limits have already been exhausted and hence failed to create a Log!'
        );
      }
    } catch (DMLException ex) {
      System.debug(
        'Something fatal has occurred and hence failed to create a Log! Error:' +
        ex.getMessage()
      );
    }
    return debugLog;
  }

  /**
   * @description: A Public Method that can be utilized by other Apex Classes to create multiple records into <br>
   * the Debug Log object stating the Error or Information. <br>
   * @author Malin Nilsson (Stretch Customer AB) | 2023-11-06
   * @param logs - List<Log>
   **/

  public static void bulkCreateLogDebug(List<Log> logs) {
    List<DebugLog__c> logsToInsert = new List<DebugLog__c>();

    try {
      /*
                Ensure that we're well within the Governor Limits.
                The creation of the Log shouldn't disturb the execution
                of that Apex Class that utilizes this method to
                create a log.
                */

      if (
        (Limits.getDMLRows() < Limits.getLimitDMLRows()) &&
        (Limits.getDMLStatements() < Limits.getLimitDMLStatements())
      ) {
        for (Log log : logs) {
          logToConsole(log);
          DebugLog__c debuglog = new DebugLog__c(
            Type__c = log.Type,
            ApexClass__c = log.ApexClass,
            functionName__c = log.Function,
            Urgent__c = log.Urgent,
            Message__c = log.Message,
            StackTrace__c = log.StackTrace,
            RecordId__c = log.recordId
          );

          logsToInsert.add(debuglog);
        }

        insert logsToInsert;
        // Database.SaveResult[] srList = Database.insert(logsToInsert, false);
      } else {
        System.debug(
          'The Governor Limits have already been exhausted and hence failed to create a Log!'
        );
      }
    } catch (DMLException ex) {
      System.debug(
        'Something fatal has occurred and hence failed to create a Log! Error:' +
        ex.getMessage()
      );
    }
  }

  /**
   * @description: A Public Method that can be utilized by other Apex Classes to create multiple records into <br>
   * the Debug Log object stating the Error or Information. <br>
   * @author Malin Nilsson (Stretch Customer AB) | 2023-11-06
   * @param logs - List<Log>
   **/
  @future
  public static void bulkCreateLogDebugFuture(String jsonLogs) {
    List<Log> logs = (List<Log>) JSON.deserialize(jsonLogs, List<Log>.class);
    List<DebugLog__c> logsToInsert = new List<DebugLog__c>();

    try {
      /*
                Ensure that we're well within the Governor Limits.
                The creation of the Log shouldn't disturb the execution
                of that Apex Class that utilizes this method to
                create a log.
                */

      if (
        (Limits.getDMLRows() < Limits.getLimitDMLRows()) &&
        (Limits.getDMLStatements() < Limits.getLimitDMLStatements())
      ) {
        for (Log log : logs) {
          logToConsole(log);
          DebugLog__c debuglog = new DebugLog__c(
            Type__c = log.Type,
            ApexClass__c = log.ApexClass,
            functionName__c = log.Function,
            Urgent__c = log.Urgent,
            Message__c = log.Message,
            StackTrace__c = log.StackTrace,
            RecordId__c = log.recordId
          );

          logsToInsert.add(debuglog);
        }

        insert logsToInsert;
        // Database.SaveResult[] srList = Database.insert(logsToInsert, false);
      } else {
        System.debug(
          'The Governor Limits have already been exhausted and hence failed to create a Log!'
        );
      }
    } catch (DMLException ex) {
      System.debug(
        'Something fatal has occurred and hence failed to create a Log! Error:' +
        ex.getMessage()
      );
    }
  }

    private static void logToConsole(Log log){
      System.debug('Type: ' + log.Type);
      System.debug('Message: ' + log.Message);
      System.debug('Stack trace: ' + log.StackTrace);
  }
}