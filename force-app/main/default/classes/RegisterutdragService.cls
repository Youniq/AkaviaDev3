/**
 * Generates a "registerutdrag" (register extract) for a Case.
 * Runs without sharing so that Medlemsservice can extract data for cases owned by Förhandling.
 * Call via RegisterutdragController from LWC/Flow (controller enforces allowed profiles).
 */
public without sharing class RegisterutdragService {

    private static final Set<String> ALLOWED_PROFILES = new Set<String>{
        'Akavia Medlemsservice',
        'Akavia Förhandling',
        'Akavia IT Administratör',
        'Akavia System Administrator',
        'System Administrator',
        'Admin'
    };

    /** Check if current user has a profile allowed to run registerutdrag. Used by RegisterutdragController. */
    public static Boolean isAllowedProfile() {
        try {
            User u = [SELECT Profile.Name FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];
            return ALLOWED_PROFILES.contains(u.Profile.Name);
        } catch (Exception e) {
            return false;
        }
    }

    public class Result {
        @InvocableVariable(label='Success' description='True if registerutdrag was generated and attached' required=false)
        public Boolean success;
        @InvocableVariable(label='Message' description='Success or error message' required=false)
        public String message;
        @InvocableVariable(label='ContentDocumentId' description='Id of the generated file' required=false)
        public Id contentDocumentId;
        /** Same as contentDocumentId as String so LWC always gets a value when file was created */
        public String contentDocumentIdStr;
    }

    @InvocableMethod(label='Ta ut registerutdrag' description='Genererar registerutdrag för ett ärende och kopplar filen till ärendet.')
    public static List<Result> generateRegisterutdragInvocable(List<InvocableInput> inputs) {
        List<Result> results = new List<Result>();
        for (InvocableInput input : inputs) {
            results.add(generate(input.caseId));
        }
        return results;
    }

    public class InvocableInput {
        @InvocableVariable(label='Case Id' description='Id of the Case' required=true)
        public Id caseId;
    }

    public static Result generate(Id caseId) {
        Result r = new Result();
        r.success = false;
        r.message = '';
        r.contentDocumentId = null;

        if (caseId == null) {
            r.message = 'Ärende-ID saknas.';
            return r;
        }

        try {
            // Resolve person Account from Case (Contact -> Account or Case.AccountId)
            Case c = getCase(caseId);
            if (c == null) {
                r.message = 'Ärendet kunde inte hittas.';
                return r;
            }

            Id personAccountId = resolvePersonAccountId(c);
            // If standard Contact/Account are empty, try custom lookup then Case Contact Roles (often what the "Kontakt" section shows)
            if (personAccountId == null && c.ContactId == null && c.AccountId == null) {
                personAccountId = resolvePersonAccountFromCustomField(caseId);
            }
            if (personAccountId == null && c.ContactId == null && c.AccountId == null) {
                personAccountId = resolvePersonAccountFromCaseContactRole(caseId);
            }
            // Skapa alltid registerutdrag om ärendet finns – med eller utan kontakt (buildCsv hanterar null personAccountId)

            String csvContent = buildCsv(c, personAccountId);
            if (String.isBlank(csvContent)) {
                r.message = 'Ingen data kunde samlas för registerutdraget.';
                return r;
            }

            // UTF-8 BOM so Excel shows åäö correctly
            String csvWithBom = '\uFEFF' + csvContent;
            Blob csvBlob = Blob.valueOf(csvWithBom);

            String fileName = 'Registerutdrag_' + (c.CaseNumber != null ? c.CaseNumber : caseId) + '_' + Datetime.now().format('yyyy-MM-dd_HHmm') + '.csv';

            ContentVersion cv = new ContentVersion();
            cv.Title = fileName;
            cv.PathOnClient = fileName;
            cv.VersionData = csvBlob;
            cv.IsMajorVersion = true;
            insert cv;

            Id contentDocumentId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id].ContentDocumentId;

            ContentDocumentLink cdl = new ContentDocumentLink();
            cdl.ContentDocumentId = contentDocumentId;
            cdl.LinkedEntityId = caseId;
            cdl.ShareType = 'V';
            cdl.Visibility = 'AllUsers';
            insert cdl;

            r.success = true;
            r.message = 'Registerutdrag skapat och kopplat till ärendet.';
            r.contentDocumentId = contentDocumentId;
            r.contentDocumentIdStr = contentDocumentId != null ? String.valueOf(contentDocumentId) : null;
            return r;

        } catch (Exception e) {
            String errMsg = e.getMessage();
            if (String.isNotBlank(errMsg)) {
                r.message = errMsg;
            } else {
                r.message = 'Ett fel uppstod: ' + e.getTypeName();
            }
            return r;
        }
    }

    private static Case getCase(Id caseId) {
        // Note: Account.PersonEmail not included – only exists when Person Accounts enabled; use Contact for email when available
        List<Case> cases = [
            SELECT Id, CaseNumber, Subject, Description, Status, CreatedDate, ContactId, AccountId, Owner.Name,
                   Contact.Name, Contact.Email, Contact.Phone, Contact.AccountId,
                   Account.Name, Account.Phone
            FROM Case
            WHERE Id = :caseId
            LIMIT 1
        ];
        return cases.isEmpty() ? null : cases[0];
    }

    private static Id resolvePersonAccountId(Case c) {
        if (c.ContactId != null && c.Contact != null && c.Contact.AccountId != null) {
            return c.Contact.AccountId;
        }
        if (c.AccountId != null) {
            return c.AccountId;
        }
        return null;
    }

    /**
     * Tries to find a custom lookup field on Case that references Account (e.g. Person__c, Medlem__c).
     * Used when standard ContactId and AccountId are empty but the org uses a custom field for the person.
     */
    private static Id resolvePersonAccountFromCustomField(Id caseId) {
        try {
            Map<String, Schema.SObjectField> fieldMap = Schema.SObjectType.Case.fields.getMap();
            for (String fname : fieldMap.keySet()) {
                if (fname == 'ContactId' || fname == 'AccountId') continue;
                Schema.DescribeFieldResult df = fieldMap.get(fname).getDescribe();
                if (df.getType() != Schema.DisplayType.Reference) continue;
                List<Schema.SObjectType> refTo = df.getReferenceTo();
                Boolean referencesAccount = false;
                for (Schema.SObjectType t : refTo) {
                    if (t.getDescribe().getName() == 'Account') {
                        referencesAccount = true;
                        break;
                    }
                }
                if (!referencesAccount) continue;
                String q = 'SELECT Id, ' + fname + ' FROM Case WHERE Id = :caseId LIMIT 1';
                List<SObject> rows = Database.query(q);
                if (!rows.isEmpty()) {
                    Id val = (Id) rows[0].get(fname);
                    if (val != null) return val;
                }
                break; // Use first matching field only
            }
        } catch (Exception e) {
            // Ignore – custom field not found or not accessible
        }
        return null;
    }

    /**
     * When the Case "Kontakt" section is populated via Case Contact Roles (not standard ContactId),
     * use the first contact role's Contact.AccountId as the person account.
     */
    private static Id resolvePersonAccountFromCaseContactRole(Id caseId) {
        try {
            List<CaseContactRole> roles = [
                SELECT ContactId, Contact.AccountId
                FROM CaseContactRole
                WHERE CasesId = :caseId
                AND ContactId != null
                LIMIT 1
            ];
            if (!roles.isEmpty() && roles[0].Contact != null && roles[0].Contact.AccountId != null) {
                return roles[0].Contact.AccountId;
            }
        } catch (Exception e) {
            // CaseContactRole not enabled or no access
        }
        return null;
    }

    private static String getAccountName(Id accountId) {
        try {
            List<Account> accs = [SELECT Name FROM Account WHERE Id = :accountId LIMIT 1];
            return accs.isEmpty() ? '' : (accs[0].Name != null ? accs[0].Name : '');
        } catch (Exception e) {
            return '';
        }
    }

    private static String buildCsv(Case c, Id personAccountId) {
        List<String> rows = new List<String>();

        // Section: Ärende
        rows.add('=== Ärende ===');
        rows.add(csvRow(new List<String>{ 'Fält', 'Värde' }));
        rows.add(csvRow(new List<String>{ 'Ärendenummer', c.CaseNumber }));
        rows.add(csvRow(new List<String>{ 'Ämne', c.Subject }));
        rows.add(csvRow(new List<String>{ 'Beskrivning', c.Description != null ? c.Description : '' }));
        rows.add(csvRow(new List<String>{ 'Status', c.Status }));
        rows.add(csvRow(new List<String>{ 'Skapat', c.CreatedDate != null ? c.CreatedDate.format() : '' }));
        rows.add(csvRow(new List<String>{ 'Ägare', c.Owner != null ? c.Owner.Name : '' }));
        rows.add('');

        // Section: Kontakt/Person
        rows.add('=== Kontakt / Person ===');
        if (c.Contact != null) {
            rows.add(csvRow(new List<String>{ 'Namn', c.Contact.Name }));
            rows.add(csvRow(new List<String>{ 'E-post', c.Contact.Email != null ? c.Contact.Email : '' }));
            rows.add(csvRow(new List<String>{ 'Telefon', c.Contact.Phone != null ? c.Contact.Phone : '' }));
        } else if (c.Account != null) {
            rows.add(csvRow(new List<String>{ 'Namn', c.Account.Name }));
            rows.add(csvRow(new List<String>{ 'E-post', '' }));
            rows.add(csvRow(new List<String>{ 'Telefon', c.Account.Phone != null ? c.Account.Phone : '' }));
        } else if (personAccountId != null) {
            String personName = getAccountName(personAccountId);
            rows.add(csvRow(new List<String>{ 'Namn', personName }));
            rows.add(csvRow(new List<String>{ 'E-post', '' }));
            rows.add(csvRow(new List<String>{ 'Telefon', '' }));
        } else {
            rows.add(csvRow(new List<String>{ 'Info', 'Ingen kontakt eller konto tillgänglig' }));
        }
        rows.add('');

        // Section: Medlemskap
        rows.add('=== Medlemskap ===');
        List<Membership__c> memberships = getMemberships(personAccountId);
        if (memberships.isEmpty()) {
            rows.add(csvRow(new List<String>{ 'Medlemskap', 'Inga poster' }));
        } else {
            rows.add(csvRow(new List<String>{ 'Namn', 'Status', 'Startdatum', 'Slutdatum', 'Medlemskategori', 'Senaste medlemskap', 'Utträdesorsak' }));
            for (Membership__c m : memberships) {
                rows.add(csvRow(new List<String>{
                    m.Name,
                    m.Status__c != null ? m.Status__c : '',
                    m.StartDate__c != null ? String.valueOf(m.StartDate__c) : '',
                    m.EndDate__c != null ? String.valueOf(m.EndDate__c) : '',
                    m.MembershipCategory__c != null ? m.MembershipCategory__c : '',
                    m.SenasteMedlemskap__c == true ? 'Ja' : 'Nej',
                    m.ExitReason__c != null ? m.ExitReason__c : ''
                }));
            }
        }
        rows.add('');

        // Section: Anställningar
        rows.add('=== Anställningar ===');
        List<Employment__c> employments = getEmployments(personAccountId);
        if (employments.isEmpty()) {
            rows.add(csvRow(new List<String>{ 'Anställningar', 'Inga poster' }));
        } else {
            rows.add(csvRow(new List<String>{ 'Namn', 'Status', 'Startdatum', 'Slutdatum', 'Arbetsplats' }));
            for (Employment__c emp : employments) {
                rows.add(csvRow(new List<String>{
                    emp.Name,
                    emp.Status__c != null ? emp.Status__c : '',
                    emp.StartDate__c != null ? String.valueOf(emp.StartDate__c) : '',
                    emp.EndDate__c != null ? String.valueOf(emp.EndDate__c) : '',
                    emp.WorkplaceName__c != null ? emp.WorkplaceName__c : ''
                }));
            }
        }

        return String.join(rows, '\n');
    }

    private static List<Membership__c> getMemberships(Id personAccountId) {
        if (personAccountId == null) {
            return new List<Membership__c>();
        }
        return [
            SELECT Id, Name, Status__c, StartDate__c, EndDate__c, MembershipCategory__c, SenasteMedlemskap__c, ExitReason__c
            FROM Membership__c
            WHERE Person__c = :personAccountId
            ORDER BY StartDate__c DESC NULLS LAST
        ];
    }

    private static List<Employment__c> getEmployments(Id personAccountId) {
        if (personAccountId == null) {
            return new List<Employment__c>();
        }
        return [
            SELECT Id, Name, Status__c, StartDate__c, EndDate__c, WorkplaceName__c
            FROM Employment__c
            WHERE Person__c = :personAccountId
            ORDER BY StartDate__c DESC NULLS LAST
        ];
    }

    private static String csvRow(List<String> values) {
        List<String> escaped = new List<String>();
        for (String v : values) {
            String s = v == null ? '' : v;
            if (s.contains(',') || s.contains('"') || s.contains('\n') || s.contains('\r')) {
                s = '"' + s.replace('"', '""') + '"';
            }
            escaped.add(s);
        }
        return String.join(escaped, ',');
    }
}