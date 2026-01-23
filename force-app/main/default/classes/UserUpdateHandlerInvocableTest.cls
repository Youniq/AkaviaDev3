/**
 * @description       : 
 * @author            : Malin Nilsson (Stretch Customer AB)
 * @group             : 
 * @last modified on  : 2025-01-24
 * @last modified by  : Malin Nilsson (Stretch Customer AB)
**/
@IsTest
private class UserUpdateHandlerInvocableTest {
    @IsTest
    static void testUserUpdateAsync() {
        // Setup test data using TestDataFactory
        TestDataFactorySetupParams params = new TestDataFactorySetupParams();
        params.numberOfMemberUsers = 1;
        TestDataFactory.setupTestData(params);
        
        // Get the created test user
        User testUser = [SELECT Id, IsActive, FederationIdentifier FROM User WHERE Profile.Name = 'Akavia Member' AND IsActive = true LIMIT 1];
        
        // Create request
        UserUpdateHandlerInvocable.UserUpdateRequest request = new UserUpdateHandlerInvocable.UserUpdateRequest();
        request.userId = testUser.Id;
        request.isActive = false;
        request.federationIdentifier = 'test123';
        
        Test.startTest();
        UserUpdateHandlerInvocable.updateUserAsync(new List<UserUpdateHandlerInvocable.UserUpdateRequest>{request});
        Test.stopTest();
        
        // Verify the update
        User updatedUser = [SELECT Id, IsActive, FederationIdentifier FROM User WHERE Id = :testUser.Id];
        System.assertEquals(false, updatedUser.IsActive, 'User should be deactivated');
        System.assertEquals('test123', updatedUser.FederationIdentifier, 'Federation Identifier should be updated');
    }
    
    @IsTest
    static void testUserUpdateAsyncBulk() {
        // Setup test data using TestDataFactory
        TestDataFactorySetupParams params = new TestDataFactorySetupParams();
        params.numberOfMemberUsers = 10;
        TestDataFactory.setupTestData(params);
        
        // Get the created test users
        List<User> testUsers = [
            SELECT Id, FirstName 
            FROM User 
            WHERE Profile.Name = 'Akavia Member' 
            AND Email LIKE 'testuser%@example.com'  // Match the email pattern used in TestDataFactory
        ];
        List<UserUpdateHandlerInvocable.UserUpdateRequest> requests = new List<UserUpdateHandlerInvocable.UserUpdateRequest>();
        
        // Create requests
        for(User u : testUsers) {
            UserUpdateHandlerInvocable.UserUpdateRequest request = new UserUpdateHandlerInvocable.UserUpdateRequest();
            request.userId = u.Id;
            request.isActive = false;
            request.federationIdentifier = 'test' + u.FirstName;
            requests.add(request);
        }
        
        Test.startTest();
        UserUpdateHandlerInvocable.updateUserAsync(requests);
        Test.stopTest();
        
        // Verify the updates
        List<User> updatedUsers = [SELECT Id, IsActive, FederationIdentifier FROM User WHERE Id IN :testUsers];
        System.assertEquals(10, updatedUsers.size(), 'All users should be updated');
        
        for(User u : updatedUsers) {
            System.assertEquals(false, u.IsActive, 'User should be deactivated');
            System.assert(u.FederationIdentifier.startsWith('test'), 'Federation Identifier should be updated');
        }
    }
}