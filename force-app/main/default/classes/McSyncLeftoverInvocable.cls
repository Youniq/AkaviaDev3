/**
 * @description       : Responsible for attempting to fix SyncWithMc__c checkbox status on all relevant child objects under Account.
 * @author            : Malin Nilsson (Stretch Customer AB)
 * @group             :
 * @last modified on  : 2025-01-28
 * @last modified by  : Malin Nilsson (Stretch Customer AB)
 **/
public without sharing class McSyncLeftoverInvocable {
  public class Request {
    @InvocableVariable(
      Label='Query Limit'
      Description='Use of you wish to add a limit to number of queried records for each child object. Leave empty to query all.'
    )
    public Integer queryLimit;

     @InvocableVariable(
      Label='Account Id'
      Description='If the job should run for single Account, put the Account Id. Leave empty to run for all Accounts.'
    )
    public String accId;
  }

  @InvocableMethod(
    label='Correct Mc Sync Leftovers'
    description='Enqueues jobs that will try to update child records (under Account) to have the correct Mc Sync status (SyncWithMc__c)'
  )
  public static void correctMcSyncStatus(List<Request> requests) {
    for (Request r : requests) {
      // 1. Correct mismatched Memberships
      LeftoverQueueable membershipsQueueable = new LeftoverQueueable(
        McSyncLeftoverHelper.membershipsQuery(r.queryLimit, r.accId),
        'Memberships'
      );
      System.enqueueJob(membershipsQueueable);

      // 2. Correct mismatched Employments
      LeftoverQueueable empsQueueable = new LeftoverQueueable(
        McSyncLeftoverHelper.employmentsQuery(r.queryLimit,r.accId),
        'Emplpoyments'
      );
      System.enqueueJob(empsQueueable);

      // 3. Correct mismatched Applications
      LeftoverQueueable applicationsQueueable = new LeftoverQueueable(
        McSyncLeftoverHelper.applicationsQuery(r.queryLimit,r.accId),
        'Applications'
      );
      System.enqueueJob(applicationsQueueable);

      // 4. Correct mismatched Assignments
      LeftoverQueueable assignmtsQueueable = new LeftoverQueueable(
        McSyncLeftoverHelper.assignmentsQuery(r.queryLimit,r.accId),
        'Assignments'
      );
      System.enqueueJob(assignmtsQueueable);

      // // X5X. Correct mismatched Invoices
      // LeftoverQueueable invcoicesQueueable = new LeftoverQueueable(
      //   McSyncLeftoverHelper.invoicesQuery(r.queryLimit,r.accId),
      //   'Invoices'
      // );
      // System.enqueueJob(invcoicesQueueable);

      // 5. Correct mismatched Membership Benefits
      LeftoverQueueable memBenefitsQueueable = new LeftoverQueueable(
        McSyncLeftoverHelper.membershipBenefitQuery(r.queryLimit,r.accId),
        'MembershipBenefits'
      );
      System.enqueueJob(memBenefitsQueueable);

      // 6. Correct mismatched Campaign Members
      LeftoverQueueable campaignMembersQueueable = new LeftoverQueueable(
        McSyncLeftoverHelper.campaignMembersQuery(r.queryLimit,r.accId),
        'CampaignMembers'
      );
      System.enqueueJob(campaignMembersQueueable);
    }
  }

  /**
   * Quable class to initiate batches for each object.
   */
  public class LeftoverQueueable implements System.Queueable {
    private String query;
    private String runningObject; // only for logging purposes in batchable

    public LeftoverQueueable(String inputQuery, String inputObject) {
      this.query = inputQuery;
      this.runningObject = inputObject;
    }

    public void execute(QueueableContext context) {
      try {
        System.debug(
          LoggingLevel.DEBUG,
          'Initiated queable for object: ' +
          this.runningObject +
          '. id: ' +
          context.getJobId()
        );

        McSyncLeftoverBatchable batchable = new McSyncLeftoverBatchable(
          this.query,
          this.runningObject
        );
        Database.executeBatch(batchable);
      } catch (Exception ex) {
        System.debug(
          'Cause--> ' +
          ex.getCause() +
          'Message--> ' +
          ex.getMessage()
        );
        System.debug(
          'tackTrace--> ' +
          ex.getStackTraceString() +
          'tLineNumber--> ' +
          ex.getLineNumber()
        );

        ApexLog.Error logError = new ApexLog.error(
          'MCSyncLeftoverBatchable',
          'execute()',
          true,
          ex
        );
        ApexLog.createLogDebug(logError);
      }
    }
  }
}