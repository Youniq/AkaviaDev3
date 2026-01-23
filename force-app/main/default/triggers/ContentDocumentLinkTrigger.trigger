/**
 * @description       : 
 * @author            : Malin Nilsson (Stretch Customer AB)
 * @group             : 
 * @last modified on  : 2026-01-16
 * @last modified by  : Malin Nilsson (Stretch Customer AB)
**/
trigger ContentDocumentLinkTrigger on ContentDocumentLink ( after insert ) {

    if ( Trigger.isAfter && Trigger.isInsert ) {
        // Call existing handler if it exists (may be from managed package)
        try {
            ContentDocumentLinkTriggerHandler handler = new ContentDocumentLinkTriggerHandler();
            handler.handleAfterInsert( Trigger.new, Trigger.newMap );
        } catch (Exception e) {
            // Handler may not exist, continue with our logic
            System.debug(LoggingLevel.WARN, 'ContentDocumentLinkTriggerHandler not found: ' + e.getMessage());
        }
        
        // Control if CDLs are linked to EmailMessages
        List<ContentDocumentLink> emailMessageCdlList = new List<ContentDocumentLink>();
        for (ContentDocumentLink cdl : Trigger.new) {
            if (cdl.LinkedEntityId != null) {
                String objectType = String.valueOf(cdl.LinkedEntityId.getSObjectType());
                if (objectType == 'EmailMessage') {
                    System.debug(LoggingLevel.INFO, 'ContentDocumentLinkTrigger: CDL is linked to EmailMessage: ' + cdl.LinkedEntityId);
                    emailMessageCdlList.add(cdl);
                }
            }
        }
        if (!emailMessageCdlList.isEmpty()) {
            // Link email attachment files to their related Cases
            EmailAttachmentLinkHandler.linkEmailFilesToCases(emailMessageCdlList);
        }
    }

}