/**
 * @description Trigger handler for BulkEmailSendEvent__e platform event
 * @author AI Assistant
 * @group Bulk Email
**/
trigger BulkEmailSendEventTrigger on BulkEmailSendEvent__e (after insert) {
    BulkEmailSendEventTriggerHandler handler = new BulkEmailSendEventTriggerHandler();
    handler.processEvents(Trigger.new);
}