@IsTest
private class ContractReviewMetadataSelectorTest {
  // ─── getTemplates ───────────────────────────────────────────────

  @IsTest
  static void getTemplates_returnsNotNull() {
    List<ContractReviewTemplate__mdt> templates = ContractReviewMetadataSelector.getTemplates();

    System.assertNotEquals(
      null,
      templates,
      'getTemplates should return a non-null list'
    );
  }

  @IsTest
  static void getTemplates_orderedByMasterLabel() {
    List<ContractReviewTemplate__mdt> templates = ContractReviewMetadataSelector.getTemplates();

    if (templates.size() < 2) {
      return; // nothing to verify ordering with a single record
    }
    for (Integer i = 1; i < templates.size(); i++) {
      System.assert(
        templates[i].MasterLabel >= templates[i - 1].MasterLabel,
        'Templates should be ordered by MasterLabel'
      );
    }
  }

  @IsTest
  static void getTemplates_fieldsPopulated() {
    List<ContractReviewTemplate__mdt> templates = ContractReviewMetadataSelector.getTemplates();

    for (ContractReviewTemplate__mdt t : templates) {
      System.assertNotEquals(
        null,
        t.DeveloperName,
        'DeveloperName should be populated'
      );
      System.assertNotEquals(
        null,
        t.MasterLabel,
        'MasterLabel should be populated'
      );
    }
  }

  // ─── getCriteria ────────────────────────────────────────────────

  @IsTest
  static void getCriteria_returnsNotNull() {
    List<ContractReviewCriterion__mdt> criteria = ContractReviewMetadataSelector.getCriteria();

    System.assertNotEquals(
      null,
      criteria,
      'getCriteria should return a non-null list'
    );
  }

  @IsTest
  static void getCriteria_orderedBySequence() {
    List<ContractReviewCriterion__mdt> criteria = ContractReviewMetadataSelector.getCriteria();

    if (criteria.size() < 2) {
      return;
    }
    Decimal prevSequence = null;
    for (ContractReviewCriterion__mdt c : criteria) {
      if (c.Sequence__c != null && prevSequence != null) {
        System.assert(
          c.Sequence__c >= prevSequence,
          'Criteria should be ordered by Sequence__c ASC'
        );
      }
      if (c.Sequence__c != null) {
        prevSequence = c.Sequence__c;
      }
    }
  }

  @IsTest
  static void getCriteria_fieldsPopulated() {
    List<ContractReviewCriterion__mdt> criteria = ContractReviewMetadataSelector.getCriteria();

    for (ContractReviewCriterion__mdt c : criteria) {
      System.assertNotEquals(
        null,
        c.DeveloperName,
        'DeveloperName should be populated'
      );
    }
  }

  // ─── getTemplateAssignments ─────────────────────────────────────

  @IsTest
  static void getTemplateAssignments_returnsActiveAndValidShape() {
    // Dynamically find a template instead of hard-coding a DeveloperName
    List<ContractReviewTemplate__mdt> allTemplates = ContractReviewMetadataSelector.getTemplates();

    String templateDevName = allTemplates.isEmpty()
      ? 'NonExistent__Template'
      : allTemplates[0].DeveloperName;

    List<ContractReviewTemplateAssignment__mdt> assignments = ContractReviewMetadataSelector.getTemplateAssignments(
      templateDevName
    );

    System.assertNotEquals(
      null,
      assignments,
      'getTemplateAssignments should return a non-null list'
    );

    for (ContractReviewTemplateAssignment__mdt a : assignments) {
      System.assertEquals(
        true,
        a.IsActive__c,
        'All returned assignments should be active'
      );
      System.assertNotEquals(
        null,
        a.ContractReviewCriterion__r.DeveloperName,
        'Criterion DeveloperName should be populated via relationship'
      );
      System.assertNotEquals(
        null,
        a.ContractReviewCriterion__r.MasterLabel,
        'Criterion MasterLabel should be populated via relationship'
      );
    }
  }

  @IsTest
  static void getTemplateAssignments_unknownTemplate_returnsEmpty() {
    List<ContractReviewTemplateAssignment__mdt> assignments = ContractReviewMetadataSelector.getTemplateAssignments(
      'NonExistent_Template_XYZ'
    );

    System.assertEquals(
      0,
      assignments.size(),
      'Should return empty list for non-existent template'
    );
  }

  @IsTest
  static void getTemplateAssignments_blankInput_returnsEmpty() {
    List<ContractReviewTemplateAssignment__mdt> assignments = ContractReviewMetadataSelector.getTemplateAssignments(
      ''
    );
    System.assertEquals(
      0,
      assignments.size(),
      'Should return empty list for blank input'
    );
  }

  @IsTest
  static void getTemplateAssignments_nullInput_returnsEmpty() {
    List<ContractReviewTemplateAssignment__mdt> assignments = ContractReviewMetadataSelector.getTemplateAssignments(
      null
    );
    System.assertEquals(
      0,
      assignments.size(),
      'Should return empty list for null input'
    );
  }

  // ─── System.runAs coverage ──────────────────────────────────────

  @IsTest
  static void getTemplates_runAsMinimumAccess() {
    Profile minProfile = [
      SELECT Id
      FROM Profile
      WHERE Name = 'Minimum Access - Salesforce'
      LIMIT 1
    ];
    User testUser = new User(
      Alias = 'crtest',
      Email = 'crtest@example.com',
      EmailEncodingKey = 'UTF-8',
      LastName = 'CRTest',
      LanguageLocaleKey = 'en_US',
      LocaleSidKey = 'en_US',
      ProfileId = minProfile.Id,
      TimeZoneSidKey = 'America/New_York',
      UserName = 'crtest.' + System.currentTimeMillis() + '@example.com'
    );
    insert testUser;

    System.runAs(testUser) {
      // CMDT is readable by all users regardless of profile
      List<ContractReviewTemplate__mdt> templates = ContractReviewMetadataSelector.getTemplates();
      System.assertNotEquals(
        null,
        templates,
        'Minimum-access user should read CMDT without exception'
      );
    }
  }
}