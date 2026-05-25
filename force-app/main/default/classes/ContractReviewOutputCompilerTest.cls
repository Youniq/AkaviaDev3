@IsTest
private class ContractReviewOutputCompilerTest {
  @TestSetup
  static void setup() {
    Case parentCase = new Case(Subject = 'Test Output Compiler');
    insert parentCase;

    ContractReview__c review = new ContractReview__c(
      Case__c = parentCase.Id,
      ContractReviewTemplateId__c = 'test-template-id'
    );
    insert review;

    // Use fabricated MDT Ids so runtime criteria are always created,
    // regardless of whether real ContractReviewCriterion__mdt records
    // exist in the org. This ensures compileOutput() code path coverage.
    String mdtPrefix = ContractReviewCriterion__mdt.SObjectType.getDescribe()
      .getKeyPrefix();
    Id fakeMdtId1 = Id.valueOf(mdtPrefix + '000000000001');
    Id fakeMdtId2 = Id.valueOf(mdtPrefix + '000000000002');

    List<ContractReviewRuntimeCriterion__c> criteria = new List<ContractReviewRuntimeCriterion__c>{
      new ContractReviewRuntimeCriterion__c(
        ContractReview__c = review.Id,
        ContractReviewCriterionId__c = fakeMdtId1,
        CriterionMet__c = true
      ),
      new ContractReviewRuntimeCriterion__c(
        ContractReview__c = review.Id,
        ContractReviewCriterionId__c = fakeMdtId2,
        CriterionMet__c = false
      )
    };
    insert criteria;
  }

  // ─── buildOutputMap unit tests ───

  /**
   * Verifies that when isSwedish=true, buildOutputMap selects Output_When_True_sv__c
   * for met criteria and Output_When_False_sv__c for unmet criteria, concatenating
   * them with a double linebreak separator.
   */
  @IsTest
  static void buildOutputMap_swedish_returnsCorrectOutputs() {
    Id fakeReviewId =
      ContractReview__c.SObjectType.getDescribe().getKeyPrefix() +
      '000000000001';
    Id fakeMdtId1 =
      ContractReviewCriterion__mdt.SObjectType.getDescribe().getKeyPrefix() +
      '000000000001';
    Id fakeMdtId2 =
      ContractReviewCriterion__mdt.SObjectType.getDescribe().getKeyPrefix() +
      '000000000002';

    Map<Id, ContractReviewCriterion__mdt> mdtMap = new Map<Id, ContractReviewCriterion__mdt>{
      fakeMdtId1 => (ContractReviewCriterion__mdt) JSON.deserialize(
        '{' +
          '"Id":"' +
          fakeMdtId1 +
          '",' +
          '"MasterLabel":"Criterion1",' +
          '"Output_When_True_sv__c":"Sv True 1",' +
          '"Output_When_False_sv__c":"Sv False 1",' +
          '"Output_When_True_Eng__c":"Eng True 1",' +
          '"Output_When_False_Eng__c":"Eng False 1"' +
          '}',
        ContractReviewCriterion__mdt.class
      ),
      fakeMdtId2 => (ContractReviewCriterion__mdt) JSON.deserialize(
        '{' +
          '"Id":"' +
          fakeMdtId2 +
          '",' +
          '"MasterLabel":"Criterion2",' +
          '"Output_When_True_sv__c":"Sv True 2",' +
          '"Output_When_False_sv__c":"Sv False 2",' +
          '"Output_When_True_Eng__c":"Eng True 2",' +
          '"Output_When_False_Eng__c":"Eng False 2"' +
          '}',
        ContractReviewCriterion__mdt.class
      )
    };

    List<ContractReviewRuntimeCriterion__c> criteria = new List<ContractReviewRuntimeCriterion__c>{
      (ContractReviewRuntimeCriterion__c) JSON.deserialize(
        '{' +
          '"ContractReview__c":"' +
          fakeReviewId +
          '",' +
          '"ContractReviewCriterionId__c":"' +
          fakeMdtId1 +
          '",' +
          '"CriterionMet__c":true' +
          '}',
        ContractReviewRuntimeCriterion__c.class
      ),
      (ContractReviewRuntimeCriterion__c) JSON.deserialize(
        '{' +
          '"ContractReview__c":"' +
          fakeReviewId +
          '",' +
          '"ContractReviewCriterionId__c":"' +
          fakeMdtId2 +
          '",' +
          '"CriterionMet__c":false' +
          '}',
        ContractReviewRuntimeCriterion__c.class
      )
    };

    Map<Id, String> result = ContractReviewOutputCompiler.buildOutputMap(
      criteria,
      mdtMap,
      true
    );

    System.assertEquals(1, result.size());
    String output = result.get(fakeReviewId);
    System.assert(
      output.contains('Criterion1'),
      'Should contain heading for criterion 1'
    );
    System.assert(
      output.contains('Sv True 1'),
      'Should contain true output for criterion 1'
    );
    System.assert(
      output.contains('Criterion2'),
      'Should contain heading for criterion 2'
    );
    System.assert(
      output.contains('Sv False 2'),
      'Should contain false output for criterion 2'
    );
    System.assert(
      output.contains('\n\n'),
      'Should be separated by double linebreak'
    );
  }

  /**
   * Verifies that when isSwedish=false, buildOutputMap selects Output_When_True_Eng__c
   * for met criteria, returning the English output string.
   */
  @IsTest
  static void buildOutputMap_english_returnsCorrectOutputs() {
    Id fakeReviewId =
      ContractReview__c.SObjectType.getDescribe().getKeyPrefix() +
      '000000000001';
    Id fakeMdtId1 =
      ContractReviewCriterion__mdt.SObjectType.getDescribe().getKeyPrefix() +
      '000000000001';

    Map<Id, ContractReviewCriterion__mdt> mdtMap = new Map<Id, ContractReviewCriterion__mdt>{
      fakeMdtId1 => (ContractReviewCriterion__mdt) JSON.deserialize(
        '{"Id":"' +
          fakeMdtId1 +
          '","MasterLabel":"EngCriterion","Output_When_True_sv__c":"Sv True","Output_When_False_sv__c":"Sv False","Output_When_True_Eng__c":"Eng True","Output_When_False_Eng__c":"Eng False"}',
        ContractReviewCriterion__mdt.class
      )
    };

    List<ContractReviewRuntimeCriterion__c> criteria = new List<ContractReviewRuntimeCriterion__c>{
      (ContractReviewRuntimeCriterion__c) JSON.deserialize(
        '{"ContractReview__c":"' +
          fakeReviewId +
          '","ContractReviewCriterionId__c":"' +
          fakeMdtId1 +
          '","CriterionMet__c":true}',
        ContractReviewRuntimeCriterion__c.class
      )
    };

    Map<Id, String> result = ContractReviewOutputCompiler.buildOutputMap(
      criteria,
      mdtMap,
      false
    );

    System.assert(result.get(fakeReviewId).contains('Eng True'), 'Should contain English true output');
    System.assert(result.get(fakeReviewId).contains('EngCriterion'), 'Should contain criterion name heading');
  }

  /**
   * Verifies that when a metadata record has a blank output field for the
   * selected language and met/unmet branch, that entry is excluded from
   * the concatenated result rather than producing an empty segment.
   */
  @IsTest
  static void buildOutputMap_blankOutput_skipped() {
    Id fakeReviewId =
      ContractReview__c.SObjectType.getDescribe().getKeyPrefix() +
      '000000000001';
    Id fakeMdtId1 =
      ContractReviewCriterion__mdt.SObjectType.getDescribe().getKeyPrefix() +
      '000000000001';
    Id fakeMdtId2 =
      ContractReviewCriterion__mdt.SObjectType.getDescribe().getKeyPrefix() +
      '000000000002';

    Map<Id, ContractReviewCriterion__mdt> mdtMap = new Map<Id, ContractReviewCriterion__mdt>{
      fakeMdtId1 => (ContractReviewCriterion__mdt) JSON.deserialize(
        '{"Id":"' +
          fakeMdtId1 +
          '","MasterLabel":"BlankCrit1","Output_When_True_sv__c":"Sv True 1","Output_When_False_sv__c":"Sv False 1"}',
        ContractReviewCriterion__mdt.class
      ),
      fakeMdtId2 => (ContractReviewCriterion__mdt) JSON.deserialize(
        '{"Id":"' +
          fakeMdtId2 +
          '","MasterLabel":"BlankCrit2","Output_When_True_sv__c":"","Output_When_False_sv__c":""}',
        ContractReviewCriterion__mdt.class
      )
    };

    List<ContractReviewRuntimeCriterion__c> criteria = new List<ContractReviewRuntimeCriterion__c>{
      (ContractReviewRuntimeCriterion__c) JSON.deserialize(
        '{"ContractReview__c":"' +
          fakeReviewId +
          '","ContractReviewCriterionId__c":"' +
          fakeMdtId1 +
          '","CriterionMet__c":true}',
        ContractReviewRuntimeCriterion__c.class
      ),
      (ContractReviewRuntimeCriterion__c) JSON.deserialize(
        '{"ContractReview__c":"' +
          fakeReviewId +
          '","ContractReviewCriterionId__c":"' +
          fakeMdtId2 +
          '","CriterionMet__c":true}',
        ContractReviewRuntimeCriterion__c.class
      )
    };

    Map<Id, String> result = ContractReviewOutputCompiler.buildOutputMap(
      criteria,
      mdtMap,
      true
    );

    System.assert(
      result.get(fakeReviewId).contains('Sv True 1'),
      'Blank output should be skipped, non-blank should remain'
    );
    System.assert(
      !result.get(fakeReviewId).contains('BlankCrit2'),
      'Criterion with blank output should not appear'
    );
  }

  /**
   * Verifies that a runtime criterion whose ContractReviewCriterionId__c
   * does not match any entry in the metadata map is silently skipped,
   * producing an empty result rather than throwing an exception.
   */
  @IsTest
  static void buildOutputMap_nullMdt_skipped() {
    Id fakeReviewId =
      ContractReview__c.SObjectType.getDescribe().getKeyPrefix() +
      '000000000001';
    Id fakeMdtId1 =
      ContractReviewCriterion__mdt.SObjectType.getDescribe().getKeyPrefix() +
      '000000000099';

    Map<Id, ContractReviewCriterion__mdt> mdtMap = new Map<Id, ContractReviewCriterion__mdt>();

    List<ContractReviewRuntimeCriterion__c> criteria = new List<ContractReviewRuntimeCriterion__c>{
      (ContractReviewRuntimeCriterion__c) JSON.deserialize(
        '{"ContractReview__c":"' +
          fakeReviewId +
          '","ContractReviewCriterionId__c":"' +
          fakeMdtId1 +
          '","CriterionMet__c":true}',
        ContractReviewRuntimeCriterion__c.class
      )
    };

    Map<Id, String> result = ContractReviewOutputCompiler.buildOutputMap(
      criteria,
      mdtMap,
      true
    );

    System.assertEquals(
      0,
      result.size(),
      'Missing mdt should be silently skipped'
    );
  }

  // ─── compileOutput integration tests ───

  /**
   * End-to-end test: invokes compileOutput with runtime criteria that
   * reference fabricated MDT Ids. Exercises the full code path (SOQL,
   * mdtIds loop, MDT query, buildOutputMap, DML) without depending on
   * real ContractReviewCriterion__mdt records in the org.
   *
   * Output logic correctness is validated by the buildOutputMap unit tests.
   */
  @IsTest
  static void compileOutput_endToEnd_completesWithoutError() {
    ContractReview__c review = [SELECT Id FROM ContractReview__c LIMIT 1];

    Test.startTest();
    ContractReviewOutputCompiler.compileOutput(new List<Id>{ review.Id });
    Test.stopTest();

    // With fabricated MDT Ids the MDT query returns empty, so outputs are null.
    ContractReview__c updated = [
      SELECT Output_Sv__c, Output_Eng__c
      FROM ContractReview__c
      WHERE Id = :review.Id
    ];
    System.assertEquals(
      null,
      updated.Output_Sv__c,
      'Output should be null when MDT records do not match'
    );
    System.assertEquals(
      null,
      updated.Output_Eng__c,
      'Output should be null when MDT records do not match'
    );
  }

  /**
   * Verifies that calling the invocable method with an empty list
   * returns cleanly without error or DML, covering the early-exit guard.
   */
  @IsTest
  static void compileOutput_emptyList_noError() {
    ContractReviewOutputCompiler.compileOutput(new List<Id>());
  }

  /**
   * Verifies that a ContractReview__c with no related runtime criteria
   * is handled gracefully — the method early-exits and both output
   * fields remain null on the record.
   */
  @IsTest
  static void compileOutput_noRuntimeCriteria_noError() {
    Case parentCase = new Case(Subject = 'Test No Criteria');
    insert parentCase;
    ContractReview__c review = new ContractReview__c(
      Case__c = parentCase.Id,
      ContractReviewTemplateId__c = 'test-template-id'
    );
    insert review;

    Test.startTest();
    ContractReviewOutputCompiler.compileOutput(new List<Id>{ review.Id });
    Test.stopTest();

    ContractReview__c updated = [
      SELECT Output_Sv__c, Output_Eng__c
      FROM ContractReview__c
      WHERE Id = :review.Id
    ];
    System.assertEquals(
      null,
      updated.Output_Sv__c,
      'Swedish output should remain null'
    );
    System.assertEquals(
      null,
      updated.Output_Eng__c,
      'English output should remain null'
    );
  }

  // ─── resolveHeading / Display Title tests ───

  @IsTest
  static void buildOutputMap_displayTitlePopulated_usedAsHeading() {
    Id fakeReviewId =
      ContractReview__c.SObjectType.getDescribe().getKeyPrefix() +
      '000000000001';
    Id fakeMdtId1 =
      ContractReviewCriterion__mdt.SObjectType.getDescribe().getKeyPrefix() +
      '000000000001';

    Map<Id, ContractReviewCriterion__mdt> mdtMap = new Map<Id, ContractReviewCriterion__mdt>{
      fakeMdtId1 => (ContractReviewCriterion__mdt) JSON.deserialize(
        '{"Id":"' + fakeMdtId1 + '","MasterLabel":"OriginalName","Display_Title__c":"Svensk Titel","Output_When_True_sv__c":"Sv True","Output_When_False_sv__c":"Sv False"}',
        ContractReviewCriterion__mdt.class
      )
    };

    List<ContractReviewRuntimeCriterion__c> criteria = new List<ContractReviewRuntimeCriterion__c>{
      (ContractReviewRuntimeCriterion__c) JSON.deserialize(
        '{"ContractReview__c":"' + fakeReviewId + '","ContractReviewCriterionId__c":"' + fakeMdtId1 + '","CriterionMet__c":true}',
        ContractReviewRuntimeCriterion__c.class
      )
    };

    Map<Id, String> result = ContractReviewOutputCompiler.buildOutputMap(criteria, mdtMap, true);

    String output = result.get(fakeReviewId);
    System.assert(output.contains('Svensk Titel'), 'Swedish display title should be used as heading');
    System.assert(!output.contains('OriginalName'), 'MasterLabel should NOT appear when display title is populated');
  }

  @IsTest
  static void buildOutputMap_displayTitleEngPopulated_usedAsHeading() {
    Id fakeReviewId =
      ContractReview__c.SObjectType.getDescribe().getKeyPrefix() +
      '000000000001';
    Id fakeMdtId1 =
      ContractReviewCriterion__mdt.SObjectType.getDescribe().getKeyPrefix() +
      '000000000001';

    Map<Id, ContractReviewCriterion__mdt> mdtMap = new Map<Id, ContractReviewCriterion__mdt>{
      fakeMdtId1 => (ContractReviewCriterion__mdt) JSON.deserialize(
        '{"Id":"' + fakeMdtId1 + '","MasterLabel":"OriginalName","Display_Title_Eng__c":"English Title","Output_When_True_Eng__c":"Eng True","Output_When_False_Eng__c":"Eng False"}',
        ContractReviewCriterion__mdt.class
      )
    };

    List<ContractReviewRuntimeCriterion__c> criteria = new List<ContractReviewRuntimeCriterion__c>{
      (ContractReviewRuntimeCriterion__c) JSON.deserialize(
        '{"ContractReview__c":"' + fakeReviewId + '","ContractReviewCriterionId__c":"' + fakeMdtId1 + '","CriterionMet__c":true}',
        ContractReviewRuntimeCriterion__c.class
      )
    };

    Map<Id, String> result = ContractReviewOutputCompiler.buildOutputMap(criteria, mdtMap, false);

    String output = result.get(fakeReviewId);
    System.assert(output.contains('English Title'), 'English display title should be used as heading');
    System.assert(!output.contains('OriginalName'), 'MasterLabel should NOT appear when display title is populated');
  }

  @IsTest
  static void buildOutputMap_displayTitleBlank_fallsBackToMasterLabel() {
    Id fakeReviewId =
      ContractReview__c.SObjectType.getDescribe().getKeyPrefix() +
      '000000000001';
    Id fakeMdtId1 =
      ContractReviewCriterion__mdt.SObjectType.getDescribe().getKeyPrefix() +
      '000000000001';

    Map<Id, ContractReviewCriterion__mdt> mdtMap = new Map<Id, ContractReviewCriterion__mdt>{
      fakeMdtId1 => (ContractReviewCriterion__mdt) JSON.deserialize(
        '{"Id":"' + fakeMdtId1 + '","MasterLabel":"FallbackName","Display_Title__c":"","Display_Title_Eng__c":"","Output_When_True_sv__c":"Sv True","Output_When_True_Eng__c":"Eng True"}',
        ContractReviewCriterion__mdt.class
      )
    };

    List<ContractReviewRuntimeCriterion__c> criteria = new List<ContractReviewRuntimeCriterion__c>{
      (ContractReviewRuntimeCriterion__c) JSON.deserialize(
        '{"ContractReview__c":"' + fakeReviewId + '","ContractReviewCriterionId__c":"' + fakeMdtId1 + '","CriterionMet__c":true}',
        ContractReviewRuntimeCriterion__c.class
      )
    };

    Map<Id, String> svResult = ContractReviewOutputCompiler.buildOutputMap(criteria, mdtMap, true);
    Map<Id, String> engResult = ContractReviewOutputCompiler.buildOutputMap(criteria, mdtMap, false);

    System.assert(svResult.get(fakeReviewId).contains('FallbackName'), 'Swedish heading should fall back to MasterLabel when display title is blank');
    System.assert(engResult.get(fakeReviewId).contains('FallbackName'), 'English heading should fall back to MasterLabel when display title is blank');
  }

  @IsTest
  static void buildOutputMap_displayTitleWhitespace_fallsBackToMasterLabel() {
    Id fakeReviewId =
      ContractReview__c.SObjectType.getDescribe().getKeyPrefix() +
      '000000000001';
    Id fakeMdtId1 =
      ContractReviewCriterion__mdt.SObjectType.getDescribe().getKeyPrefix() +
      '000000000001';

    Map<Id, ContractReviewCriterion__mdt> mdtMap = new Map<Id, ContractReviewCriterion__mdt>{
      fakeMdtId1 => (ContractReviewCriterion__mdt) JSON.deserialize(
        '{"Id":"' + fakeMdtId1 + '","MasterLabel":"WhitespaceFallback","Display_Title__c":"   ","Output_When_True_sv__c":"Sv True"}',
        ContractReviewCriterion__mdt.class
      )
    };

    List<ContractReviewRuntimeCriterion__c> criteria = new List<ContractReviewRuntimeCriterion__c>{
      (ContractReviewRuntimeCriterion__c) JSON.deserialize(
        '{"ContractReview__c":"' + fakeReviewId + '","ContractReviewCriterionId__c":"' + fakeMdtId1 + '","CriterionMet__c":true}',
        ContractReviewRuntimeCriterion__c.class
      )
    };

    Map<Id, String> result = ContractReviewOutputCompiler.buildOutputMap(criteria, mdtMap, true);

    System.assert(result.get(fakeReviewId).contains('WhitespaceFallback'), 'Whitespace-only display title should fall back to MasterLabel');
  }

  @IsTest
  static void buildOutputMap_mixedDisplayTitles_perLanguageFallback() {
    Id fakeReviewId =
      ContractReview__c.SObjectType.getDescribe().getKeyPrefix() +
      '000000000001';
    Id fakeMdtId1 =
      ContractReviewCriterion__mdt.SObjectType.getDescribe().getKeyPrefix() +
      '000000000001';

    Map<Id, ContractReviewCriterion__mdt> mdtMap = new Map<Id, ContractReviewCriterion__mdt>{
      fakeMdtId1 => (ContractReviewCriterion__mdt) JSON.deserialize(
        '{"Id":"' + fakeMdtId1 + '","MasterLabel":"MixedFallback","Display_Title__c":"Svensk Rubrik","Display_Title_Eng__c":"","Output_When_True_sv__c":"Sv True","Output_When_True_Eng__c":"Eng True"}',
        ContractReviewCriterion__mdt.class
      )
    };

    List<ContractReviewRuntimeCriterion__c> criteria = new List<ContractReviewRuntimeCriterion__c>{
      (ContractReviewRuntimeCriterion__c) JSON.deserialize(
        '{"ContractReview__c":"' + fakeReviewId + '","ContractReviewCriterionId__c":"' + fakeMdtId1 + '","CriterionMet__c":true}',
        ContractReviewRuntimeCriterion__c.class
      )
    };

    Map<Id, String> svResult = ContractReviewOutputCompiler.buildOutputMap(criteria, mdtMap, true);
    Map<Id, String> engResult = ContractReviewOutputCompiler.buildOutputMap(criteria, mdtMap, false);

    System.assert(svResult.get(fakeReviewId).contains('Svensk Rubrik'), 'Swedish output should use populated display title');
    System.assert(!svResult.get(fakeReviewId).contains('MixedFallback'), 'Swedish output should NOT contain MasterLabel when display title is set');
    System.assert(engResult.get(fakeReviewId).contains('MixedFallback'), 'English output should fall back to MasterLabel when English display title is empty');
    System.assert(!engResult.get(fakeReviewId).contains('Svensk Rubrik'), 'English output should NOT contain Swedish display title');
  }
}