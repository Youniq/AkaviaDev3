/**
 * @description       : Checks if the triggering FeedComment is:
 *                      Posted on a Case
 *                      Not Authered by a Akavia Member
 *                      Is Published for all users with access
 *                      -> This is the base filter - further processing will be made in the flow triggered at the end
 * @author            : Malin Nilsson (Stretch Customer AB)
 * @group             :
 * @last modified on  : 2024-02-12
 * @last modified by  : Malin Nilsson (Stretch Customer AB)
 **/
public without sharing class FeedCommentTriggerHandler {
  public void handleAfterInsert(Map<ID, FeedComment> newMap) {
    Map<ID, FeedComment> onlyCasesMap = new Map<ID, FeedComment>();
    for (FeedComment comm : newMap.values()) {
      if (String.ValueOf(comm.parentId).startsWith('500')) {
        onlyCasesMap.put(comm.Id, comm);
      }
    }

    List<FeedComment> qualifiedFeedComments = [
      SELECT Id, Status
      FROM FeedComment
      WHERE
        Id IN :onlyCasesMap.keySet()
        // Check that comment isn't posted by member.
        AND CreatedBy.Profile.Name != 'Akavia Member'
        // Only care for specific types, theese are the same as the ones displayed in customer portal.
        AND (CommentType = 'TextComment'
        OR CommentType = 'ContentComment')
        // Make sure that related feed item is published to all users and is of correct type.
        AND FeedItemId IN (
          SELECT id
          FROM FeedItem
          WHERE
            Visibility = 'AllUsers'
            AND (Type = 'TextPost'
            OR Type = 'ContentPost')
          // Only keep if parent record is a Case
        )
        AND parentId IN (SELECT Id FROM Case)
    ];

    // Only Keep the qualified comments from the original map if they're published before sending them to flow for further processing.
    for (FeedComment comm : qualifiedFeedComments) {
      if (comm.Status == 'Published') {
        // get the whole feedComment from the onlyCasesMap before initiating flow.
        FeedComment triggerComm = onlyCasesMap.get(comm.Id);
        Map<String, Object> inputs = new Map<String, Object>{
          'var_sObj_FeedComment' => triggerComm
        };

        // Launch flow from apex
        // https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/flow_interview_class.htm
        // For discussion about invoking flow in a loop and governor limits,
        // see this tweet thread: https://twitter.com/Nads_P07/status/1140341833689518080
        Flow.Interview myFlow = Flow.Interview.createInterview(
          'FeedItem_FeedComment_SUB_NotifyMemberNewCaseComment', // API name of flow
          inputs
        );
        myFlow.start();

        System.debug(
          LoggingLevel.DEBUG,
          'FeedComment trigger initiated the flow FeedItem_FeedComment_SUB_NotifyMemberNewCaseComment.'
        );
        System.debug(LoggingLevel.DEBUG, 'Input: ' + triggerComm);
      }
    }
  }
}