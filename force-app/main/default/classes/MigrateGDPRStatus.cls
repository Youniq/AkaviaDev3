public class MigrateGDPRStatus {
    static final Date today = System.today();
    static final Date DaysAgo30 = today.addDays(-30);
    static final Date YearsAgo1 = today.addMonths(-12);
    static final Date YearsAgo3 = today.addMonths(-36);
    static final Date YearsAgo5 = today.addMonths(-60);
    static final Date YearsAgo7 = today.addMonths(-84);
    static final Date YearsAgo10 = today.addMonths(-120);
    static final Date YearsAgo20 = today.addMonths(-240);
    static final String GDPRStatus30Days = '30 Days';
    static final String GDPRStatus1Year = '1 Year';
    static final String GDPRStatus3Year = '3 Year';
    static final String GDPRStatus5Year = '5 Year';
    static final String GDPRStatus7Year = '7 Year';

    public MigrateGDPRStatus(){
        
        initFieldUpdate(DaysAgo30, YearsAgo1, GDPRStatus30Days);  // GDPR 30dagar gäller från 30 dagar till 1 år
        initFieldUpdate(YearsAgo1, YearsAgo3, GDPRStatus1Year);  // GDPR 1 år gäller från 1 år - 3 år
        initFieldUpdate(YearsAgo3, YearsAgo5, GDPRStatus3Year);  // GDPR 3 år gäller från 3 år - 5 år
        initFieldUpdate(YearsAgo5, YearsAgo7, GDPRStatus5Year);  // GDPR 5 år gäller från 5 år - 7 år
        initFieldUpdate(YearsAgo7, YearsAgo10, GDPRStatus7Year);  // GDPR 7 år gäller från 7 år - 10 år, vid GDPR 10 år deletas personkontot från databasen.
        initFieldUpdate(YearsAgo10, YearsAgo20, GDPRStatus7Year);  // Sätt GDPR 7 år även på medlemmar vart cancellationDate__c har passerat 10 år, dett pga flow kollar att GDPRStatus__c är '7 Year' - annars deletas de ej.
    }
    
    /**
     * cancelIntervalStart = Det närmsta datumet som villkoret gäller för.
     * cancelIntervalEnd = Det mest avlägsna datumet som villkoret gäller för.
     * Ex. Record cancellationDate är 2020-01-01. 
     * GDPR 30 dagar gäller då med start (cancelIntervalStart) 2020-02-01 och avslutas (cancelIntervalEnd) dagen innan det gått ett år: 2020-12-31.
     * */
    private void initFieldUpdate(Date cancelIntervalStart, Date cancelIntervalEnd, String fieldValue) {
          String accountGDPRQuery = 'SELECT Id FROM Account WHERE ' +
            'GDPRStatus__c = null' + 
            ' AND IsPersonAccount = true' + 
            ' AND MembershipStatus__c != \'Aktiv\'' +
            ' AND cancellationDate__c != null' +
            ' AND CancellationDate__c <= :CancelIntervalStart' +
            ' AND cancellationDate__c > :CancelIntervalEnd';
        
        Id batchInstanceId = Database.executeBatch(new MigrateGDPRStatusBatchable(accountGDPRQuery, cancelIntervalStart, cancelIntervalEnd, fieldValue));
    }
}