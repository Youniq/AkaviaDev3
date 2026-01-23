/**
 * @description       : 
 * @author            : Malin Nilsson (Stretch Customer AB)
 * @group             : 
 * @last modified on  : 2025-01-09
 * @last modified by  : Malin Nilsson (Stretch Customer AB)
**/
@isTest
public with sharing class SetAccountRandomNoTest {
    @TestSetup
    static void setup() {   

        TestDataFactorySetupParams params = new TestDataFactorySetupParams();
        params.numberOfAccounts = 10;
        // params.numberOfMemberUsers = 10;
        params.addMembershipsToMembers = true;

        TestDataFactory.setupBasicTestData();
        TestDataFactory.setupTestData(params);
        
    }

    @IsTest
    static void testSetAccountRandomNoBatch() {

        Test.startTest();
        SchedulableSetAccountRandomNo.runBatch();
        Test.stopTest();
        
        List<Account> accounts = [SELECT Id, RandomNo__c FROM Account where RandomNo__c != null];
        Assert.areNotEqual(0, accounts.size());
        // for( Account acc : [SELECT Id, RandomNo__c FROM Account] ) {
        //     Assert.areNotEqual(null, acc.RandomNo__c);
        // }
    }

    @IsTest
    static void testScheduleJob() {
       
    Test.startTest();
    String jobId = SchedulableSetAccountRandomNo.scheduleIt();
    Test.stopTest();

    // Query the CronTrigger object to verify the job was scheduled
    CronTrigger ct = [SELECT Id, CronExpression, TimesTriggered, NextFireTime FROM CronTrigger WHERE id = :jobId];

      // Verify the job has not run yet
      Assert.areEqual(0, ct.TimesTriggered);
    }
}