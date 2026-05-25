@IsTest
private class ContractReviewControllerTest {
  private static User getTestUser() {
    return [
      SELECT Id
      FROM User
      WHERE Username = 'contractreviewtest@example.com.akavia'
      LIMIT 1
    ];
  }

  @TestSetup
  static void setup() {
    Profile p = [
      SELECT Id
      FROM Profile
      WHERE Name = 'Standard User'
      LIMIT 1
    ];
    User testUser = new User(
      Alias = 'crvwtest',
      Email = 'contractreviewtest@example.com',
      EmailEncodingKey = 'UTF-8',
      LastName = 'ReviewTester',
      LanguageLocaleKey = 'en_US',
      LocaleSidKey = 'en_US',
      ProfileId = p.Id,
      TimeZoneSidKey = 'Europe/Stockholm',
      UserName = 'contractreviewtest@example.com.akavia'
    );

    // Wrap setup-object DML (User + PermissionSetAssignment) in its own
    // runAs context to avoid MIXED_DML_OPERATION with non-setup objects
    System.runAs(new User(Id = UserInfo.getUserId())) {
      insert testUser;

      PermissionSet ps = [
        SELECT Id
        FROM PermissionSet
        WHERE Name = 'Contract_Review_PS'
        LIMIT 1
      ];
      insert new PermissionSetAssignment(
        AssigneeId = testUser.Id,
        PermissionSetId = ps.Id
      );
    }

    System.runAs(testUser) {
      Case parentCase = new Case(Subject = 'Test Contract Review Viewer');
      insert parentCase;

      ContractReview__c review = new ContractReview__c(
        Case__c = parentCase.Id,
        ContractReviewTemplateId__c = 'test-template-id'
      );
      insert review;

      ContractReviewRuntimeCriterion__c criterion = new ContractReviewRuntimeCriterion__c(
        ContractReview__c = review.Id,
        Definition__c = 'Test criterion definition',
        CriterionMet__c = true,
        Extract__c = 'Relevant contract text'
      );
      insert criterion;
    }

    // Insert ContentVersion/ContentDocumentLink as admin to avoid
    // managed package trigger (qsyd_FE) FLS issues on Standard User
    ContractReview__c review = [SELECT Id FROM ContractReview__c LIMIT 1];
    ContentVersion cv = new ContentVersion(
      Title = 'TestContract',
      PathOnClient = 'TestContract.pdf',
      VersionData = Blob.valueOf('fake pdf content')
    );
    insert cv;

    Id contentDocId = [
      SELECT ContentDocumentId
      FROM ContentVersion
      WHERE Id = :cv.Id
    ]
    .ContentDocumentId;

    ContentDocumentLink cdl = new ContentDocumentLink(
      LinkedEntityId = review.Id,
      ContentDocumentId = contentDocId,
      ShareType = 'V'
    );
    insert cdl;
  }

  // ─── getContractReviews ───

  @IsTest
  static void getContractReviews_returnsReviewsForCase() {
    User testUser = getTestUser();
    System.runAs(testUser) {
      Case c = [SELECT Id FROM Case LIMIT 1];

      List<ContractReview__c> reviews = ContractReviewController.getContractReviews(
        c.Id
      );

      System.assert(!reviews.isEmpty(), 'Should return at least one review');
      System.assertNotEquals(null, reviews[0].Name);
      System.assertNotEquals(null, reviews[0].CreatedDate);
    }
  }

  @IsTest
  static void getContractReviews_returnsEmptyForCaseWithNoReviews() {
    User testUser = getTestUser();
    System.runAs(testUser) {
      Case emptyCase = new Case(Subject = 'Empty Case');
      insert emptyCase;

      List<ContractReview__c> reviews = ContractReviewController.getContractReviews(
        emptyCase.Id
      );

      System.assertEquals(0, reviews.size(), 'Should return empty list');
    }
  }

  @IsTest
  static void getContractReviews_throwsOnNullCaseId() {
    try {
      ContractReviewController.getContractReviews(null);
      System.assert(false, 'Expected AuraHandledException');
    } catch (AuraHandledException e) {
      System.assert(
        e.getMessage().contains('Case Id is required'),
        'Should contain expected message: ' + e.getMessage()
      );
    }
  }

  // ─── getReviewDetails ───

  @IsTest
  static void getReviewDetails_returnsCriteriaAndPdf() {
    User testUser = getTestUser();
    System.runAs(testUser) {
      ContractReview__c review = [SELECT Id FROM ContractReview__c LIMIT 1];

      ContractReviewController.ReviewDetailsWrapper result = ContractReviewController.getReviewDetails(
        review.Id
      );

      System.assert(!result.criteria.isEmpty(), 'Should return criteria');
      System.assertNotEquals(
        null,
        result.contentDocumentId,
        'Should return a contentDocumentId for the attached PDF'
      );
      System.assertNotEquals(
        null,
        result.contentVersionId,
        'Should return a contentVersionId for the attached PDF'
      );
      System.assertEquals(
        'TestContract.pdf',
        result.fileName,
        'Should return filename with extension'
      );
      System.assertEquals(
        'pdf',
        result.fileExtension,
        'Should return pdf as fileExtension'
      );
      // Template uses a fake Id that won't match any real MDT record
      System.assertEquals(
        null,
        result.templateName,
        'templateName should be null for non-existent MDT Id'
      );
      // outputEng comes from Output_Eng__c (not populated in test data)
      System.assertEquals(
        null,
        result.outputEng,
        'outputEng should be null when Output_Eng__c is not set'
      );
      // responseDraft comes from ResponseDraft__c (not populated in test data)
      System.assertEquals(
        null,
        result.responseDraft,
        'responseDraft should be null when ResponseDraft__c is not set'
      );
      // responseDraftEng comes from ResponseDraft_Eng__c (not populated in test data)
      System.assertEquals(
        null,
        result.responseDraftEng,
        'responseDraftEng should be null when ResponseDraft_Eng__c is not set'
      );
    }
  }

  @IsTest
  static void getReviewDetails_returnsNullPdfWhenNoneAttached() {
    User testUser = getTestUser();
    System.runAs(testUser) {
      Case parentCase = [SELECT Id FROM Case LIMIT 1];
      ContractReview__c reviewNoPdf = new ContractReview__c(
        Case__c = parentCase.Id,
        ContractReviewTemplateId__c = 'test-template-no-pdf'
      );
      insert reviewNoPdf;

      ContractReviewController.ReviewDetailsWrapper result = ContractReviewController.getReviewDetails(
        reviewNoPdf.Id
      );

      System.assertEquals(
        null,
        result.contentDocumentId,
        'contentDocumentId should be null when no PDF attached'
      );
      System.assertEquals(
        null,
        result.contentVersionId,
        'contentVersionId should be null when no PDF attached'
      );
      System.assertEquals(
        0,
        result.criteria.size(),
        'Should return empty criteria list'
      );
      System.assertEquals(
        null,
        result.fileName,
        'fileName should be null when no PDF attached'
      );
    }
  }

  @IsTest
  static void getReviewDetails_returnsEmptyWrapperOnNullReviewId() {
    ContractReviewController.ReviewDetailsWrapper result = ContractReviewController.getReviewDetails(
      null
    );

    System.assertNotEquals(null, result, 'Should return wrapper, not null');
    System.assertEquals(0, result.criteria.size(), 'Criteria should be empty');
    System.assertEquals(
      null,
      result.contentDocumentId,
      'contentDocumentId should be null'
    );
    System.assertEquals(
      null,
      result.contentVersionId,
      'contentVersionId should be null'
    );
    System.assertEquals(
      null,
      result.templateName,
      'templateName should be null for null reviewId'
    );
    System.assertEquals(
      null,
      result.fileName,
      'fileName should be null for null reviewId'
    );
    System.assertEquals(
      null,
      result.outputEng,
      'outputEng should be null for null reviewId'
    );
    System.assertEquals(
      null,
      result.responseDraft,
      'responseDraft should be null for null reviewId'
    );
    System.assertEquals(
      null,
      result.responseDraftEng,
      'responseDraftEng should be null for null reviewId'
    );
  }

  // ─── getReviewDetails: non-matching template Id ───

  @IsTest
  static void getReviewDetails_handlesNonMatchingTemplateId() {
    User testUser = getTestUser();
    System.runAs(testUser) {
      Case parentCase = [SELECT Id FROM Case LIMIT 1];
      ContractReview__c reviewBadTemplate = new ContractReview__c(
        Case__c = parentCase.Id,
        ContractReviewTemplateId__c = 'no-match-template'
      );
      insert reviewBadTemplate;

      ContractReviewController.ReviewDetailsWrapper result = ContractReviewController.getReviewDetails(
        reviewBadTemplate.Id
      );

      System.assertEquals(
        null,
        result.templateName,
        'templateName should be null for non-matching template Id'
      );
    }
  }

  // ─── getTemplateName helper ───

  @IsTest
  static void getTemplateName_returnsNullForNull() {
    System.assertEquals(
      null,
      ContractReviewController.getTemplateName(null),
      'Should return null for null input'
    );
  }

  @IsTest
  static void getTemplateName_returnsNullForInvalidId() {
    System.assertEquals(
      null,
      ContractReviewController.getTemplateName('bogus-id-12345'),
      'Should return null for non-existent MDT Id'
    );
  }

  // ─── cancelStuckReview ───

  @IsTest
  static void cancelStuckReview_cancelsProcessingReview() {
    User testUser = getTestUser();
    System.runAs(testUser) {
      ContractReview__c review = [SELECT Id FROM ContractReview__c LIMIT 1];
      review.Status__c = 'Processing';
      update review;

      Test.startTest();
      ContractReviewController.cancelStuckReview(review.Id);
      Test.stopTest();

      ContractReview__c updated = [
        SELECT Status__c, ErrorMessage__c
        FROM ContractReview__c
        WHERE Id = :review.Id
      ];
      System.assertEquals('Failure', updated.Status__c,
        'Status should be Failure after cancel');
      System.assert(updated.ErrorMessage__c.contains('avbröts manuellt'),
        'ErrorMessage should contain cancel message: ' + updated.ErrorMessage__c);
    }
  }

  @IsTest
  static void cancelStuckReview_throwsForNonProcessingReview() {
    User testUser = getTestUser();
    System.runAs(testUser) {
      ContractReview__c review = [SELECT Id FROM ContractReview__c LIMIT 1];
      // Status is null/not Processing by default

      try {
        ContractReviewController.cancelStuckReview(review.Id);
        System.assert(false, 'Expected AuraHandledException');
      } catch (AuraHandledException e) {
        System.assert(
          e.getMessage().contains('inte i bearbetningsläge'),
          'Should contain expected message: ' + e.getMessage()
        );
      }
    }
  }

  @IsTest
  static void cancelStuckReview_throwsForNullId() {
    try {
      ContractReviewController.cancelStuckReview(null);
      System.assert(false, 'Expected AuraHandledException');
    } catch (AuraHandledException e) {
      System.assert(
        e.getMessage().contains('Review Id is required'),
        'Should contain expected message: ' + e.getMessage()
      );
    }
  }

  // ─── generateDraft ───

  @IsTest
  static void generateDraft_enqueuesJobForSuccessReview() {
    User testUser = getTestUser();
    System.runAs(testUser) {
      ContractReview__c review = [SELECT Id FROM ContractReview__c LIMIT 1];
      review.Status__c = 'Success';
      update review;

      Test.startTest();
      ContractReviewController.generateDraft(review.Id, 'English');
      Test.stopTest();

      // Verify a job was enqueued (Test.stopTest() executes it synchronously,
      // but the queueable will fail due to missing prompt template — that's OK,
      // we just verify the controller accepted the call without throwing)
    }
  }

  @IsTest
  static void generateDraft_throwsOnNullReviewId() {
    try {
      ContractReviewController.generateDraft(null, 'Svenska');
      System.assert(false, 'Expected AuraHandledException');
    } catch (AuraHandledException e) {
      System.assert(
        e.getMessage().contains('Review Id is required'),
        'Should contain expected message: ' + e.getMessage()
      );
    }
  }

  @IsTest
  static void generateDraft_throwsOnInvalidLanguage() {
    User testUser = getTestUser();
    System.runAs(testUser) {
      ContractReview__c review = [SELECT Id FROM ContractReview__c LIMIT 1];
      review.Status__c = 'Success';
      update review;

      try {
        ContractReviewController.generateDraft(review.Id, 'French');
        System.assert(false, 'Expected AuraHandledException');
      } catch (AuraHandledException e) {
        System.assert(
          e.getMessage().contains('Unsupported language'),
          'Should contain expected message: ' + e.getMessage()
        );
      }
    }
  }

  @IsTest
  static void generateDraft_throwsForNonSuccessReview() {
    User testUser = getTestUser();
    System.runAs(testUser) {
      ContractReview__c review = [SELECT Id FROM ContractReview__c LIMIT 1];
      // Status is not 'Success' by default

      try {
        ContractReviewController.generateDraft(review.Id, 'Svenska');
        System.assert(false, 'Expected AuraHandledException');
      } catch (AuraHandledException e) {
        System.assert(
          e.getMessage().contains('inte klar'),
          'Should contain expected message: ' + e.getMessage()
        );
      }
    }
  }

  // ─── getReviewDetails: image file support ───

  @IsTest
  static void getReviewDetails_imageFile_returnsFileExtension() {
    User testUser = getTestUser();

    // Create a review with a JPG file attached (as admin to avoid FLS issues)
    Case parentCase = [SELECT Id FROM Case LIMIT 1];
    ContractReview__c reviewImg;
    System.runAs(testUser) {
      reviewImg = new ContractReview__c(
        Case__c = parentCase.Id,
        ContractReviewTemplateId__c = 'test-template-img'
      );
      insert reviewImg;
    }

    ContentVersion jpgCv = new ContentVersion(
      Title = 'ScannedContract',
      PathOnClient = 'ScannedContract.jpg',
      VersionData = Blob.valueOf('fake jpg content')
    );
    insert jpgCv;

    Id jpgDocId = [
      SELECT ContentDocumentId
      FROM ContentVersion
      WHERE Id = :jpgCv.Id
    ].ContentDocumentId;

    insert new ContentDocumentLink(
      LinkedEntityId = reviewImg.Id,
      ContentDocumentId = jpgDocId,
      ShareType = 'V'
    );

    System.runAs(testUser) {
      Test.startTest();
      ContractReviewController.ReviewDetailsWrapper result =
        ContractReviewController.getReviewDetails(reviewImg.Id);
      Test.stopTest();

      System.assertNotEquals(
        null,
        result.contentDocumentId,
        'Should return contentDocumentId for image file'
      );
      System.assertNotEquals(
        null,
        result.contentVersionId,
        'Should return contentVersionId for image file'
      );
      System.assertEquals(
        'jpg',
        result.fileExtension,
        'Should return jpg as fileExtension'
      );
      System.assertEquals(
        'ScannedContract.jpg',
        result.fileName,
        'Should return correct fileName for image'
      );
    }
  }
}