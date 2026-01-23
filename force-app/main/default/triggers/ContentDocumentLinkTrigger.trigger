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
        
        // Link email attachment files to their related Cases
        EmailAttachmentLinkHandler.linkEmailFilesToCases(Trigger.new);
    }

}