@IsTest
private class ContractReviewFileSelectorTest {
  @TestSetup
  static void setup() {
    Case parentCase = new Case(Subject = 'Test File Selector');
    insert parentCase;

    // File linked directly to Case
    ContentVersion caseFile = new ContentVersion(
      Title = 'CaseFile',
      PathOnClient = 'CaseFile.pdf',
      VersionData = Blob.valueOf('case file content')
    );
    insert caseFile;
    Id caseDocId = [
      SELECT ContentDocumentId
      FROM ContentVersion
      WHERE Id = :caseFile.Id
    ]
    .ContentDocumentId;
    insert new ContentDocumentLink(
      ContentDocumentId = caseDocId,
      LinkedEntityId = parentCase.Id,
      ShareType = 'V'
    );

    // EmailMessage on the Case
    EmailMessage em = new EmailMessage(
      ParentId = parentCase.Id,
      Subject = 'Test Email',
      TextBody = 'Email body',
      Incoming = true
    );
    insert em;

    // File linked to EmailMessage
    ContentVersion emailFile = new ContentVersion(
      Title = 'EmailAttachment',
      PathOnClient = 'EmailAttachment.pdf',
      VersionData = Blob.valueOf('email attachment content')
    );
    insert emailFile;
    Id emailDocId = [
      SELECT ContentDocumentId
      FROM ContentVersion
      WHERE Id = :emailFile.Id
    ]
    .ContentDocumentId;
    insert new ContentDocumentLink(
      ContentDocumentId = emailDocId,
      LinkedEntityId = em.Id,
      ShareType = 'V'
    );
  }

  @IsTest
  static void getFiles_caseWithCaseAndEmailFiles_returnsDeduplicated() {
    Case parentCase = [SELECT Id FROM Case LIMIT 1];

    ContractReviewFileSelector.Request req = new ContractReviewFileSelector.Request();
    req.caseId = parentCase.Id;

    Test.startTest();
    List<ContractReviewFileSelector.Response> results = ContractReviewFileSelector.getFiles(
      new List<ContractReviewFileSelector.Request>{ req }
    );
    Test.stopTest();

    System.assertEquals(1, results.size(), 'Should return one response');
    List<ContentDocument> docs = results[0].contentDocuments;
    System.assertEquals(2, docs.size(), 'Should return 2 files (Case + EmailMessage)');

    Set<String> titles = new Set<String>();
    for (ContentDocument doc : docs) {
      titles.add(doc.Title);
    }
    System.assert(titles.contains('CaseFile'), 'Should contain the Case file');
    System.assert(
      titles.contains('EmailAttachment'),
      'Should contain the EmailMessage attachment'
    );
  }

  @IsTest
  static void getFiles_caseWithNoFiles_returnsEmptyList() {
    Case emptyCase = new Case(Subject = 'Empty Case');
    insert emptyCase;

    ContractReviewFileSelector.Request req = new ContractReviewFileSelector.Request();
    req.caseId = emptyCase.Id;

    Test.startTest();
    List<ContractReviewFileSelector.Response> results = ContractReviewFileSelector.getFiles(
      new List<ContractReviewFileSelector.Request>{ req }
    );
    Test.stopTest();

    System.assertEquals(1, results.size(), 'Should return one response');
    System.assertEquals(
      0,
      results[0].contentDocuments.size(),
      'Should return empty list when no files exist'
    );
  }

  @IsTest
  static void getFiles_nullCaseId_returnsEmptyList() {
    ContractReviewFileSelector.Request req = new ContractReviewFileSelector.Request();
    req.caseId = null;

    Test.startTest();
    List<ContractReviewFileSelector.Response> results = ContractReviewFileSelector.getFiles(
      new List<ContractReviewFileSelector.Request>{ req }
    );
    Test.stopTest();

    System.assertEquals(1, results.size(), 'Should return one response');
    System.assertEquals(
      0,
      results[0].contentDocuments.size(),
      'Should return empty list for null caseId'
    );
  }

  @IsTest
  static void getFiles_emptyRequestList_returnsEmptyList() {
    Test.startTest();
    List<ContractReviewFileSelector.Response> results = ContractReviewFileSelector.getFiles(
      new List<ContractReviewFileSelector.Request>()
    );
    Test.stopTest();

    System.assertEquals(
      0,
      results.size(),
      'Should return empty list for empty input'
    );
  }

  @IsTest
  static void getFiles_bulkRequests_usesThreeQueries() {
    Case parentCase = [SELECT Id FROM Case WHERE Subject = 'Test File Selector' LIMIT 1];

    Case secondCase = new Case(Subject = 'Second Case');
    insert secondCase;

    ContentVersion secondFile = new ContentVersion(
      Title = 'SecondCaseFile',
      PathOnClient = 'SecondCaseFile.pdf',
      VersionData = Blob.valueOf('second case content')
    );
    insert secondFile;
    Id secondDocId = [
      SELECT ContentDocumentId
      FROM ContentVersion
      WHERE Id = :secondFile.Id
    ]
    .ContentDocumentId;
    insert new ContentDocumentLink(
      ContentDocumentId = secondDocId,
      LinkedEntityId = secondCase.Id,
      ShareType = 'V'
    );

    ContractReviewFileSelector.Request req1 = new ContractReviewFileSelector.Request();
    req1.caseId = parentCase.Id;

    ContractReviewFileSelector.Request req2 = new ContractReviewFileSelector.Request();
    req2.caseId = secondCase.Id;

    ContractReviewFileSelector.Request req3 = new ContractReviewFileSelector.Request();
    req3.caseId = null;

    Test.startTest();
    Integer queriesBefore = Limits.getQueries();
    List<ContractReviewFileSelector.Response> results = ContractReviewFileSelector.getFiles(
      new List<ContractReviewFileSelector.Request>{ req1, req2, req3 }
    );
    Integer queriesUsed = Limits.getQueries() - queriesBefore;
    Test.stopTest();

    System.assertEquals(3, results.size(), 'Should return three responses');
    System.assertEquals(
      3,
      queriesUsed,
      'Should use exactly 3 SOQL queries regardless of request count'
    );

    // First request: Case + EmailMessage files
    System.assertEquals(
      2,
      results[0].contentDocuments.size(),
      'First case should have 2 files'
    );

    // Second request: one file on second case
    System.assertEquals(
      1,
      results[1].contentDocuments.size(),
      'Second case should have 1 file'
    );
    System.assertEquals(
      'SecondCaseFile',
      results[1].contentDocuments[0].Title,
      'Second case file should be SecondCaseFile'
    );

    // Third request: null caseId
    System.assertEquals(
      0,
      results[2].contentDocuments.size(),
      'Null caseId should return empty list'
    );
  }

  @IsTest
  static void getFiles_duplicateFile_deduplicates() {
    Case parentCase = [SELECT Id FROM Case WHERE Subject = 'Test File Selector' LIMIT 1];
    EmailMessage em = [SELECT Id FROM EmailMessage WHERE ParentId = :parentCase.Id LIMIT 1];

    // Link the Case file also to the EmailMessage (creating a duplicate)
    ContentDocumentLink existingLink = [
      SELECT ContentDocumentId
      FROM ContentDocumentLink
      WHERE LinkedEntityId = :parentCase.Id
        AND ContentDocument.Title = 'CaseFile'
      LIMIT 1
    ];
    insert new ContentDocumentLink(
      ContentDocumentId = existingLink.ContentDocumentId,
      LinkedEntityId = em.Id,
      ShareType = 'V'
    );

    ContractReviewFileSelector.Request req = new ContractReviewFileSelector.Request();
    req.caseId = parentCase.Id;

    Test.startTest();
    List<ContractReviewFileSelector.Response> results = ContractReviewFileSelector.getFiles(
      new List<ContractReviewFileSelector.Request>{ req }
    );
    Test.stopTest();

    System.assertEquals(1, results.size(), 'Should return one response');
    List<ContentDocument> docs = results[0].contentDocuments;
    // CaseFile is linked to both Case and EmailMessage, but should appear only once
    // EmailAttachment is linked only to EmailMessage
    System.assertEquals(
      2,
      docs.size(),
      'Should return 2 unique files even though CaseFile is linked to both Case and EmailMessage'
    );
  }

  @IsTest
  static void getFiles_unsupportedFormats_areExcluded() {
    Case parentCase = [SELECT Id FROM Case WHERE Subject = 'Test File Selector' LIMIT 1];

    // Create unsupported file types linked to the Case
    ContentVersion txtFile = new ContentVersion(
      Title = 'NonPdfFile',
      PathOnClient = 'NonPdfFile.txt',
      VersionData = Blob.valueOf('text content')
    );
    insert txtFile;
    Id txtDocId = [
      SELECT ContentDocumentId
      FROM ContentVersion
      WHERE Id = :txtFile.Id
    ]
    .ContentDocumentId;
    insert new ContentDocumentLink(
      ContentDocumentId = txtDocId,
      LinkedEntityId = parentCase.Id,
      ShareType = 'V'
    );

    ContentVersion docxFile = new ContentVersion(
      Title = 'WordDoc',
      PathOnClient = 'WordDoc.docx',
      VersionData = Blob.valueOf('docx content')
    );
    insert docxFile;
    Id docxDocId = [
      SELECT ContentDocumentId
      FROM ContentVersion
      WHERE Id = :docxFile.Id
    ]
    .ContentDocumentId;
    insert new ContentDocumentLink(
      ContentDocumentId = docxDocId,
      LinkedEntityId = parentCase.Id,
      ShareType = 'V'
    );

    ContractReviewFileSelector.Request req = new ContractReviewFileSelector.Request();
    req.caseId = parentCase.Id;

    Test.startTest();
    List<ContractReviewFileSelector.Response> results = ContractReviewFileSelector.getFiles(
      new List<ContractReviewFileSelector.Request>{ req }
    );
    Test.stopTest();

    List<ContentDocument> docs = results[0].contentDocuments;
    for (ContentDocument doc : docs) {
      System.assert(
        ContractReviewFileSelector.SUPPORTED_EXTENSIONS.contains(doc.FileExtension),
        'All returned files should have supported extensions, but found: ' + doc.Title + '.' + doc.FileExtension
      );
    }
    // Should still return the 2 PDF files from setup, not .txt or .docx
    System.assertEquals(2, docs.size(), 'Should return only the 2 supported files from setup');
  }

  @IsTest
  static void getFiles_imageFiles_areIncluded() {
    Case parentCase = [SELECT Id FROM Case WHERE Subject = 'Test File Selector' LIMIT 1];

    // Create JPG file linked to the Case
    ContentVersion jpgFile = new ContentVersion(
      Title = 'ScannedContract',
      PathOnClient = 'ScannedContract.jpg',
      VersionData = Blob.valueOf('fake jpg content')
    );
    insert jpgFile;
    Id jpgDocId = [
      SELECT ContentDocumentId
      FROM ContentVersion
      WHERE Id = :jpgFile.Id
    ]
    .ContentDocumentId;
    insert new ContentDocumentLink(
      ContentDocumentId = jpgDocId,
      LinkedEntityId = parentCase.Id,
      ShareType = 'V'
    );

    // Create PNG file linked to the Case
    ContentVersion pngFile = new ContentVersion(
      Title = 'ScannedContractPng',
      PathOnClient = 'ScannedContractPng.png',
      VersionData = Blob.valueOf('fake png content')
    );
    insert pngFile;
    Id pngDocId = [
      SELECT ContentDocumentId
      FROM ContentVersion
      WHERE Id = :pngFile.Id
    ]
    .ContentDocumentId;
    insert new ContentDocumentLink(
      ContentDocumentId = pngDocId,
      LinkedEntityId = parentCase.Id,
      ShareType = 'V'
    );

    ContractReviewFileSelector.Request req = new ContractReviewFileSelector.Request();
    req.caseId = parentCase.Id;

    Test.startTest();
    List<ContractReviewFileSelector.Response> results = ContractReviewFileSelector.getFiles(
      new List<ContractReviewFileSelector.Request>{ req }
    );
    Test.stopTest();

    List<ContentDocument> docs = results[0].contentDocuments;
    // 2 PDFs from setup + 1 JPG + 1 PNG = 4
    System.assertEquals(4, docs.size(), 'Should return 4 files (2 PDFs + JPG + PNG)');

    Set<String> extensions = new Set<String>();
    for (ContentDocument doc : docs) {
      extensions.add(doc.FileExtension);
    }
    System.assert(extensions.contains('jpg'), 'Should include JPG files');
    System.assert(extensions.contains('png'), 'Should include PNG files');
    System.assert(extensions.contains('pdf'), 'Should still include PDF files');
  }
}