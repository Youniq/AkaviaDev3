@IsTest
private class ContractReviewCriterionSelectorTest {
  @TestSetup
  static void setup() {
    Case parentCase = new Case(Subject = 'Test Criterion Selector');
    insert parentCase;

    ContractReview__c review = new ContractReview__c(
      Case__c = parentCase.Id,
      ContractReviewTemplateId__c = 'test-template-id'
    );
    insert review;

    List<ContractReviewRuntimeCriterion__c> criteria = new List<ContractReviewRuntimeCriterion__c>{
      new ContractReviewRuntimeCriterion__c(
        Name = 'A - First Criterion',
        Definition__c = 'First definition text',
        ContractReview__c = review.Id,
        Sequence__c = 20
      ),
      new ContractReviewRuntimeCriterion__c(
        Name = 'B - Second Criterion',
        Definition__c = 'Second definition text',
        ContractReview__c = review.Id,
        Sequence__c = 10
      )
    };
    insert criteria;
  }

  @IsTest
  static void getCriteria_validReview_returnsSerializedJson() {
    ContractReview__c review = [SELECT Id FROM ContractReview__c LIMIT 1];

    ContractReviewCriterionSelector.Request req = new ContractReviewCriterionSelector.Request();
    req.contractReviewId = review.Id;

    Test.startTest();
    List<ContractReviewCriterionSelector.Response> results = ContractReviewCriterionSelector.getCriteria(
      new List<ContractReviewCriterionSelector.Request>{ req }
    );
    Test.stopTest();

    System.assertEquals(
      1,
      results.size(),
      'Should return one response for one request'
    );
    String prompt = results[0].Prompt;
    System.assertNotEquals(null, prompt, 'Prompt should not be null');
    System.assertNotEquals('[]', prompt, 'Prompt should not be empty array');

    List<Object> parsed = (List<Object>) JSON.deserializeUntyped(prompt);
    System.assertEquals(2, parsed.size(), 'Should contain 2 criteria');

    Map<String, Object> first = (Map<String, Object>) parsed[0];
    System.assertEquals(
      'B - Second Criterion',
      first.get('Name'),
      'B criterion (Sequence 10) should come first (ORDER BY Sequence__c)'
    );
    System.assertNotEquals(
      null,
      first.get('Definition__c'),
      'Definition__c should be present'
    );
    System.assertNotEquals(null, first.get('Id'), 'Id should be present');

    Map<String, Object> second = (Map<String, Object>) parsed[1];
    System.assertEquals(
      'A - First Criterion',
      second.get('Name'),
      'A criterion (Sequence 20) should come second'
    );
  }

  @IsTest
  static void getCriteria_reviewWithNoCriteria_returnsEmptyJsonArray() {
    Case parentCase = [SELECT Id FROM Case LIMIT 1];
    ContractReview__c emptyReview = new ContractReview__c(
      Case__c = parentCase.Id,
      ContractReviewTemplateId__c = 'empty-template'
    );
    insert emptyReview;

    ContractReviewCriterionSelector.Request req = new ContractReviewCriterionSelector.Request();
    req.contractReviewId = emptyReview.Id;

    Test.startTest();
    List<ContractReviewCriterionSelector.Response> results = ContractReviewCriterionSelector.getCriteria(
      new List<ContractReviewCriterionSelector.Request>{ req }
    );
    Test.stopTest();

    System.assertEquals(1, results.size(), 'Should return one response');
    System.assertEquals(
      '[]',
      results[0].Prompt,
      'Prompt should be empty JSON array when no criteria exist'
    );
  }

  @IsTest
  static void getCriteria_nullId_returnsEmptyJsonArray() {
    ContractReviewCriterionSelector.Request req = new ContractReviewCriterionSelector.Request();
    req.contractReviewId = null;

    Test.startTest();
    List<ContractReviewCriterionSelector.Response> results = ContractReviewCriterionSelector.getCriteria(
      new List<ContractReviewCriterionSelector.Request>{ req }
    );
    Test.stopTest();

    System.assertEquals(1, results.size(), 'Should return one response');
    System.assertEquals(
      '[]',
      results[0].Prompt,
      'Prompt should be empty JSON array for null review'
    );
  }

  @IsTest
  static void getCriteria_emptyRequestList_returnsEmptyList() {
    Test.startTest();
    List<ContractReviewCriterionSelector.Response> results = ContractReviewCriterionSelector.getCriteria(
      new List<ContractReviewCriterionSelector.Request>()
    );
    Test.stopTest();

    System.assertEquals(
      0,
      results.size(),
      'Should return empty list for empty input'
    );
  }

  @IsTest
  static void getCriteria_bulkRequests_usesOneQuery() {
    Case parentCase = [SELECT Id FROM Case LIMIT 1];
    ContractReview__c existingReview = [SELECT Id FROM ContractReview__c LIMIT 1];

    ContractReview__c secondReview = new ContractReview__c(
      Case__c = parentCase.Id,
      ContractReviewTemplateId__c = 'second-template'
    );
    insert secondReview;

    List<ContractReviewRuntimeCriterion__c> secondCriteria = new List<ContractReviewRuntimeCriterion__c>{
      new ContractReviewRuntimeCriterion__c(
        Name = 'C - Third Criterion',
        Definition__c = 'Third definition text',
        ContractReview__c = secondReview.Id
      )
    };
    insert secondCriteria;

    ContractReviewCriterionSelector.Request req1 = new ContractReviewCriterionSelector.Request();
    req1.contractReviewId = existingReview.Id;

    ContractReviewCriterionSelector.Request req2 = new ContractReviewCriterionSelector.Request();
    req2.contractReviewId = secondReview.Id;

    ContractReviewCriterionSelector.Request req3 = new ContractReviewCriterionSelector.Request();
    req3.contractReviewId = null;

    Test.startTest();
    Integer queriesBefore = Limits.getQueries();
    List<ContractReviewCriterionSelector.Response> results = ContractReviewCriterionSelector.getCriteria(
      new List<ContractReviewCriterionSelector.Request>{ req1, req2, req3 }
    );
    Integer queriesUsed = Limits.getQueries() - queriesBefore;
    Test.stopTest();

    System.assertEquals(3, results.size(), 'Should return three responses');

    List<Object> parsed1 = (List<Object>) JSON.deserializeUntyped(results[0].Prompt);
    System.assertEquals(2, parsed1.size(), 'First review should have 2 criteria');

    List<Object> parsed2 = (List<Object>) JSON.deserializeUntyped(results[1].Prompt);
    System.assertEquals(1, parsed2.size(), 'Second review should have 1 criterion');

    Map<String, Object> thirdCriterion = (Map<String, Object>) parsed2[0];
    System.assertEquals('C - Third Criterion', thirdCriterion.get('Name'), 'Should return correct criterion for second review');

    System.assertEquals('[]', results[2].Prompt, 'Null id should return empty JSON array');

    System.assertEquals(1, queriesUsed, 'Should use exactly 1 SOQL query regardless of request count');
  }
}