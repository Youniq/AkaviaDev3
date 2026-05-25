public without sharing class GdprRegisterutdragService {

    public class Result {
        @AuraEnabled public Boolean success;
        /** Kort text för toast / statusrad */
        @AuraEnabled public String message;
        /** Utförlig teknisk sammanfattning (filnamn, antal, ContentDocument-id) */
        @AuraEnabled public String detailMessage;
        @AuraEnabled public Id contentDocumentId;
        @AuraEnabled public String extractFileName;
        @AuraEnabled public Id zipContentDocumentId;
        @AuraEnabled public String zipFileName;
        @AuraEnabled public Integer zipEntryCount;
        /** NONE | CREATED | ERROR_BUILD | ERROR_SAVE */
        @AuraEnabled public String zipStatus;
    }

    private class AttachmentZipPlan {
        Blob archive;
        Integer filesInZip;
        Integer uniqueDocumentsFromCases;
        Integer contentDocumentLinkRows;
        String buildError;
    }

    private class GdprDeliveryCsvInfo {
        Id personAccountId;
        String generatedAt;
        String formatLabel;
        String extractFileName;
        String zipFileName;
        Integer uniqueDocumentsFromCases;
        Integer contentDocumentLinkRows;
        Integer zipEntryCount;
        String zipPreparedSummary;
        String zipBuildError;
    }

    @AuraEnabled
    public static Result generateForAccount(Id accountId) {
        return generateForAccountWithFormat(accountId, 'CSV');
    }

    @AuraEnabled
    public static Result generateForAccountWithFormat(Id accountId, String format) {
        Result r = new Result();
        r.success = false;
        r.message = '';
        r.detailMessage = '';
        r.contentDocumentId = null;
        r.extractFileName = '';
        r.zipContentDocumentId = null;
        r.zipFileName = '';
        r.zipEntryCount = 0;
        r.zipStatus = null;

        if (accountId == null) {
            r.message = 'Kontots Id saknas.';
            return r;
        }

        // 1) Hämta personkontot och grunduppgifter
        Account acc = [
            SELECT Id,
                   Name,
                   IsPersonAccount,
                   SocialSecurityNumber__c,
                   MemberNumber__c,
                   PersonEmail,
                   Phone,
                   BillingStreet,
                   BillingPostalCode,
                   BillingCity,
                   BillingCountry
            FROM Account
            WHERE Id = :accountId
            LIMIT 1
        ];

        if (!acc.IsPersonAccount) {
            r.message = 'Kontot är inte ett personkonto.';
            return r;
        }

        // 2) Hämta relaterad data via SOQL
        List<Membership__c> memberships = getMemberships(accountId);
        List<Employment__c> employments = getEmployments(accountId);
        List<Case> cases = getCases(accountId);
        List<Assignment__c> assignments = getAssignments(accountId);
        List<Task> tasks = getTasks(accountId);
        List<Invoice__c> invoices = getInvoices(accountId);
        List<Application__c> applications = getApplications(accountId);
        List<BankIdAuthLog__c> bankIdLogs = getBankIdAuthLogs(accountId);
        List<MembershipBenefit__c> memberBenefits = getMembershipBenefits(accountId);
        List<Appointment__c> appointments = getAppointments(accountId);

        String normalizedFormat = format == null ? 'CSV' : format.trim().toUpperCase();
        Boolean excelFormat = normalizedFormat == 'XLS' || normalizedFormat == 'XLSX' || normalizedFormat == 'XML';
        String extension;
        if (normalizedFormat == 'XLSX') {
            extension = '.xlsx';
        } else if (normalizedFormat == 'XLS') {
            extension = '.xls';
        } else if (normalizedFormat == 'XML') {
            extension = '.xml';
        } else {
            extension = '.csv';
        }

        String baseName = acc.Name != null ? acc.Name : String.valueOf(accountId);
        String ts = Datetime.now().format('yyyy-MM-dd_HHmm');
        String extractFileName = 'GDPR_Registerutdrag_' + baseName.replace(' ', '_') + '_' + ts + extension;
        String zipFileNamePlanned = 'GDPR_Arendebilagor_' + baseName.replace(' ', '_') + '_' + ts + '.zip';
        String formatLabel;
        if (normalizedFormat == 'CSV') {
            formatLabel = 'CSV';
        } else if (normalizedFormat == 'XLS') {
            formatLabel = 'Excel (.xls)';
        } else if (normalizedFormat == 'XLSX') {
            formatLabel = 'Excel (.xlsx)';
        } else if (normalizedFormat == 'XML') {
            formatLabel = 'Excel XML';
        } else {
            formatLabel = normalizedFormat;
        }

        AttachmentZipPlan zipPlan = buildAttachmentZipPlan(cases);

        GdprDeliveryCsvInfo delivery = new GdprDeliveryCsvInfo();
        delivery.personAccountId = accountId;
        delivery.generatedAt = Datetime.now().format();
        delivery.formatLabel = formatLabel;
        delivery.extractFileName = extractFileName;
        delivery.zipFileName = zipFileNamePlanned;
        delivery.uniqueDocumentsFromCases = zipPlan.uniqueDocumentsFromCases;
        delivery.contentDocumentLinkRows = zipPlan.contentDocumentLinkRows;
        delivery.zipEntryCount = zipPlan.filesInZip;
        if (!String.isBlank(zipPlan.buildError)) {
            delivery.zipPreparedSummary = 'Zip kunde inte byggas.';
            delivery.zipBuildError = zipPlan.buildError;
        } else if (zipPlan.archive == null || zipPlan.archive.size() == 0) {
            delivery.zipPreparedSummary = 'Inga bifogade filer på ärenden att packa.';
        } else {
            delivery.zipPreparedSummary = 'Zip binär byggd, ' + String.valueOf(zipPlan.filesInZip) + ' fil(er).';
        }

        // 3) Bygg CSV (basformat som även används för Excel-konvertering)
        String csvContent = buildCsv(
            acc,
            memberships,
            employments,
            cases,
            assignments,
            tasks,
            invoices,
            applications,
            bankIdLogs,
            memberBenefits,
            appointments,
            delivery
        );
        if (String.isBlank(csvContent)) {
            r.message = 'Inga data kunde samlas för GDPR‑utdraget.';
            return r;
        }

        // 4) Bygg filinnehåll enligt valt format
        String outputContent = excelFormat
            ? convertCsvToExcelXml(csvContent)
            : '\uFEFF' + csvContent;
        Blob outputBlob = Blob.valueOf(outputContent);

        ContentVersion cv = new ContentVersion();
        cv.Title = extractFileName;
        cv.PathOnClient = extractFileName;
        cv.VersionData = outputBlob;
        cv.IsMajorVersion = true;
        insert cv;

        Id contentDocumentId = [
            SELECT ContentDocumentId
            FROM ContentVersion
            WHERE Id = :cv.Id
            LIMIT 1
        ].ContentDocumentId;

        ContentDocumentLink cdl = new ContentDocumentLink();
        cdl.ContentDocumentId = contentDocumentId;
        cdl.LinkedEntityId = accountId;
        cdl.ShareType = 'V';
        cdl.Visibility = 'AllUsers';
        insert cdl;

        r.success = true;
        r.contentDocumentId = contentDocumentId;
        r.extractFileName = extractFileName;
        r.zipEntryCount = zipPlan.filesInZip != null ? zipPlan.filesInZip : 0;
        r.zipFileName = zipFileNamePlanned;
        r.zipContentDocumentId = null;
        r.zipStatus = 'NONE';

        String zipSaveError = null;
        // 5) Försök skapa separat zip med bilagor från relaterade ärenden
        try {
            if (zipPlan.archive != null && zipPlan.archive.size() > 0) {
                ContentVersion zipCv = new ContentVersion();
                zipCv.Title = zipFileNamePlanned;
                zipCv.PathOnClient = zipFileNamePlanned;
                zipCv.VersionData = zipPlan.archive;
                zipCv.IsMajorVersion = true;
                insert zipCv;

                Id zipContentDocumentId = [
                    SELECT ContentDocumentId
                    FROM ContentVersion
                    WHERE Id = :zipCv.Id
                    LIMIT 1
                ].ContentDocumentId;

                ContentDocumentLink zipLink = new ContentDocumentLink();
                zipLink.ContentDocumentId = zipContentDocumentId;
                zipLink.LinkedEntityId = accountId;
                zipLink.ShareType = 'V';
                zipLink.Visibility = 'AllUsers';
                insert zipLink;

                r.zipContentDocumentId = zipContentDocumentId;
                r.zipStatus = 'CREATED';
            }
        } catch (Exception zipEx) {
            zipSaveError = zipEx.getMessage();
            r.zipStatus = 'ERROR_SAVE';
        }

        r.message = buildShortSuccessMessage(r.zipStatus, zipPlan);
        r.detailMessage = buildDetailMessage(
            extractFileName,
            contentDocumentId,
            zipFileNamePlanned,
            r.zipContentDocumentId,
            zipPlan,
            zipSaveError
        );

        return r;
    }

    private static String buildShortSuccessMessage(String zipStatus, AttachmentZipPlan zipPlan) {
        if (zipStatus == 'ERROR_SAVE') {
            return 'Utdrag sparat under Filer på kontot. Zip med bilagor kunde inte sparas.';
        }
        if (zipStatus == 'CREATED') {
            return 'GDPR‑utdrag och zip med bilagor finns under Filer på kontot.';
        }
        if (!String.isBlank(zipPlan.buildError)) {
            return 'Utdrag sparat under Filer på kontot. Zip kunde inte byggas.';
        }
        return 'GDPR‑utdrag finns under Filer på kontot.';
    }

    private static String buildDetailMessage(
        String extractFileName,
        Id extractContentDocumentId,
        String zipFileName,
        Id zipContentDocumentId,
        AttachmentZipPlan zipPlan,
        String zipSaveError
    ) {
        List<String> lines = new List<String>();
        lines.add('Utdragsfil: ' + extractFileName);
        if (extractContentDocumentId != null) {
            lines.add('ContentDocumentId (utdrag): ' + String.valueOf(extractContentDocumentId));
        }
        lines.add('—');
        lines.add('Zip (planerat filnamn): ' + zipFileName);
        if (zipContentDocumentId != null) {
            lines.add('ContentDocumentId (zip): ' + String.valueOf(zipContentDocumentId));
        } else if (!String.isBlank(zipSaveError)) {
            lines.add('Zip sparades inte: ' + zipSaveError);
        }
        lines.add('Unika dokument (ärenden): ' + String.valueOf(zipPlan.uniqueDocumentsFromCases));
        lines.add('Antal ärendekopplingar (ContentDocumentLink): ' + String.valueOf(zipPlan.contentDocumentLinkRows));
        lines.add('Antal filer i zip (vid lyckad byggnad): ' + String.valueOf(zipPlan.filesInZip));
        if (!String.isBlank(zipPlan.buildError)) {
            lines.add('Fel vid zip-byggnad: ' + zipPlan.buildError);
        }
        return String.join(lines, '\n');
    }

    private static AttachmentZipPlan buildAttachmentZipPlan(List<Case> cases) {
        AttachmentZipPlan plan = new AttachmentZipPlan();
        plan.archive = null;
        plan.filesInZip = 0;
        plan.uniqueDocumentsFromCases = 0;
        plan.contentDocumentLinkRows = 0;
        plan.buildError = null;

        if (cases == null || cases.isEmpty()) {
            return plan;
        }

        try {
            Map<Id, String> caseNumberById = new Map<Id, String>();
            Set<Id> documentIds = new Set<Id>();
            Map<Id, Id> documentToCaseId = new Map<Id, Id>();
            Map<Id, Integer> indexByCaseId = new Map<Id, Integer>();
            Set<String> usedPaths = new Set<String>();

            for (Case c : cases) {
                caseNumberById.put(c.Id, c.CaseNumber);
                if (c.ContentDocumentLinks == null) {
                    continue;
                }

                for (ContentDocumentLink cdl : c.ContentDocumentLinks) {
                    plan.contentDocumentLinkRows++;
                    if (cdl.ContentDocumentId == null) {
                        continue;
                    }
                    documentIds.add(cdl.ContentDocumentId);
                    if (!documentToCaseId.containsKey(cdl.ContentDocumentId)) {
                        documentToCaseId.put(cdl.ContentDocumentId, c.Id);
                    }
                }
            }

            plan.uniqueDocumentsFromCases = documentIds.size();

            if (documentIds.isEmpty()) {
                return plan;
            }

            List<ContentVersion> versions = [
                SELECT ContentDocumentId,
                       Title,
                       FileExtension,
                       VersionData
                FROM ContentVersion
                WHERE IsLatest = true
                  AND ContentDocumentId IN :documentIds
            ];
            if (versions.isEmpty()) {
                return plan;
            }

            Compression.ZipWriter zip = new Compression.ZipWriter();
            for (ContentVersion v : versions) {
                Id caseId = documentToCaseId.get(v.ContentDocumentId);
                String caseNumber = caseId != null ? caseNumberById.get(caseId) : null;
                String safeCaseNumber = String.isBlank(caseNumber)
                    ? 'UNKNOWN_CASE'
                    : caseNumber.replaceAll('[^a-zA-Z0-9_-]', '_');

                Integer currentIndex = indexByCaseId.containsKey(caseId) ? indexByCaseId.get(caseId) + 1 : 1;
                indexByCaseId.put(caseId, currentIndex);

                String rawTitle = String.isBlank(v.Title) ? 'bilaga_' + String.valueOf(currentIndex) : v.Title;
                String safeTitle = rawTitle.replaceAll('[\\\\/:*?"<>|]', '_');
                String ext = String.isBlank(v.FileExtension) ? '' : '.' + v.FileExtension;
                String basePath = safeCaseNumber + '/' + safeTitle + ext;
                String path = basePath;

                Integer duplicateSuffix = 1;
                while (usedPaths.contains(path)) {
                    path = safeCaseNumber + '/' + safeTitle + ' (' + String.valueOf(duplicateSuffix) + ')' + ext;
                    duplicateSuffix++;
                }
                usedPaths.add(path);

                zip.addEntry(path, v.VersionData);
            }

            plan.archive = zip.getArchive();
            plan.filesInZip = versions.size();
        } catch (Exception ex) {
            plan.archive = null;
            plan.filesInZip = 0;
            plan.buildError = ex.getMessage();
        }

        return plan;
    }

    private static void appendGdprLeveransSection(List<String> rows, GdprDeliveryCsvInfo d) {
        if (d == null) {
            return;
        }
        rows.add('');
        rows.add('');
        rows.add('=== GDPR – Leverans och spårbarhet ===');
        rows.add(csvRow(new List<String>{ 'Fält', 'Värde' }));
        rows.add(csvRow(new List<String>{ 'Personkonto (Id)', d.personAccountId != null ? String.valueOf(d.personAccountId) : '' }));
        rows.add(csvRow(new List<String>{ 'Genererat', d.generatedAt }));
        rows.add(csvRow(new List<String>{ 'Format', d.formatLabel }));
        rows.add(csvRow(new List<String>{ 'Utdragsfil (filnamn)', d.extractFileName }));
        rows.add(csvRow(new List<String>{ 'Zip ärendebilagor (filnamn)', d.zipFileName }));
        rows.add(csvRow(new List<String>{ 'Antal unika dokument på ärenden', String.valueOf(d.uniqueDocumentsFromCases) }));
        rows.add(csvRow(new List<String>{ 'Antal ärendekopplingar (ContentDocumentLink)', String.valueOf(d.contentDocumentLinkRows) }));
        Integer extraLinks = d.contentDocumentLinkRows - d.uniqueDocumentsFromCases;
        if (extraLinks < 0) {
            extraLinks = 0;
        }
        rows.add(csvRow(new List<String>{ 'Extra ärendelänkar (samma dokument flera ärenden)', String.valueOf(extraLinks) }));
        rows.add(csvRow(new List<String>{ 'Antal filer i zip (vid lyckad packning)', String.valueOf(d.zipEntryCount) }));
        rows.add(csvRow(new List<String>{ 'Status zip (före sparning i Salesforce)', d.zipPreparedSummary }));
        if (!String.isBlank(d.zipBuildError)) {
            rows.add(csvRow(new List<String>{ 'Fel vid zip-byggnad', d.zipBuildError }));
        }
        rows.add(csvRow(new List<String>{ 'Spårning i Salesforce', 'Filerna finns under Filer på personkontot; matcha filnamnen ovan.' }));
        rows.add('');
    }

    private static String buildCsv(
        Account acc,
        List<Membership__c> memberships,
        List<Employment__c> employments,
        List<Case> cases,
        List<Assignment__c> assignments,
        List<Task> tasks,
        List<Invoice__c> invoices,
        List<Application__c> applications,
        List<BankIdAuthLog__c> bankIdLogs,
        List<MembershipBenefit__c> memberBenefits,
        List<Appointment__c> appointments,
        GdprDeliveryCsvInfo deliveryInfo
    ) {
        List<String> rows = new List<String>();

        // Sektion: Person
        rows.add('=== Person ===');
        rows.add(csvRow(new List<String>{ 'Fält', 'Värde' }));
        rows.add(csvRow(new List<String>{ 'Namn', acc.Name }));
        rows.add(csvRow(new List<String>{ 'Personnummer', acc.SocialSecurityNumber__c }));
        rows.add(csvRow(new List<String>{ 'Medlemsnummer', acc.MemberNumber__c }));
        rows.add(csvRow(new List<String>{ 'E‑post', acc.PersonEmail }));
        rows.add(csvRow(new List<String>{ 'Telefon', acc.Phone }));
        rows.add(csvRow(new List<String>{ 'Adress', acc.BillingStreet }));
        rows.add(csvRow(new List<String>{ 'Postnummer', acc.BillingPostalCode }));
        rows.add(csvRow(new List<String>{ 'Ort', acc.BillingCity }));
        rows.add(csvRow(new List<String>{ 'Land', acc.BillingCountry }));
        rows.add('');

        // Sektion: Medlemskap (vertikal layout per medlemskap, liknande Person‑sektionen)
        rows.add('');
        rows.add('=== Medlemskap ===');
        if (memberships.isEmpty()) {
            rows.add(csvRow(new List<String>{ 'Medlemskap', 'Inga poster' }));
        } else {
            Integer index = 1;
            for (Membership__c m : memberships) {
                rows.add('Medlemskap ' + String.valueOf(index));
                rows.add(csvRow(new List<String>{ 'Fält', 'Värde' }));
                rows.add(csvRow(new List<String>{ 'Status', m.Status__c }));
                rows.add(csvRow(new List<String>{ 'Startdatum', m.StartDate__c != null ? String.valueOf(m.StartDate__c) : '' }));
                rows.add(csvRow(new List<String>{ 'Slutdatum', m.EndDate__c != null ? String.valueOf(m.EndDate__c) : '' }));
                rows.add(csvRow(new List<String>{ 'Medlemskategori', m.MembershipCategory__c }));
                rows.add(csvRow(new List<String>{ 'Senaste medlemskap', m.SenasteMedlemskap__c == true ? 'Ja' : 'Nej' }));
                rows.add(csvRow(new List<String>{ 'Utträdesorsak', m.ExitReason__c }));
                rows.add(''); // tom rad mellan medlemskap
                index++;
            }
        }
        rows.add('');

        // Sektion: Anställningar
        rows.add('');
        rows.add('=== Anställningar ===');
        if (employments.isEmpty()) {
            rows.add(csvRow(new List<String>{ 'Anställningar', 'Inga poster' }));
        } else {
            Integer empIndex = 1;
            for (Employment__c emp : employments) {
                rows.add('Anställning ' + String.valueOf(empIndex));
                rows.add(csvRow(new List<String>{ 'Fält', 'Värde' }));
                rows.add(csvRow(new List<String>{ 'Status', emp.Status__c }));
                rows.add(csvRow(new List<String>{ 'Startdatum', emp.StartDate__c != null ? String.valueOf(emp.StartDate__c) : '' }));
                rows.add(csvRow(new List<String>{ 'Slutdatum', emp.EndDate__c != null ? String.valueOf(emp.EndDate__c) : '' }));
                rows.add(csvRow(new List<String>{ 'Arbetsplats', emp.WorkplaceName__c }));
                rows.add('');
                empIndex++;
            }
        }
        rows.add('');

        // Sektion: Ärende - Ärenden & ärendekommentarer
        rows.add('');
        rows.add('=== Ärende - Ärenden & ärendekommentarer ===');
        if (cases.isEmpty()) {
            rows.add(csvRow(new List<String>{ 'Ärende - Ärenden & ärendekommentarer', 'Inga poster' }));
        } else {
            Integer caseIndex = 1;
            for (Case c : cases) {
                rows.add('Ärende ' + String.valueOf(caseIndex));
                rows.add(csvRow(new List<String>{ 'Fält', 'Värde' }));
                rows.add(csvRow(new List<String>{ 'Ärendenummer', c.CaseNumber }));
                rows.add(csvRow(new List<String>{ 'Ämne', c.Subject }));
                rows.add(csvRow(new List<String>{ 'Ärendets typ', c.Type }));
                rows.add(csvRow(new List<String>{ 'Status', c.Status }));
                rows.add(csvRow(new List<String>{ 'Beskrivning', c.Description }));
                rows.add(csvRow(new List<String>{ 'Datum/tid stängt', c.ClosedDate != null ? c.ClosedDate.format() : '' }));
                rows.add(csvRow(new List<String>{ 'Öppningsdatum', c.CreatedDate != null ? c.CreatedDate.format() : '' }));
                rows.add(csvRow(new List<String>{ 'Ärendeorsak', c.Reason }));
                rows.add(csvRow(new List<String>{ 'Ursprung', c.Origin }));
                rows.add(csvRow(new List<String>{ 'Överordnat ärendenummer', c.Parent != null ? c.Parent.CaseNumber : '' }));
                rows.add(csvRow(new List<String>{ 'Ägare', c.Owner != null ? c.Owner.Name : '' }));
                rows.add('');

                // Ärende - E‑postmeddelanden
                if (c.EmailMessages != null && !c.EmailMessages.isEmpty()) {
                    Integer emailIndex = 1;
                    for (EmailMessage em : c.EmailMessages) {
                        rows.add('Ärende ' + String.valueOf(caseIndex) + ' - e-postmeddelande ' + String.valueOf(emailIndex));
                        rows.add(csvRow(new List<String>{ 'Fält', 'Värde' }));
                        rows.add(csvRow(new List<String>{ 'Ämne', em.Subject }));
                        rows.add(csvRow(new List<String>{ 'Från', em.FromAddress }));
                        rows.add(csvRow(new List<String>{ 'Till', em.ToAddress }));
                        rows.add(csvRow(new List<String>{ 'Skickat', em.MessageDate != null ? em.MessageDate.format() : (em.CreatedDate != null ? em.CreatedDate.format() : '') }));
                        rows.add(csvRow(new List<String>{ 'Status', em.Status }));
                        rows.add(csvRow(new List<String>{ 'Inkommande', em.Incoming ? 'Ja' : 'Nej' }));
                        rows.add(csvRow(new List<String>{ 'Text', em.TextBody }));
                        rows.add('');
                        emailIndex++;
                    }
                } else {
                    rows.add('Ärende ' + String.valueOf(caseIndex) + ' - e-postmeddelanden');
                    rows.add(csvRow(new List<String>{ 'Fält', 'Värde' }));
                    rows.add(csvRow(new List<String>{ 'E‑postmeddelanden', 'Inga poster' }));
                    rows.add('');
                }

                // Ärende - Inlägg (Case Feed)
                if (c.Feeds != null && !c.Feeds.isEmpty()) {
                    Integer feedIndex = 1;
                    for (CaseFeed f : c.Feeds) {
                        rows.add('Ärende ' + String.valueOf(caseIndex) + ' - inlägg ' + String.valueOf(feedIndex));
                        rows.add(csvRow(new List<String>{ 'Fält', 'Värde' }));
                        rows.add(csvRow(new List<String>{ 'Typ', f.Type }));
                        rows.add(csvRow(new List<String>{ 'Titel', f.Title }));
                        rows.add(csvRow(new List<String>{ 'Text', f.Body }));
                        rows.add(csvRow(new List<String>{ 'Skapat', f.CreatedDate != null ? f.CreatedDate.format() : '' }));
                        rows.add(csvRow(new List<String>{ 'Skapad av', f.CreatedBy != null ? f.CreatedBy.Name : '' }));
                        rows.add('');
                        feedIndex++;
                    }
                } else {
                    rows.add('Ärende ' + String.valueOf(caseIndex) + ' - inlägg');
                    rows.add(csvRow(new List<String>{ 'Fält', 'Värde' }));
                    rows.add(csvRow(new List<String>{ 'Inlägg', 'Inga poster' }));
                    rows.add('');
                }

                // Ärende - Bifogade filer
                if (c.ContentDocumentLinks != null && !c.ContentDocumentLinks.isEmpty()) {
                    Integer fileIndex = 1;
                    for (ContentDocumentLink cdl : c.ContentDocumentLinks) {
                        String fileName = cdl.ContentDocument != null ? cdl.ContentDocument.Title : '';
                        String extension = cdl.ContentDocument != null ? cdl.ContentDocument.FileExtension : '';
                        String created = cdl.ContentDocument != null && cdl.ContentDocument.CreatedDate != null
                            ? cdl.ContentDocument.CreatedDate.format()
                            : '';
                        String fullFileName = String.isBlank(extension) ? fileName : fileName + '.' + extension;

                        rows.add('Ärende ' + String.valueOf(caseIndex) + ' - bifogad fil ' + String.valueOf(fileIndex));
                        rows.add(csvRow(new List<String>{ 'Fält', 'Värde' }));
                        rows.add(csvRow(new List<String>{ 'Ärendenummer', c.CaseNumber }));
                        rows.add(csvRow(new List<String>{ 'Filnamn', fullFileName }));
                        rows.add(csvRow(new List<String>{ 'Skapad', created }));
                        rows.add('');
                        fileIndex++;
                    }
                } else {
                    rows.add('Ärende ' + String.valueOf(caseIndex) + ' - bifogade filer');
                    rows.add(csvRow(new List<String>{ 'Fält', 'Värde' }));
                    rows.add(csvRow(new List<String>{ 'Ärendenummer', c.CaseNumber }));
                    rows.add(csvRow(new List<String>{ 'Filer', 'Inga poster' }));
                    rows.add('');
                }

                caseIndex++;
            }
        }
        rows.add('');

        // Sektion: Uppdrag (Assignment__c)
        rows.add('');
        rows.add('=== Uppdrag ===');
        if (assignments.isEmpty()) {
            rows.add(csvRow(new List<String>{ 'Uppdrag', 'Inga poster' }));
        } else {
            Integer assIndex = 1;
            for (Assignment__c a : assignments) {
                rows.add('Uppdrag ' + String.valueOf(assIndex));
                rows.add(csvRow(new List<String>{ 'Fält', 'Värde' }));
                rows.add(csvRow(new List<String>{ 'Namn', a.Name }));
                rows.add(csvRow(new List<String>{ 'Typ', a.Type__c }));
                rows.add(csvRow(new List<String>{ 'Roll', a.Role__c }));
                rows.add(csvRow(new List<String>{ 'Status', a.Status__c }));
                rows.add(csvRow(new List<String>{ 'Startdatum', a.StartDate__c != null ? String.valueOf(a.StartDate__c) : '' }));
                rows.add(csvRow(new List<String>{ 'Slutdatum', a.EndDate__c != null ? String.valueOf(a.EndDate__c) : '' }));
                rows.add('');
                assIndex++;
            }
        }
        rows.add('');

        // Sektion: Uppgifter (Task)
        rows.add('');
        rows.add('=== Uppgifter (Task) ===');
        if (tasks.isEmpty()) {
            rows.add(csvRow(new List<String>{ 'Uppgifter', 'Inga poster' }));
        } else {
            Integer taskIndex = 1;
            for (Task t : tasks) {
                rows.add('Uppgift ' + String.valueOf(taskIndex));
                rows.add(csvRow(new List<String>{ 'Fält', 'Värde' }));
                rows.add(csvRow(new List<String>{ 'Ämne', t.Subject }));
                rows.add(csvRow(new List<String>{ 'Status', t.Status }));
                rows.add(csvRow(new List<String>{ 'Datum', t.ActivityDate != null ? String.valueOf(t.ActivityDate) : '' }));
                rows.add(csvRow(new List<String>{ 'Ägare', t.Owner != null ? t.Owner.Name : '' }));
                rows.add('');
                taskIndex++;
            }
        }
        rows.add('');

        // Sektion: Ärende - Telefonloggar (Task, Type=Call, samt ärenden med källa Phone)
        rows.add('');
        rows.add('=== Ärende - Telefonloggar ===');
        Integer callIndex = 0;

        // Telefonloggar från Task
        for (Task t : tasks) {
            if (t.Type == 'Call' && t.TaskSubtype == 'Call') {
                callIndex++;
                rows.add('Telefonlogg ' + String.valueOf(callIndex));
                rows.add(csvRow(new List<String>{ 'Fält', 'Värde' }));
                rows.add(csvRow(new List<String>{ 'Källa', 'Task' }));
                rows.add(csvRow(new List<String>{ 'Typ', t.Type }));
                rows.add(csvRow(new List<String>{ 'Ämne', t.Subject }));
                rows.add(csvRow(new List<String>{ 'Skapat', t.CreatedDate != null ? t.CreatedDate.format() : '' }));
                rows.add(csvRow(new List<String>{ 'Beskrivning', t.Description }));
                rows.add(csvRow(new List<String>{ 'Ägare', t.Owner != null ? t.Owner.Name : '' }));
                rows.add('');
            }
        }

        // Telefonloggar från ärenden med källa Phone
        for (Case c : cases) {
            if (c.Origin == 'Phone') {
                callIndex++;
                rows.add('Telefonlogg ' + String.valueOf(callIndex));
                rows.add(csvRow(new List<String>{ 'Fält', 'Värde' }));
                rows.add(csvRow(new List<String>{ 'Källa', 'Ärende (Origin = Phone)' }));
                rows.add(csvRow(new List<String>{ 'Ärendenummer', c.CaseNumber }));
                rows.add(csvRow(new List<String>{ 'Ämne', c.Subject }));
                rows.add(csvRow(new List<String>{ 'Skapat', c.CreatedDate != null ? c.CreatedDate.format() : '' }));
                rows.add(csvRow(new List<String>{ 'Beskrivning', c.Description }));
                rows.add(csvRow(new List<String>{ 'Ägare', c.Owner != null ? c.Owner.Name : '' }));
                rows.add('');
            }
        }

        if (callIndex == 0) {
            rows.add(csvRow(new List<String>{ 'Telefonloggar', 'Inga poster' }));
        }
        rows.add('');

        // Sektion: Fakturor
        rows.add('');
        rows.add('=== Fakturor ===');
        if (invoices.isEmpty()) {
            rows.add(csvRow(new List<String>{ 'Fakturor', 'Inga poster' }));
        } else {
            Integer invIndex = 1;
            for (Invoice__c inv : invoices) {
                rows.add('Faktura ' + String.valueOf(invIndex));
                rows.add(csvRow(new List<String>{ 'Fält', 'Värde' }));
                rows.add(csvRow(new List<String>{ 'Fakturanummer', inv.Name }));
                rows.add(csvRow(new List<String>{ 'Förfallodatum', inv.ExpirationDate__c != null ? String.valueOf(inv.ExpirationDate__c) : '' }));
                rows.add(csvRow(new List<String>{ 'Betalstatus', inv.PaymentStatus__c }));
                rows.add(csvRow(new List<String>{ 'Länk', inv.InvoiceLink__c }));
                rows.add('');
                invIndex++;
            }
        }
        rows.add('');

        // Sektion: Ansökningar (Applications__r)
        rows.add('');
        rows.add('=== Ansökningar ===');
        if (applications.isEmpty()) {
            rows.add(csvRow(new List<String>{ 'Ansökningar', 'Inga poster' }));
        } else {
            Integer appIndex = 1;
            for (Application__c app : applications) {
                rows.add('Ansökan ' + String.valueOf(appIndex));
                rows.add(csvRow(new List<String>{ 'Fält', 'Värde' }));
                rows.add(csvRow(new List<String>{ 'Ansökningsdatum', app.ApplicationDate__c != null ? String.valueOf(app.ApplicationDate__c) : '' }));
                rows.add(csvRow(new List<String>{ 'Beslut', app.Decision__c }));
                rows.add(csvRow(new List<String>{ 'Medlemskapstyp', app.MembershipType__c }));
                rows.add(csvRow(new List<String>{ 'Medlemsgrupp', app.MembershipGroup__c }));
                rows.add(csvRow(new List<String>{ 'Betalsätt', app.PaymentMethod__c }));
                rows.add(csvRow(new List<String>{ 'Distributionssätt', app.DistributionMethod__c }));
                rows.add(csvRow(new List<String>{ 'Utbildning', app.Education__c }));
                rows.add(csvRow(new List<String>{ 'Universitet', app.University__c }));
                rows.add(csvRow(new List<String>{ 'Föredraget språk', app.PreferredLanguage__c }));
                rows.add('');
                appIndex++;
            }
        }
        rows.add('');

        // Sektion: BankId-authloggar
        rows.add('');
        rows.add('=== BankId-authloggar ===');
        if (bankIdLogs.isEmpty()) {
            rows.add(csvRow(new List<String>{ 'BankId-authloggar', 'Inga poster' }));
        } else {
            Integer logIndex = 1;
            for (BankIdAuthLog__c log : bankIdLogs) {
                rows.add('BankId-logg ' + String.valueOf(logIndex));
                rows.add(csvRow(new List<String>{ 'Fält', 'Värde' }));
                rows.add(csvRow(new List<String>{ 'Datum', log.CreatedDate != null ? log.CreatedDate.format() : '' }));
                rows.add(csvRow(new List<String>{ 'Status', log.Status__c }));
                rows.add(csvRow(new List<String>{ 'Felmeddelande', log.ErrorMessage__c }));
                rows.add('');
                logIndex++;
            }
        }
        rows.add('');

        // Sektion: Medlemsförmåner
        rows.add('');
        rows.add('=== Medlemsförmåner ===');
        if (memberBenefits.isEmpty()) {
            rows.add(csvRow(new List<String>{ 'Medlemsförmåner', 'Inga poster' }));
        } else {
            Integer mbIndex = 1;
            for (MembershipBenefit__c mb : memberBenefits) {
                rows.add('Medlemsförmån ' + String.valueOf(mbIndex));
                rows.add(csvRow(new List<String>{ 'Fält', 'Värde' }));
                rows.add(csvRow(new List<String>{ 'Förmån', mb.Benefit__r != null ? mb.Benefit__r.Name : '' }));
                rows.add(csvRow(new List<String>{ 'Status', mb.Status__c }));
                rows.add(csvRow(new List<String>{ 'Startdatum', mb.StartDate__c != null ? String.valueOf(mb.StartDate__c) : '' }));
                rows.add(csvRow(new List<String>{ 'Slutdatum', mb.EndDate__c != null ? String.valueOf(mb.EndDate__c) : '' }));
                rows.add('');
                mbIndex++;
            }
        }
        rows.add('');

        // Sektion: Möten
        rows.add('');
        rows.add('=== Möten ===');
        if (appointments.isEmpty()) {
            rows.add(csvRow(new List<String>{ 'Möten', 'Inga poster' }));
        } else {
            Integer aptIndex = 1;
            for (Appointment__c apt : appointments) {
                rows.add('Möte ' + String.valueOf(aptIndex));
                rows.add(csvRow(new List<String>{ 'Fält', 'Värde' }));
                rows.add(csvRow(new List<String>{ 'Mötestyp', apt.MeetingType__c }));
                rows.add(csvRow(new List<String>{ 'Start', apt.StartDateTime__c != null ? apt.StartDateTime__c.format() : (apt.StartDate__c != null ? String.valueOf(apt.StartDate__c) : '') }));
                rows.add(csvRow(new List<String>{ 'Slut', apt.EndDateTime__c != null ? apt.EndDateTime__c.format() : (apt.EndDate__c != null ? String.valueOf(apt.EndDate__c) : '') }));
                rows.add(csvRow(new List<String>{ 'Status', apt.Status__c }));
                rows.add(csvRow(new List<String>{ 'Kommentar', apt.Comments__c }));
                rows.add('');
                aptIndex++;
            }
        }
        rows.add('');

        appendGdprLeveransSection(rows, deliveryInfo);

        return String.join(rows, '\n');
    }

    private static List<Membership__c> getMemberships(Id personAccountId) {
        if (personAccountId == null) {
            return new List<Membership__c>();
        }
        return [
            SELECT Id,
                   Name,
                   Status__c,
                   StartDate__c,
                   EndDate__c,
                   MembershipCategory__c,
                   SenasteMedlemskap__c,
                   ExitReason__c,
                   Person__c
            FROM Membership__c
            WHERE Person__c = :personAccountId
        ];
    }

    private static List<Employment__c> getEmployments(Id personAccountId) {
        if (personAccountId == null) {
            return new List<Employment__c>();
        }
        return [
            SELECT Id,
                   Name,
                   Status__c,
                   StartDate__c,
                   EndDate__c,
                   WorkplaceName__c,
                   Person__c
            FROM Employment__c
            WHERE Person__c = :personAccountId
        ];
    }

    private static List<Case> getCases(Id personAccountId) {
        if (personAccountId == null) {
            return new List<Case>();
        }
        return [
            SELECT Id,
                   CaseNumber,
                   Subject,
                   Type,
                   Description,
                   Status,
                   ClosedDate,
                   Reason,
                   Origin,
                   CreatedDate,
                   Owner.Name,
                   Parent.CaseNumber,
                   (SELECT Id, IsPublished, CreatedDate, LastModifiedDate FROM CaseComments),
                   (SELECT Id,
                           Subject,
                           FromAddress,
                           ToAddress,
                   MessageDate,
                           CreatedDate,
                           Status,
                   Incoming,
                           TextBody
                    FROM EmailMessages),
                   (SELECT Id,
                           CreatedDate,
                           CreatedBy.Name,
                           Type,
                           Title,
                           Body
                    FROM Feeds),
                   (SELECT Id,
                           ContentDocumentId,
                           ContentDocument.Title,
                           ContentDocument.FileExtension,
                           ContentDocument.CreatedDate
                    FROM ContentDocumentLinks)
            FROM Case
            WHERE AccountId = :personAccountId
               OR (ContactId != null AND Contact.AccountId = :personAccountId)
        ];
    }

    private static List<Assignment__c> getAssignments(Id personAccountId) {
        if (personAccountId == null) {
            return new List<Assignment__c>();
        }
        return [
            SELECT Id,
                   Name,
                   Type__c,
                   Role__c,
                   Status__c,
                   StartDate__c,
                   EndDate__c,
                   Person__c
            FROM Assignment__c
            WHERE Person__c = :personAccountId
        ];
    }

    private static List<Task> getTasks(Id personAccountId) {
        if (personAccountId == null) {
            return new List<Task>();
        }
        return [
            SELECT Id,
                   Subject,
                   Status,
                   Type,
                   TaskSubtype,
                   CreatedDate,
                   Description,
                   ActivityDate,
                   Owner.Name,
                   WhoId,
                   WhatId
            FROM Task
            WHERE IsDeleted = false
              AND (WhoId = :personAccountId OR WhatId = :personAccountId)
        ];
    }

    private static List<Invoice__c> getInvoices(Id personAccountId) {
        if (personAccountId == null) {
            return new List<Invoice__c>();
        }
        return [
            SELECT Id,
                   Name,
                   ExpirationDate__c,
                   PaymentStatus__c,
                   InvoiceLink__c,
                   Person__c
            FROM Invoice__c
            WHERE Person__c = :personAccountId
        ];
    }

    private static List<Application__c> getApplications(Id personAccountId) {
        if (personAccountId == null) {
            return new List<Application__c>();
        }
        return [
            SELECT Id,
                   Name,
                   ApplicationDate__c,
                   Decision__c,
                   MembershipType__c,
                   MembershipGroup__c,
                   PaymentMethod__c,
                   DistributionMethod__c,
                   Education__c,
                   University__c,
                   PreferredLanguage__c,
                   Person__c
            FROM Application__c
            WHERE Person__c = :personAccountId
        ];
    }

    private static List<BankIdAuthLog__c> getBankIdAuthLogs(Id personAccountId) {
        if (personAccountId == null) {
            return new List<BankIdAuthLog__c>();
        }
        return [
            SELECT Id,
                   CreatedDate,
                   Status__c,
                   ErrorMessage__c,
                   Person__c
            FROM BankIdAuthLog__c
            WHERE Person__c = :personAccountId
            ORDER BY CreatedDate DESC
        ];
    }

    private static List<MembershipBenefit__c> getMembershipBenefits(Id personAccountId) {
        if (personAccountId == null) {
            return new List<MembershipBenefit__c>();
        }
        return [
            SELECT Id,
                   Benefit__r.Name,
                   Status__c,
                   StartDate__c,
                   EndDate__c,
                   Person__c
            FROM MembershipBenefit__c
            WHERE Person__c = :personAccountId
        ];
    }

    private static List<Appointment__c> getAppointments(Id accountId) {
        if (accountId == null) {
            return new List<Appointment__c>();
        }
        return [
            SELECT Id,
                   Name,
                   MeetingType__c,
                   StartDateTime__c,
                   StartDate__c,
                   EndDateTime__c,
                   EndDate__c,
                   Status__c,
                   Comments__c,
                   Account__c
            FROM Appointment__c
            WHERE Account__c = :accountId
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

    private static String convertCsvToExcelXml(String csvContent) {
        List<List<String>> matrix = parseCsvToMatrix(csvContent);
        List<String> xml = new List<String>();
        xml.add('<?xml version="1.0"?>');
        xml.add('<?mso-application progid="Excel.Sheet"?>');
        xml.add('<Workbook xmlns="urn:schemas-microsoft-com:office:spreadsheet"');
        xml.add(' xmlns:o="urn:schemas-microsoft-com:office:office"');
        xml.add(' xmlns:x="urn:schemas-microsoft-com:office:excel"');
        xml.add(' xmlns:ss="urn:schemas-microsoft-com:office:spreadsheet">');
        xml.add('<Worksheet ss:Name="Registerutdrag"><Table>');

        for (List<String> row : matrix) {
            xml.add('<Row>');
            for (String cell : row) {
                xml.add('<Cell><Data ss:Type="String">' + escapeXml(cell) + '</Data></Cell>');
            }
            xml.add('</Row>');
        }

        xml.add('</Table></Worksheet>');
        xml.add('</Workbook>');
        return String.join(xml, '');
    }

    private static List<List<String>> parseCsvToMatrix(String csvContent) {
        List<List<String>> rows = new List<List<String>>();
        List<String> currentRow = new List<String>();
        String currentCell = '';
        Boolean inQuotes = false;
        Integer len = csvContent != null ? csvContent.length() : 0;

        for (Integer i = 0; i < len; i++) {
            String ch = csvContent.substring(i, i + 1);

            if (ch == '"') {
                Boolean nextIsQuote = (i + 1 < len) && csvContent.substring(i + 1, i + 2) == '"';
                if (inQuotes && nextIsQuote) {
                    currentCell += '"';
                    i++;
                } else {
                    inQuotes = !inQuotes;
                }
            } else if (ch == ',' && !inQuotes) {
                currentRow.add(currentCell);
                currentCell = '';
            } else if ((ch == '\n' || ch == '\r') && !inQuotes) {
                if (ch == '\r' && i + 1 < len && csvContent.substring(i + 1, i + 2) == '\n') {
                    i++;
                }
                currentRow.add(currentCell);
                rows.add(currentRow);
                currentRow = new List<String>();
                currentCell = '';
            } else {
                currentCell += ch;
            }
        }

        if (!currentRow.isEmpty() || currentCell != '') {
            currentRow.add(currentCell);
            rows.add(currentRow);
        }

        return rows;
    }

    private static String escapeXml(String input) {
        String s = input == null ? '' : input;
        s = s.replace('&', '&amp;');
        s = s.replace('<', '&lt;');
        s = s.replace('>', '&gt;');
        s = s.replace('"', '&quot;');
        s = s.replace('\'', '&apos;');
        return s;
    }
}