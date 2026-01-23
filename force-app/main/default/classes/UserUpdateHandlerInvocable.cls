/**
 * @description       : Update user in separate transaction to avoid MIXED_DML_OPERATION error error
 * @author            : Malin Nilsson (Stretch Customer AB)
 * @group             : 
 * @last modified on  : 2025-01-24
 * @last modified by  : Malin Nilsson (Stretch Customer AB)
**/
public class UserUpdateHandlerInvocable {
    @InvocableMethod(label='Update User in Separate Transaction' description='Updates User record in a queueable context')
    public static void updateUserAsync(List<UserUpdateRequest> requests) {
        System.enqueueJob(new UserUpdateQueueable(requests));
    }
    
    public class UserUpdateRequest {
        @InvocableVariable(required=true)
        public Id userId;
        
        @InvocableVariable(required=true)
        public Boolean isActive;
        
        @InvocableVariable
        public String federationIdentifier;
    }
    
    private class UserUpdateQueueable implements Queueable {
        private List<UserUpdateRequest> requests;
        
        public UserUpdateQueueable(List<UserUpdateRequest> requests) {
            this.requests = requests;
        }
        
        public void execute(QueueableContext context) {
            List<User> usersToUpdate = new List<User>();
            
            for(UserUpdateRequest request : requests) {
                User usr = new User(
                    Id = request.userId,
                    IsActive = request.isActive,
                    FederationIdentifier = request.federationIdentifier
                );
                usersToUpdate.add(usr);
            }
            
            if(!usersToUpdate.isEmpty()) {
                update usersToUpdate;
            }
        }
    }
}