/**
 * @description       : 
 * @author            : Malin Nilsson (Stretch Customer AB)
 * @group             : 
 * @last modified on  : 2023-11-15
 * @last modified by  : Malin Nilsson (Stretch Customer AB)
**/
global with sharing class EmailPublisherForCaseEmails implements QuickAction.QuickActionDefaultsHandler {

    private static final String DEFAULT_TEMPLATE_DEVELOPER_NAME = 'Standard_Case_signatur';
    private static Id cachedTemplateId;

    global EmailPublisherForCaseEmails() {}

    global void onInitDefaults(QuickAction.QuickActionDefaults[] defaults) {
        if (defaults == null || defaults.isEmpty()) return;

        for (QuickAction.QuickActionDefaults qd : defaults) {
            if (!(qd instanceof QuickAction.SendEmailQuickActionDefaults)) continue;

            QuickAction.SendEmailQuickActionDefaults sendEmailDefaults = (QuickAction.SendEmailQuickActionDefaults) qd;
            EmailMessage emailMessage = (EmailMessage) sendEmailDefaults.getTargetSObject();
            String actionName = sendEmailDefaults.getActionName();

            // 1. Hämta mallens innehåll (Signaturen)
            Id templateId = getDefaultClassicTemplateId();
            String templateBody = '';
            if (templateId != null) {
                Id caseId = sendEmailDefaults.getContextId();
                Messaging.SingleEmailMessage renderedTemplate = Messaging.renderStoredEmailTemplate(templateId, null, caseId);
                templateBody = renderedTemplate.getHtmlBody();
            }

            // 2. LOGIK FÖR NYA MEJL (Case.SendEmail)
            // Här vill vi fortfarande starta med ett tomt ark (förutom signaturen)
            if (actionName.equals('Case.SendEmail') || 
                actionName.equals('Case.Email_With_History') || 
                actionName.equals('Case.Another_email_action')) {
                
                emailMessage.BccAddress = '';
                emailMessage.CcAddress = '';
                emailMessage.ToAddress = '';

                if (actionName.equals('Case.SendEmail')) {
                    emailMessage.Subject = ''; 
                    emailMessage.HtmlBody = templateBody; 
                    emailMessage.TextBody = '';
                } else {
                    String existingBody = emailMessage.HtmlBody != null ? emailMessage.HtmlBody : '';
                    emailMessage.HtmlBody = templateBody + '<br/><br/>' + existingBody;
                }
            }
            
            // 3. LOGIK FÖR SVAR (Reply / ReplyAll)
            // HÄR BEHÅLLER VI ALLT: To, CC, BCC, Ämne och Historik
            else if (actionName.equals('EmailMessage._Reply') || actionName.equals('EmailMessage._ReplyAll')) {
                
                // Spara historiken
                String history = emailMessage.HtmlBody != null ? emailMessage.HtmlBody : '';
                
                // VI RÖR INTE:
                // emailMessage.ToAddress
                // emailMessage.CcAddress
                // emailMessage.BccAddress
                // emailMessage.Subject
                // På så sätt behålls allt precis som det var i tråden.

                // Lägg bara signaturen ÖVERST och behåll historiken under
                emailMessage.HtmlBody = templateBody + '<br/><br/>' + history;
            }
        }
    }

    private static Id getDefaultClassicTemplateId() {
        if (cachedTemplateId != null) return cachedTemplateId;
        List<EmailTemplate> templates = [
            SELECT Id FROM EmailTemplate 
            WHERE DeveloperName = :DEFAULT_TEMPLATE_DEVELOPER_NAME AND IsActive = true 
            LIMIT 1
        ];
        return templates.isEmpty() ? null : templates[0].Id;
    }
}