public with sharing class GdprRegisterutdragController {

    @AuraEnabled
    public static GdprRegisterutdragService.Result generateForAccount(Id accountId) {
        return GdprRegisterutdragService.generateForAccount(accountId);
    }

    /**
     * Ny entrypoint för modal-varianten där användaren kan välja format.
     * Just nu ignoreras formatet och vi skapar alltid CSV via befintlig service,
     * så vi kan enkelt lägga till riktig XLSX-hantering senare utan att ändra LWC.
     */
    @AuraEnabled
    public static GdprRegisterutdragService.Result generateForAccountWithFormat(Id accountId, String format) {
        return GdprRegisterutdragService.generateForAccountWithFormat(accountId, format);
    }
}