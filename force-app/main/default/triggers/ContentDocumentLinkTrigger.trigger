/**
 * Trigger: ContentDocumentLink (after insert)
 * Purpose:
 *  1) Run existing org handler to launch flow etc.
 *  2) If a File is linked to an EmailMessage, also link the same File to the related Case
 *     so it appears in Case Files / File Explorer.
 */
trigger ContentDocumentLinkTrigger on ContentDocumentLink (after insert) {

    // (Optional) Keep this if you actually use this handler in your org.
    // Note: No try/catch needed — if the class didn't exist, this trigger wouldn't compile.
    new ContentDocumentLinkTriggerHandler().handleAfterInsert(Trigger.new, Trigger.newMap);

    // Only process CDLs linked to EmailMessage
    List<ContentDocumentLink> emailMessageCdls = new List<ContentDocumentLink>();
    for (ContentDocumentLink cdl : Trigger.new) {
        if (cdl.LinkedEntityId == null) continue;

        // Avoid string compares where possible
        if (cdl.LinkedEntityId.getSObjectType() == EmailMessage.SObjectType) {
            emailMessageCdls.add(cdl);
        }
    }

    if (!emailMessageCdls.isEmpty()) {
        EmailAttachmentLinkHandler.linkEmailFilesToCases(emailMessageCdls);
    }
}
