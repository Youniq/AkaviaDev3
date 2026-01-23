/**
 * @description Test class for TestContextUtil
 * @author Malin Nilsson (Stretch Customer AB)
 * @last modified on : 2025-01-29
 * @last modified by : Malin Nilsson (Stretch Customer AB)
 */
@IsTest
private class TestContextUtilTest {
    /**
     * @description Verifies that the isTestContext method returns true when running in test context
     */
    @IsTest
    static void testIsTestContext() {
        // When
        TestContextUtil.Request req = new TestContextUtil.Request();
        req.someText = 'aaa';
        TestContextUtil.Request req2 = new TestContextUtil.Request();
        req2.someText = 'bbb';
        List<Boolean> result = TestContextUtil.isRunningTest(new List<TestContextUtil.Request>{req, req2});
        
        // Then
        System.assertEquals(2, result.size(), 'Expected 2 results');
        System.assert(result[0], 'Expected true when running in test context');
    }
}