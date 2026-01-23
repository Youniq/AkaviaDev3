/**
 * Class to hold invocable method that handles moving of Employment__c records from one workplace to another
 * @author Jenny Blomberg
 * @since 2023-02-03
 */
public class TransferEmploymentsInvocable {

    public class Request {

        @InvocableVariable (label='ID of existing workplace' description='ID of the workplace to move employments from' required=true)
        public String oldWorkPlaceId;

        @InvocableVariable (label='ID of future workplace' description='ID of the workplace to move employments to' required=true)
        public String newWorkPlaceId;

        @InvocableVariable (label='Move Existing Employments?' description='Should we move existing Employment records (true) or should we End existing and create new Employment Records? (false)' required=true)
        public boolean moveExisting; 

        @InvocableVariable (label='Start Date if we create new employments' description='If we are to create new Employment__c records we need a startdate' required=false)
        public Date StartDate;
    }

    public class Result {
        @InvocableVariable(label='Error Messages' description='Error Messages' required=true)
        public List<String> errorMessages = new List<String>();
    }

    /**
     * Invocable method to handle moving of employments from one workplace to another
     * @param requests 
     * @return  `Static List<Result>`
     */
    @InvocableMethod(label='Move Employments' description='Method to move employments from a workplace to another')
    public Static List<Result> TransferEmploymentsInvocable(List<Request> requests) {

        for(Request r: requests){
            if(r.moveExisting){
                List<Employment__c> employmentsToMove = getEmploymentsToMove(r.oldWorkPlaceId);
                employmentsToMove = handleEmploymentsToMove(employmentsToMove, r.newWorkPlaceId);
                Database.executeBatch(new BatchableUpsertSObject(employmentsToMove, 'update'), 50);
            }else{
                List<Employment__c> employmentsToReCreate = getEmploymentsToReCreate(r.oldWorkPlaceId);
                List<Employment__c> employmentsToCreate = handleEmploymentsToReCreate(employmentsToReCreate, r.newWorkPlaceId, r.StartDate);
                Database.executeBatch(new BatchableUpsertSObject(employmentsToCreate, 'insert'), 50);
            }
        }

        return new List<Result>();
    }

    /**
     * If the user has chosen to move Employments this method will simply connect the Employment__c records 
     * to the new workplace instead. 
     * @param employmentsToMove //Employment__c records to move to the new workplace
     * @param newWorkplaceId // Id of the new Workplace
     * @return  `List<Employment__c>`//List of the moved Employment__c records NOT yet updated in db
     */
    private static List<Employment__c> handleEmploymentsToMove(List<Employment__c> employmentsToMove, String newWorkplaceId){

        for(Employment__c em: employmentsToMove){
            em.WorkPlace__c = newWorkplaceId;
        }

        return employmentsToMove;
    }

    /**
     * If the user has chosen to reCreate Employments this method will end all current employments and 
     * create new ones connected to the new workplace
     * @param employmentsToReCreate // these are the employments that we will create new Employment__c records for at the new workplace
     * @param newWorkplaceId // Id of the new workplace
     * @param StartDate //Start date for the new Employment__c records
     * @return  `List<Employment__c>` // List of all new Employment__c records NOT yet inserted
     */
    private static List<Employment__c> handleEmploymentsToReCreate(List<Employment__c> employmentsToReCreate, String newWorkplaceId, Date StartDate){

        List<Employment__c> employmentsToInsert = new List<Employment__c>();

        for(Employment__c employmentToEnd: employmentsToReCreate){
            Employment__c newEmployment = new Employment__c(
                                                            WorkPlace__c = newWorkplaceId,
                                                            Person__c = employmentToEnd.Person__c,
                                                            Manager__c = employmentToEnd.Manager__c,
                                                            StartDate__c = StartDate
                                                            );
            employmentsToInsert.add(newEmployment);
        }

        return employmentsToInsert;
    }

    /**
     * Method to query the employment records that should be moved, meaning that they should be 
     * connected to a new workplace.
     * @param workplaceId 
     * @return  `List<Employment__c>`
     */
    private static List<Employment__c> getEmploymentsToMove(String workplaceId){
        return[SELECT 
                Id
                FROM Employment__c 
                WHERE WorkPlace__c =: workplaceId 
                AND Status__c != 'Avslutad'];
    }

    /**
     * Method to query the employment__c records that should be "recreated" meaning the ones that should 
     * get an end date and a new record should be created connected to the new worksite
     * @param workplaceId 
     * @return  `List<Employment__c>`
     */
    private static List<Employment__c> getEmploymentsToReCreate(String workplaceId){
        return[SELECT 
                Id,
                WorkPlace__c,
                Person__c, 
                Manager__c,
                StartDate__c
                FROM Employment__c 
                WHERE WorkPlace__c =: workplaceId 
                AND Status__c != 'Avslutad'
                AND IsLatestEmployment__c = true];
    }
}