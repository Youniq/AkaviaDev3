/**
 * @description       :
 * @author            : Malin Nilsson (Stretch Customer AB)
 * @group             :
 * @last modified on  : 2024-02-13
 * @last modified by  : Malin Nilsson (Stretch Customer AB)
 **/
@isTest
private class ApexLogTest {
  @isTest
  private static void createErrorLogFuture() {
    try {
      Integer result = 1 / 0;
    } catch (Exception ex) {
      Test.startTest();
      ApexLog.Error logError = new ApexLog.Error(
        'ApexLog_Test',
        'createErrorLog',
        true,
        ex
      );
      ApexLog.createLogDebugFuture(Json.serialize(logError));

      Test.stopTest();
      List<DebugLog__c> lstLogsCreated = [
        SELECT Id, Type__c, ApexClass__c, functionName__c
        FROM DebugLog__c
        WHERE functionName__c = 'createErrorLog'
      ];
      System.assertEquals(1, lstLogsCreated.size());
      System.assertEquals('Error', lstLogsCreated.get(0).Type__c);
    }
  }

  @isTest
  private static void createErrorLog() {
    try {
      Integer result = 1 / 0;
    } catch (Exception ex) {
      Test.startTest();

      ApexLog.Error logError = new ApexLog.Error(
        'ApexLog_Test',
        'createErrorLog',
        true,
        ex
      );
      ApexLog.createLogDebug(logError);

      Test.stopTest();
      List<DebugLog__c> lstLogsCreated = [
        SELECT Id, Type__c, ApexClass__c, functionName__c
        FROM DebugLog__c
        WHERE functionName__c = 'createErrorLog'
      ];
      System.assertEquals(1, lstLogsCreated.size());
      System.assertEquals('Error', lstLogsCreated.get(0).Type__c);
    }
  }

  @isTest
  private static void bulkCreateErrorLog() {
    List<ApexLog.Log> logList = new List<ApexLog.Log>();
    Integer count = 3;

    while (count > 0) {
      try {
        Integer result = 1 / 0;
      } catch (Exception ex) {
        ApexLog.Error logError = new ApexLog.Error(
          'ApexLogTest',
          'bulkCreateErrorLog',
          true,
          ex
        );
        logList.add(logError);
      }
      count--;
    }

    Test.startTest();
    ApexLog.bulkCreateLogDebug(logList);
    Test.stopTest();

    List<DebugLog__c> logsCreated = [
      SELECT Id, Type__c, ApexClass__c, functionName__c
      FROM DebugLog__c
      WHERE functionName__c = 'bulkCreateErrorLog'
    ];
    System.assertEquals(3, logsCreated.size());
    System.assertEquals('Error', logsCreated.get(0).Type__c);
  }

  @isTest
  private static void createInformationLogFuture() {
    Test.startTest();
    ApexLog.Information logInfo = new ApexLog.Information(
      'ApexLog_Test',
      'createInformationLog',
      true,
      'createInformationLog'
    );
    ApexLog.createLogDebugFuture(Json.serialize(logInfo));
    Test.stopTest();
    List<DebugLog__c> lstLogsCreated = [
      SELECT Id, Type__c, ApexClass__c, functionName__c, Message__c
      FROM DebugLog__c
      WHERE functionName__c = 'createInformationLog'
    ];
    System.assertEquals(1, lstLogsCreated.size());
    System.assertEquals('Information', lstLogsCreated.get(0).Type__c);
    System.assertEquals('ApexLog_Test', lstLogsCreated.get(0).ApexClass__c);
    System.assertEquals(
      'createInformationLog',
      lstLogsCreated.get(0).Message__c
    );
  }

  @isTest
  private static void createInformationLog() {
    Test.startTest();
    ApexLog.Information logInfo = new ApexLog.Information(
      'ApexLog_Test',
      'createInformationLog',
      true,
      'createInformationLog'
    );
    ApexLog.createLogDebug(logInfo);
    Test.stopTest();
    List<DebugLog__c> lstLogsCreated = [
      SELECT Id, Type__c, ApexClass__c, functionName__c, Message__c
      FROM DebugLog__c
      WHERE functionName__c = 'createInformationLog'
    ];
    System.assertEquals(1, lstLogsCreated.size());
    System.assertEquals('Information', lstLogsCreated.get(0).Type__c);
    System.assertEquals('ApexLog_Test', lstLogsCreated.get(0).ApexClass__c);
    System.assertEquals(
      'createInformationLog',
      lstLogsCreated.get(0).Message__c
    );
  }

  @isTest
  private static void testBulkCreateInformationLogFuture() {
    Test.startTest();
    List<ApexLog.Log> logsToCreate = new List<ApexLog.Log>();
    ApexLog.Information logInfo = new ApexLog.Information(
      'ApexLog_Test',
      'testBulkCreateInformationLogFuture',
      true,
      'testBulkCreateInformationLogFuture'
    );

    logsToCreate.add(logInfo);
    ApexLog.bulkCreateLogDebugFuture(Json.serialize(logsToCreate));
    Test.stopTest();
    List<DebugLog__c> lstLogsCreated = [
      SELECT Id, Type__c, ApexClass__c, functionName__c, Message__c
      FROM DebugLog__c
      WHERE functionName__c = 'testBulkCreateInformationLogFuture'
    ];
    System.assertEquals(1, lstLogsCreated.size());
    System.assertEquals('Information', lstLogsCreated.get(0).Type__c);
    System.assertEquals('ApexLog_Test', lstLogsCreated.get(0).ApexClass__c);
    System.assertEquals(
      'testBulkCreateInformationLogFuture',
      lstLogsCreated.get(0).Message__c
    );
  }

  @isTest
  private static void testBulkCreateInformationLog() {
    Test.startTest();
    List<ApexLog.Log> logsToCreate = new List<ApexLog.Log>();
    ApexLog.Information logInfo = new ApexLog.Information(
      'ApexLog_Test',
      'testBulkCreateInformationLog',
      true,
      'testBulkCreateInformationLog'
    );

    logsToCreate.add(logInfo);
    ApexLog.bulkCreateLogDebug(logsToCreate);
    Test.stopTest();
    List<DebugLog__c> lstLogsCreated = [
      SELECT Id, Type__c, ApexClass__c, functionName__c, Message__c
      FROM DebugLog__c
      WHERE functionName__c = 'testBulkCreateInformationLog'
    ];
    System.assertEquals(1, lstLogsCreated.size());
    System.assertEquals('Information', lstLogsCreated.get(0).Type__c);
    System.assertEquals('ApexLog_Test', lstLogsCreated.get(0).ApexClass__c);
    System.assertEquals(
      'testBulkCreateInformationLog',
      lstLogsCreated.get(0).Message__c
    );
  }
}