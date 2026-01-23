public with sharing class LogCallController {
    
    @AuraEnabled
public static Id createCallTaskWithMentions(String comments, String taskType, Id contactId, Id accountId, List<String> mentionedUsers) {
    // Create call activity exactly like standard Salesforce
    Task t = new Task();
    t.Subject = 'Samtal';
    t.Type = 'Call';
    t.Status = 'Completed';
    t.Priority = 'Normal';
    t.TaskSubtype = 'Call';
    t.ActivityDate = Date.today();
    t.Description = comments;
    t.WhoId = contactId;
    t.WhatId = accountId;
    t.OwnerId = UserInfo.getUserId();
    t.CallType = 'Outbound';

    // Get current user's department based on Profile
    String userAvdelning = getUserAvdelningFromProfile();
    
    // Set the department automatically
    if (String.isNotBlank(userAvdelning)) {
        try {
            t.put('Avdelning__c', userAvdelning);
        } catch (Exception e) {
            // Silent fail for custom field
        }
    }
    
    // Try to set custom type field if it exists
    if (String.isNotBlank(taskType)) {
        try {
            t.put('Type__c', taskType);
        } catch (Exception e) {
            // Silent fail for custom field
        }
    }
    
    insert t;
    
    // Send notifications for mentioned users
    if (mentionedUsers != null && !mentionedUsers.isEmpty()) {
        sendMentionNotifications(mentionedUsers, comments, t.Id);
    }
    
    return t.Id;
}
    private static String getUserAvdelningFromProfile() {
    try {
        // Get current user's profile
        User currentUser = [
            SELECT Id, Profile.Name
            FROM User 
            WHERE Id = :UserInfo.getUserId() 
            LIMIT 1
        ];
        
        if (String.isNotBlank(currentUser.Profile.Name)) {
            return mapProfileToAvdelning(currentUser.Profile.Name);
        }
        
    } catch (Exception e) {
        // Silent fail
    }
    
    return null; // Will default to -- None --
}
        // Add this method after getUserAvdelningFromTitle() and before sendMentionNotifications()
    
    // Map title to Avdelning picklist values
   private static String mapProfileToAvdelning(String profileName) {
    if (String.isBlank(profileName)) return null;
    
    String profile = profileName.toLowerCase();
    
    // Map to your exact picklist values
    if (profile.contains('förhandling') || profile.contains('forhandling')) {
        return 'Förhandling';
    }

    if (profile.contains('medlemsservice') || profile.contains('member')) {
        return 'Medlemsservice';
    }
    
    return null; // Default to -- None --
}
    
    // Send bell notifications to mentioned users
    private static void sendMentionNotifications(List<String> mentionedUsers, String comments, Id taskId) {
        try {
            CustomNotificationType notificationType = [
                SELECT Id, DeveloperName 
                FROM CustomNotificationType 
                WHERE DeveloperName = 'Call_Log_Mention' 
                LIMIT 1
            ];
            
            // Only notify specific profiles
            Set<String> allowedProfiles = new Set<String>{ 'Akavia Medlemsservice', 'Akavia Förhandling' };
            List<User> usersToNotify = new List<User>();
            for (String mentionedUser : mentionedUsers) {
                List<User> matchedUsers = [
                    SELECT Id, Name, UserType, IsActive, Profile.Name
                    FROM User 
                    WHERE Name = :mentionedUser 
                    AND IsActive = true 
                    AND UserType = 'Standard'
                    AND Profile.Name IN :allowedProfiles
                    LIMIT 1
                ];
                if (!matchedUsers.isEmpty()) {
                    usersToNotify.add(matchedUsers[0]);
                }
            }
            
            if (!usersToNotify.isEmpty()) {
                Messaging.CustomNotification notification = new Messaging.CustomNotification();
                notification.setTitle('Du blev taggad i en samtalslogg');
                notification.setBody(UserInfo.getName() + ' nämnde dig: ' + comments.abbreviate(60));
                notification.setNotificationTypeId(notificationType.Id);
                notification.setTargetId(taskId);
                
                Set<String> recipientIds = new Set<String>();
                for (User u : usersToNotify) recipientIds.add(u.Id);
                notification.send(recipientIds);
            }
        } catch (Exception e) {
            // Silent fail for notifications
        }
    }
    
    // Get Task Type picklist values
    @AuraEnabled(cacheable=true)
    public static List<PicklistOption> getTaskTypePicklistValues() {
        List<PicklistOption> options = new List<PicklistOption>();
        
        Schema.DescribeFieldResult fieldResult = Task.Type__c.getDescribe();
        List<Schema.PicklistEntry> picklistEntries = fieldResult.getPicklistValues();
        
        for (Schema.PicklistEntry entry : picklistEntries) {
            if (entry.isActive()) {
                options.add(new PicklistOption(entry.getLabel(), entry.getValue()));
            }
        }
        
        return options;
    }
    
    // Helper class for picklist options
    public class PicklistOption {
        @AuraEnabled
        public String label { get; set; }
        @AuraEnabled
        public String value { get; set; }
        
        public PicklistOption(String label, String value) {
            this.label = label;
            this.value = value;
        }
    }
    @AuraEnabled(cacheable=true)
    public static List<UserSuggestion> searchUsersForMention(String query, Integer limitSize) {
        List<UserSuggestion> out = new List<UserSuggestion>();
        if (String.isBlank(query)) return out;
        String q = query.trim();
        if (q.length() < 2) return out;
        Integer lim = (limitSize == null || limitSize <= 0 || limitSize > 20) ? 7 : limitSize;
        // Allowed profiles for mention search
        Set<String> allowedProfiles = new Set<String>{ 'Akavia Medlemsservice', 'Akavia Förhandling' };
    
        // Split on spaces and hyphens for better matching
        List<String> parts = new List<String>();
        for (String p : q.split('[\\s\\-]+')) if (!String.isBlank(p)) parts.add(p);
        if (parts.isEmpty()) return out;
    
        // Build "anna* carin* grön*" term
        String soslQ = '';
        for (Integer i = 0; i < parts.size(); i++) soslQ += parts[i] + (i < parts.size() - 1 ? '* ' : '*');
    
        try {
            // Dynamic SOSL: no bind vars; escape quotes and append numeric LIMIT
            String term = String.escapeSingleQuotes(soslQ);
            String s = 'FIND \'' + term + '\' IN NAME FIELDS RETURNING ' +
                       'User(Id, Name WHERE IsActive = true AND UserType = \'Standard\' ' +
                       'ORDER BY Name LIMIT ' + lim + ')';
            List<List<SObject>> sr = Search.query(s);
    
            // Collect IDs from SOSL
            Set<Id> ids = new Set<Id>();
            if (!sr.isEmpty()) for (SObject so : sr[0]) ids.add(((User)so).Id);
    
            if (!ids.isEmpty()) {
                // Re-filter via SOQL to allow only specific profiles
                for (User u : [
                    SELECT Id, Name, Profile.Name
                    FROM User
                    WHERE Id IN :ids
                      AND Profile.Name IN :allowedProfiles
                    ORDER BY Name
                    LIMIT :lim
                ]) {
                    out.add(new UserSuggestion(u.Id, u.Name));
                }
            }
        } catch (Exception e) {
            // Fallback to SOQL LIKE 
            String likePattern = '%' + String.join(parts, '%') + '%';
            for (User u : [
                SELECT Id, Name, Profile.Name
                FROM User
                WHERE IsActive = true
                  AND UserType = 'Standard'
                  AND Profile.Name IN :allowedProfiles
                  AND Name LIKE :likePattern
                ORDER BY Name
                LIMIT :lim
            ]) {
                out.add(new UserSuggestion(u.Id, u.Name));
            }
        }
        return out;
    }
    // ...existing code...

    // Wrapper for mention suggestions
    public class UserSuggestion {
        @AuraEnabled public Id id { get; set; }
        @AuraEnabled public String name { get; set; }
        public UserSuggestion(Id id, String name) {
            this.id = id;
            this.name = name;
        }
    }
}