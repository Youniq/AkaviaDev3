/**
 * Trigger: ContentDocumentLink (after insert)
 * Purpose:
 *  1) Run existing org handler to launch flow etc.
 *  2) If a File is linked to an EmailMessage, also link the same File to the related Case
 *     so it appears in Case Files / File Explorer.
 */
trigger ContentDocumentLinkTrigger on ContentDocumentLink (after insert) {

    new ContentDocumentLinkTriggerHandler().handleAfterInsert(Trigger.new, Trigger.newMap);

    List<ContentDocumentLink> emailMessageCdls = new List<ContentDocumentLink>();
    for (ContentDocumentLink cdl : Trigger.new) {
        if (cdl.LinkedEntityId == null) continue;

        if (cdl.LinkedEntityId.getSObjectType() == EmailMessage.SObjectType) {
            emailMessageCdls.add(cdl);
        }
    }

    if (!emailMessageCdls.isEmpty()) {
        EmailAttachmentLinkHandler.linkEmailFilesToCases(emailMessageCdls);
    }
}
