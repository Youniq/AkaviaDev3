/**
 * Controller for Registerutdrag (register extract) from Case.
 * Checks that the current user has an allowed profile, then delegates to RegisterutdragService.
 */
public with sharing class RegisterutdragController {

    @AuraEnabled
    public static RegisterutdragService.Result generateRegisterutdrag(Id caseId) {
        if (!isAllowedProfile()) {
            throw new AuraHandledException('Du har inte behörighet att ta ut registerutdrag.');
        }
        return RegisterutdragService.generate(caseId);
    }

    private static Boolean isAllowedProfile() {
        return RegisterutdragService.isAllowedProfile();
    }
}