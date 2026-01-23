/**
 * @description       :
 * @author            : Malin Nilsson (Stretch Customer AB)
 * @group             :
 * @last modified on  : 2024-02-06
 * @last modified by  : Malin Nilsson (Stretch Customer AB)
 **/
trigger FeedCommentTrigger on FeedComment(after insert) {
  FeedCommentTriggerHandler handler = new FeedCommentTriggerHandler();

  if (Trigger.isInsert && Trigger.isAfter) {
    handler.handleAfterInsert(Trigger.newMap);
  }

}