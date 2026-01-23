trigger AttachmentTrigger on Attachment (after insert) {

    if (Trigger.isAfter && Trigger.isInsert) {
        // Link email attachment files to their related Cases
        // This converts Attachment records to Files (ContentDocument) and links them to Cases
        EmailAttachmentLinkHandler.linkEmailAttachmentsToCases(Trigger.new);
    }

}