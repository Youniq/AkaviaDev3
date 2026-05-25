@IsTest
private class ContractReviewParserTest {

    private static final Id FAKE_RESULT_ID = '001000000000001AAA';

    @TestSetup
    static void setup() {
        Case parentCase = new Case(Subject = 'Test Contract Review');
        insert parentCase;
        ContractReview__c review = new ContractReview__c(
            Case__c = parentCase.Id,
            ContractReviewTemplateId__c = 'test-template-id'
        );
        insert review;
        ContractReviewRuntimeCriterion__c criterion = new ContractReviewRuntimeCriterion__c(
            ContractReview__c = review.Id
        );
        insert criterion;
    }

    // ─── parseJSON unit tests (no DML) ───

    /**
     * Verifies that well-formed JSON with multiple entries is correctly deserialized
     * into a Map keyed by criterion Id, with all fields (met, extract) mapped accurately.
     */
    @IsTest
    static void parseJSON_validJSON_returnsMap() {
        String validId1 = '001000000000011AAA';
        String validId2 = '001000000000012AAA';
        String jsonBody = JSON.serialize(new List<Map<String, Object>>{
            new Map<String, Object>{ 'recordId' => validId1, 'met' => true, 'extract' => 'clause found', 'aicomment' => 'Criterion satisfied per section 3' },
            new Map<String, Object>{ 'recordId' => validId2, 'met' => false, 'extract' => 'not found', 'aicomment' => 'No matching clause in contract' }
        });

        Map<Id, ContractReviewParser.ParsedCriterion> result = ContractReviewParser.parseJSON(FAKE_RESULT_ID, jsonBody);

        System.assertEquals(2, result.size());
        System.assertEquals(true, result.get(Id.valueOf(validId1)).met);
        System.assertEquals('clause found', result.get(Id.valueOf(validId1)).extract);
        System.assertEquals('Criterion satisfied per section 3', result.get(Id.valueOf(validId1)).aicomment);
        System.assertEquals(false, result.get(Id.valueOf(validId2)).met);
        System.assertEquals('not found', result.get(Id.valueOf(validId2)).extract);
        System.assertEquals('No matching clause in contract', result.get(Id.valueOf(validId2)).aicomment);
    }

    /**
     * Verifies that unparseable JSON (not valid JSON syntax) throws a
     * ContractReviewParserException so the flow can route to a fault path.
     */
    @IsTest
    static void parseJSON_malformedJSON_throwsException() {
        try {
            ContractReviewParser.parseJSON(FAKE_RESULT_ID, 'not valid json');
            System.assert(false, 'Expected ContractReviewParserException');
        } catch (ContractReviewParser.ContractReviewParserException e) {
            System.assert(e.getMessage().contains('Failed to parse JSON'));
        }
    }

    /**
     * Verifies that a JSON entry with a blank recordId throws an exception.
     * A blank recordId indicates malformed AI output — the criterion can never
     * be matched, so failing loudly is preferable to silently skipping it.
     */
    @IsTest
    static void parseJSON_blankRecordId_throwsException() {
        String jsonBody = '[{"recordId":"","met":true,"extract":"text"}]';

        try {
            ContractReviewParser.parseJSON(FAKE_RESULT_ID, jsonBody);
            System.assert(false, 'Expected ContractReviewParserException');
        } catch (ContractReviewParser.ContractReviewParserException e) {
            System.assert(e.getMessage().contains('Missing recordId'));
        }
    }

    /**
     * Verifies that a JSON entry with a null recordId throws an exception.
     * Uses a raw JSON string to guarantee the null is preserved during
     * deserialization (JSON.serialize may omit null-valued keys).
     */
    @IsTest
    static void parseJSON_nullRecordId_throwsException() {
        String jsonBody = '[{"recordId":null,"met":true,"extract":"text"}]';

        try {
            ContractReviewParser.parseJSON(FAKE_RESULT_ID, jsonBody);
            System.assert(false, 'Expected ContractReviewParserException');
        } catch (ContractReviewParser.ContractReviewParserException e) {
            System.assert(e.getMessage().contains('Missing recordId'));
        }
    }

    /**
     * Verifies that a recordId which is not a valid Salesforce Id format
     * throws an exception, ensuring corrupt data from the AI response
     * does not propagate silently.
     */
    @IsTest
    static void parseJSON_invalidRecordId_throwsException() {
        String jsonBody = JSON.serialize(new List<Map<String, Object>>{
            new Map<String, Object>{ 'recordId' => 'NOT_AN_ID', 'met' => true, 'extract' => 'text' }
        });

        try {
            ContractReviewParser.parseJSON(FAKE_RESULT_ID, jsonBody);
            System.assert(false, 'Expected ContractReviewParserException');
        } catch (ContractReviewParser.ContractReviewParserException e) {
            System.assert(e.getMessage().contains('Invalid criterion ID'));
        }
    }

    /**
     * Verifies that when the same criterion Id appears multiple times in the JSON,
     * the last entry wins. This is the natural behaviour of Map.put and confirms
     * deduplication works without error.
     */
    @IsTest
    static void parseJSON_duplicateId_lastWriteWins() {
        String validId = '001000000000011AAA';
        String jsonBody = JSON.serialize(new List<Map<String, Object>>{
            new Map<String, Object>{ 'recordId' => validId, 'met' => false, 'extract' => 'first', 'aicomment' => 'first comment' },
            new Map<String, Object>{ 'recordId' => validId, 'met' => true, 'extract' => 'second', 'aicomment' => 'second comment' }
        });

        Map<Id, ContractReviewParser.ParsedCriterion> result = ContractReviewParser.parseJSON(FAKE_RESULT_ID, jsonBody);

        System.assertEquals(1, result.size());
        System.assertEquals(true, result.get(Id.valueOf(validId)).met);
        System.assertEquals('second', result.get(Id.valueOf(validId)).extract);
        System.assertEquals('second comment', result.get(Id.valueOf(validId)).aicomment);
    }

    // ─── buildUpdates unit tests ───

    /**
     * Verifies that buildUpdates correctly maps parsed criterion data onto
     * existing SObject records, setting CriterionMet__c and Extract__c
     * to the values from the parsed JSON.
     */
    @IsTest
    static void buildUpdates_validData_returnsUpdatedRecords() {
        ContractReviewRuntimeCriterion__c criterion = [SELECT Id FROM ContractReviewRuntimeCriterion__c LIMIT 1];

        ContractReviewParser.ParsedCriterion pc = new ContractReviewParser.ParsedCriterion();
        pc.recordId = criterion.Id;
        pc.met = true;
        pc.extract = 'relevant clause';
        pc.aicomment = 'Matches requirement in section 5';

        Map<Id, ContractReviewParser.ParsedCriterion> criterionDataById = new Map<Id, ContractReviewParser.ParsedCriterion>{
            criterion.Id => pc
        };
        Map<Id, ContractReviewRuntimeCriterion__c> existingCriteria = new Map<Id, ContractReviewRuntimeCriterion__c>{
            criterion.Id => criterion
        };

        List<ContractReviewRuntimeCriterion__c> toUpdate = ContractReviewParser.buildUpdates(criterionDataById, existingCriteria);

        System.assertEquals(1, toUpdate.size());
        System.assertEquals(true, toUpdate[0].CriterionMet__c);
        System.assertEquals('relevant clause', toUpdate[0].Extract__c);
        System.assertEquals('Matches requirement in section 5', toUpdate[0].ai_comment__c);
    }

    /**
     * Verifies that buildUpdates throws an exception when a parsed criterion Id
     * is not found in the existing criteria map. This guards against data integrity
     * issues where the AI references a criterion that does not exist in the database.
     */
    @IsTest
    static void buildUpdates_missingCriterion_throwsException() {
        ContractReviewRuntimeCriterion__c criterion = [SELECT Id FROM ContractReviewRuntimeCriterion__c LIMIT 1];

        ContractReviewParser.ParsedCriterion pc = new ContractReviewParser.ParsedCriterion();
        pc.recordId = criterion.Id;
        pc.met = true;
        pc.extract = 'text';

        Map<Id, ContractReviewParser.ParsedCriterion> criterionDataById = new Map<Id, ContractReviewParser.ParsedCriterion>{
            criterion.Id => pc
        };
        Map<Id, ContractReviewRuntimeCriterion__c> emptyCriteria = new Map<Id, ContractReviewRuntimeCriterion__c>();

        try {
            ContractReviewParser.buildUpdates(criterionDataById, emptyCriteria);
            System.assert(false, 'Expected ContractReviewParserException');
        } catch (ContractReviewParser.ContractReviewParserException e) {
            System.assert(e.getMessage().contains('not found'));
        }
    }

    // ─── parseReviewJSON integration tests ───

    /**
     * End-to-end happy path: inserts a ContractReviewResult__c with valid JSON
     * referencing an existing criterion, invokes the parser, and verifies the
     * criterion record was updated with the correct field values in the database.
     */
    @IsTest
    static void parseReviewJSON_endToEnd_updatesCriteria() {
        ContractReview__c review = [SELECT Id FROM ContractReview__c LIMIT 1];
        ContractReviewRuntimeCriterion__c criterion = [SELECT Id FROM ContractReviewRuntimeCriterion__c LIMIT 1];

        String jsonBody = JSON.serialize(new List<Map<String, Object>>{
            new Map<String, Object>{ 'recordId' => criterion.Id, 'met' => true, 'extract' => 'found in section 3', 'aicomment' => 'Section 3 covers this requirement' }
        });

        ContractReviewResult__c reviewResult = new ContractReviewResult__c(JSON__c = jsonBody, ContractReview__c = review.Id);
        insert reviewResult;

        Test.startTest();
        ContractReviewParser.parseReviewJSON(new List<Id>{ reviewResult.Id });
        Test.stopTest();

        ContractReviewRuntimeCriterion__c updated = [
            SELECT CriterionMet__c, Extract__c, ai_comment__c
            FROM ContractReviewRuntimeCriterion__c
            WHERE Id = :criterion.Id
        ];
        System.assertEquals(true, updated.CriterionMet__c);
        System.assertEquals('found in section 3', updated.Extract__c);
        System.assertEquals('Section 3 covers this requirement', updated.ai_comment__c);
    }

    /**
     * Verifies that a ContractReviewResult__c with a blank JSON__c field
     * causes an exception, ensuring the flow can route to a fault path
     * when upstream processing failed to populate the AI response.
     */
    @IsTest
    static void parseReviewJSON_blankJSON_throwsException() {
        ContractReview__c review = [SELECT Id FROM ContractReview__c LIMIT 1];
        ContractReviewResult__c reviewResult = new ContractReviewResult__c(JSON__c = '', ContractReview__c = review.Id);
        insert reviewResult;

        try {
            ContractReviewParser.parseReviewJSON(new List<Id>{ reviewResult.Id });
            System.assert(false, 'Expected ContractReviewParserException');
        } catch (ContractReviewParser.ContractReviewParserException e) {
            System.assert(e.getMessage().contains('No JSON found'));
        }
    }

    /**
     * Verifies that calling the invocable method with an empty list
     * returns cleanly without error or DML, covering the early-exit guard.
     */
    @IsTest
    static void parseReviewJSON_emptyList_noError() {
        ContractReviewParser.parseReviewJSON(new List<Id>());
    }

    /**
     * Verifies that JSON entries without the aicomment key parse successfully
     * with aicomment defaulting to null. This covers backward compatibility
     * with older AI responses that predate the aicomment field.
     */
    @IsTest
    static void parseJSON_missingAicomment_defaultsToNull() {
        String validId = '001000000000011AAA';
        String jsonBody = JSON.serialize(new List<Map<String, Object>>{
            new Map<String, Object>{ 'recordId' => validId, 'met' => true, 'extract' => 'clause text' }
        });

        Map<Id, ContractReviewParser.ParsedCriterion> result = ContractReviewParser.parseJSON(FAKE_RESULT_ID, jsonBody);

        System.assertEquals(1, result.size());
        System.assertEquals(null, result.get(Id.valueOf(validId)).aicomment);
    }
}