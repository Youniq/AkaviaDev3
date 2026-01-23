/**
 * @description       : NO LONGER USED. The logic has been replaced with 100% flow.
 * @author            : Malin Nilsson (Stretch Customer AB)
 * @group             :
 * @last modified on  : 2024-03-21
 * @last modified by  : Malin Nilsson (Stretch Customer AB)
 **/
@isTest
public with sharing class CloneCaseFilesInvocableTest {
  // @testSetup
  // static void makeData() {
  //   // Create a case with 3 uploaded files.
  //   TestDataFactorySetupParams params = new TestDataFactorySetupParams();
  //   params.numberOfCases = 1;
  //   params.numberOfCaseFiles = 3;
  //   TestDataFactory.setupTestData(params);
  // }

  // @isTest
  // private static void testCopyPublicFilesSuccess() {
  //   Case fromCase = [SELECT Id FROM Case LIMIT 1];
  //   Case toCase;

  //   // create another case, without any uploaded files.
  //   TestDataFactorySetupParams params = new TestDataFactorySetupParams();
  //   params.numberOfCases = 1;
  //   List<Case> toCases = TestDataFactory.createTestCases(params, true);
  //   toCase = toCases[0]; // get the first entry.
  //   List<Id> cdlIdsToCopy = new List<Id>();

  //   // Collects documents on To Case (destination case, should be 0)
  //   List<ContentDocumentLink> cdLinksDestinationBefore = [
  //     SELECT Id, ContentDocumentId
  //     FROM ContentDocumentLink
  //     WHERE LinkedEntityId = :toCase.Id
  //   ];

  //   // Check that the destination case don't have any files yet.
  //   System.assertEquals(
  //     0,
  //     cdLinksDestinationBefore.size(),
  //     'Destination aldready has documents added. Should be 0 for this test.'
  //   );

  //   // Collects documents on From Case (Source case, should be three records.)
  //   List<ContentDocumentLink> cdlinksSource = [
  //     SELECT Id, ContentDocumentId
  //     FROM ContentDocumentLink
  //     WHERE LinkedEntityId = :fromCase.Id
  //   ];

  //   for (ContentDocumentLink cdl : cdlinksSource) {
  //     cdlIdsToCopy.add(cdl.ContentDocumentId);
  //   }

  //   Test.startTest();
  //   CloneCaseFilesInvocable.Request req = new CloneCaseFilesInvocable.Request();
  //   req.fromCaseId = fromCase.Id;
  //   req.toCaseId = toCase.Id;
  //   req.contentDocumentIds = cdlIdsToCopy;
  //   req.publicVisibilty = true;

  //   List<CloneCaseFilesInvocable.Request> requests = new List<CloneCaseFilesInvocable.Request>();
  //   requests.add(req);

  //   CloneCaseFilesInvocable.CloneFilesBetweenCases(requests);
  //   Test.stopTest();

  //   // Collects documents on To Case (destination case, should be 0)
  //   List<ContentDocumentLink> cdLinksDestinationAfter = [
  //     SELECT Id, ContentDocumentId
  //     FROM ContentDocumentLink
  //     WHERE LinkedEntityId = :toCase.Id
  //   ];

  //   // Check that the destination case has the same amount of files as the source case (as we're copying all in this test).
  //   System.assertEquals(
  //     cdlinksSource.size(),
  //     cdLinksDestinationAfter.size(),
  //     'All files were not copied.'
  //   );
  // }

  // @isTest
  // private static void testCopyInternalFilesSuccess() {
  //   Case fromCase = [SELECT Id FROM Case LIMIT 1];
  //   Case toCase;

  //   // create another case, without any uploaded files.
  //   TestDataFactorySetupParams params = new TestDataFactorySetupParams();
  //   params.numberOfCases = 1;
  //   List<Case> toCases = TestDataFactory.createTestCases(params, true);
  //   toCase = toCases[0]; // get the first entry.
  //   List<Id> cdlIdsToCopy = new List<Id>();

  //   // Collects documents on To Case (destination case, should be 0)
  //   List<ContentDocumentLink> cdLinksDestinationBefore = [
  //     SELECT Id, ContentDocumentId
  //     FROM ContentDocumentLink
  //     WHERE LinkedEntityId = :toCase.Id
  //   ];

  //   // Check that the destination case don't have any files yet.
  //   System.assertEquals(
  //     0,
  //     cdLinksDestinationBefore.size(),
  //     'Destination aldready has documents added. Should be 0 for this test.'
  //   );

  //   // Collects documents on From Case (Source case, should be three records.)
  //   List<ContentDocumentLink> cdlinksSource = [
  //     SELECT Id, ContentDocumentId
  //     FROM ContentDocumentLink
  //     WHERE LinkedEntityId = :fromCase.Id
  //   ];

  //   for (ContentDocumentLink cdl : cdlinksSource) {
  //     cdlIdsToCopy.add(cdl.ContentDocumentId);
  //   }

  //   Test.startTest();
  //   CloneCaseFilesInvocable.Request req = new CloneCaseFilesInvocable.Request();
  //   req.fromCaseId = fromCase.Id;
  //   req.toCaseId = toCase.Id;
  //   req.contentDocumentIds = cdlIdsToCopy;
  //   req.publicVisibilty = false;

  //   List<CloneCaseFilesInvocable.Request> requests = new List<CloneCaseFilesInvocable.Request>();
  //   requests.add(req);

  //   CloneCaseFilesInvocable.CloneFilesBetweenCases(requests);
  //   Test.stopTest();

  //   // Collects documents on To Case (destination case, should be 0)
  //   List<ContentDocumentLink> cdLinksDestinationAfter = [
  //     SELECT Id, ContentDocumentId
  //     FROM ContentDocumentLink
  //     WHERE LinkedEntityId = :toCase.Id
  //   ];

  //   // Check that the destination case has the same amount of files as the source case (as we're copying all in this test).
  //   System.assertEquals(
  //     cdlinksSource.size(),
  //     cdLinksDestinationAfter.size(),
  //     'All files were not copied.'
  //   );
  // }

  // @isTest
  // private static void testCopyFileError() {
  //   Case fromCase = [SELECT Id FROM Case LIMIT 1];
  //   Case toCase;
  //   Boolean errorWasFound;

  //   // create another case, without any uploaded files.
  //   TestDataFactorySetupParams params = new TestDataFactorySetupParams();
  //   params.numberOfCases = 1;
  //   List<Case> toCases = TestDataFactory.createTestCases(params, true);
  //   toCase = toCases[0]; // get the first entry.

  //   Test.startTest();
  //   CloneCaseFilesInvocable.Request req = new CloneCaseFilesInvocable.Request();
  //   req.fromCaseId = fromCase.Id;
  //   req.toCaseId = toCase.Id;
  //   req.contentDocumentIds = null; // sending in null here makes the invoacable throw an exception

  //   List<CloneCaseFilesInvocable.Request> requests = new List<CloneCaseFilesInvocable.Request>();
  //   requests.add(req);

  //   try {
  //     CloneCaseFilesInvocable.CloneFilesBetweenCases(requests);
  //   } catch (Exception e) {
  //     errorWasFound = true;
  //   }

  //   Test.stopTest();

  //   System.assertEquals(
  //     true,
  //     errorWasFound,
  //     'Expected an error but no error was thrown.'
  //   );
  // }
}