/**
 * @description       : Utility class providing methods to detect test context execution.
 *                      Used primarily in Flows to conditionally skip actions during unit tests.
 * @author            : Malin Nilsson (Stretch Customer AB)
 * @group             : 
 * @last modified on  : 2025-01-29
 * @last modified by  : Malin Nilsson (Stretch Customer AB)
**/
public without sharing class TestContextUtil {

    public class Request{
        @InvocableVariable(label='Some text' description='its required to have inputs, but the contents doesn\'t matter in this case.')
        public String someText;
    }

    @InvocableMethod(label='Is Running Test' description='Returns true if running in test context')
    public static List<Boolean> isRunningTest(List<Request> requests) {
        List<Boolean> results = new List<Boolean>();
        for(Request request : requests){
            results.add(System.Test.isRunningTest());
        }
        return results;
    }
}