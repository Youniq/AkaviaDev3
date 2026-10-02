/**
 * @description       : 
 * @author            : Malin Nilsson (Stretch Customer AB)
 * @group             : 
 * @last modified on  : 2023-11-15
 * @last modified by  : Malin Nilsson (Stretch Customer AB)
**/
global with sharing class EmailPublisherForCaseEmails implements QuickAction.QuickActionDefaultsHandler {
  
    global EmailPublisherForCaseEmails() {
  }

  global void onInitDefaults(QuickAction.QuickActionDefaults[] defaults) {
    QuickAction.SendEmailQuickActionDefaults sendEmailDefaults = (QuickAction.SendEmailQuickActionDefaults)defaults.get(0);
      
    system.debug('EmailPublisher Email ActionName: ' + sendEmailDefaults.getActionName());
    
      if(sendEmailDefaults.getActionName().equals('Case.SendEmail') ||
         sendEmailDefaults.getActionName().equals('Case.Email_With_History') ||
         sendEmailDefaults.getActionName().equals('Case.Another_email_action')) {
             EmailMessage emailMessage = (EmailMessage)sendEmailDefaults.getTargetSObject(); 
              system.debug('EmailPublisher Used email action: ' + sendEmailDefaults);
             
              // always empty To, CC and Bcc addresses. They must be entered manually, Akavia requirement.
              emailMessage.BccAddress = '';
              emailMessage.CcAddress = '';
              emailMessage.ToAddress = '';
              
            // In masterdev it's enough to only set empty strings on the above fields, but not in UAT. 
             // In UAT: when uncommenting the below the fields are emptied in UAT but I get a big red error when trying to send an email. 
             //emailMessage.ToIds = new List<String>{''};
             //emailMessage.BccIds = new List<String>{''};
             //emailMessage.CcIds = new List<String>{''};
        
              // Empty body to remove thread history if not using action specifically used for keeping thread history.
              if (
                sendEmailDefaults.getActionName().contains('Case.SendEmail')
              ) {
                system.debug('Emptying email body and subject');
                emailMessage.HtmlBody = '';
                emailMessage.TextBody = '';
                emailMessage.Subject = '';
              }
                
              system.debug('EmailPublisher modified email: ' + emailMessage);
         }
      else if(sendEmailDefaults.getActionName().equals('EmailMessage._Reply') ||
             sendEmailDefaults.getActionName().equals('EmailMessage._ReplyAll')) {
              EmailMessage emailMessage = (EmailMessage)sendEmailDefaults.getTargetSObject(); 
              system.debug('EmailPublisher before modify email: ' + emailMessage);
              system.debug('EmailPublisher before modify email html body: ' + emailMessage.HtmlBody);     
             }
		}
}