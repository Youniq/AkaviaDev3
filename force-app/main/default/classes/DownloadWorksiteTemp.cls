global class DownloadWorksiteTemp implements Database.Batchable<sObject>, Database.AllowsCallouts {
  public List<String> basunIds;
  List<WorksiteDetails> result = new List<WorksiteDetails>();

  global Database.QueryLocator start(Database.BatchableContext bc) {
   /* Id recordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName()
      .get('Workplace')
      .getRecordTypeId();*/
      String basid = '987654321';
    String soqlQuery =
      'Select id, BasunID__c From Account where BasunID__c != null and parent.BasunID__c =\'' +
      basid +
      '\'';
    return Database.getQueryLocator(soqlQuery);
  }
  global void execute(Database.BatchableContext bc, List<Account> acctIds) {
    List<Account> acclistToUpdate = new List<Account>();
    try {
      for (Account acctId : acctIds) {
        WorksiteDetails workplace = BasunCallout.getWorksiteInfo(
          acctId.BasunID__c,
          'sv'
        );
        result.add(workplace);
        if (workplace != null)
          acclistToUpdate.add(
           CompanyController.createWorksiteUpdate(workplace)
          );
      }

      system.debug('acclistToUpdate ' + acclistToUpdate);
      system.debug(
        'Heap size is ' +
        limits.getHeapSize() +
        ' enforced is ' +
        limits.getLimitHeapSize()
      );

      Schema.SObjectField basunExternalIdField = Account.Fields.BasunID__c;
      Database.UpsertResult[] upsertList = Database.upsert(
        acclistToUpdate,
        basunExternalIdField,
        false
      );
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
    }
  }

  global void finish(Database.BatchableContext bc) {
    //System.debug('result--> ' + result.size());
  }
    
  /*   public static Account createWorksiteUpdate(WorksiteDetails worksiteInfo) {
    String lang = 'sv';

    Id worksiteRecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName()
      .get(GlobalConstants.RECORDTYPE_WORKPLACE)
      .getRecordTypeId();

    Account acct = new Account();
    acct.recordtypeId = worksiteRecordTypeId;
    acct.parentBasunId__c = worksiteInfo.company.id;
    System.debug('worksiteInfo.id ' + worksiteInfo.id);
    acct.BasunID__c = worksiteInfo.id;
    acct.name = worksiteInfo.name;
    acct.BasunLastModified__c = (DateTime) JSON.deserialize(
      '"' +
      worksiteInfo.lastModified +
      '"',
      DateTime.class
    );

    acct.WorkplaceNumber__c = worksiteInfo.officialWorksiteNumber;
    acct.BasunStatus__c = worksiteInfo.status.name;
    acct.BasunType__c = worksiteInfo.type.name;

    if (worksiteInfo.internet.urls.size() > 0)
      acct.Website = string.join(worksiteInfo.internet.urls, ',');

    if (worksiteInfo.business.activities.mainActivity.code != null)
      acct.MainActivity__c =
        worksiteInfo.business.activities.mainActivity.code +
        ' ' +
        worksiteInfo.business.activities.mainActivity.description;

    if (worksiteInfo.business.activities.subActivities.size() > 0) {
      string temp = '';
      for (
        WorksiteDetails.cls_subActivities sub : worksiteInfo.business.activities.subActivities
      ) {
        temp += sub.code + ' ' + sub.description;
      }
      acct.SubActivitites__c = temp;
    }

    if (worksiteInfo.phones.size() > 0) {
      for (WorksiteDetails.cls_phones ph : worksiteInfo.phones) {
        if (ph.type == 'LeasedLine')
          acct.Phone = ph.phoneNumber;
        else if (ph.type == 'Mobile')
          acct.PersonMobilePhone = ph.phoneNumber;
      }
    }

    if (worksiteInfo.postalAddress != null) {
      acct.shippingStreet = worksiteInfo.postalAddress.address;
      acct.shippingCity = worksiteInfo.postalAddress.city;
      acct.shippingPostalCode = worksiteInfo.postalAddress.zipcode;

      if (worksiteInfo.postalAddress.county.name != null)
        acct.shippingState = worksiteInfo.postalAddress.county.name;

      if (worksiteInfo.postalAddress.country.name != null)
        acct.shippingCountry = worksiteInfo.postalAddress.country.name;

      acct.shippingCareOf__c = worksiteInfo.postalAddress.co;
    }

    if (worksiteInfo.visitAddress != null) {
      acct.billingStreet = worksiteInfo.visitAddress.address;
      acct.billingCity = worksiteInfo.visitAddress.city;
      acct.billingPostalCode = worksiteInfo.visitAddress.zipcode;
      acct.billingCareOf__c = worksiteInfo.visitAddress.co;

      if (worksiteInfo.visitAddress.county.name != null)
        acct.billingState = worksiteInfo.visitAddress.county.name;

      if (worksiteInfo.visitAddress.country.name != null)
        acct.billingCountry = worksiteInfo.visitAddress.country.name;
    }

    return acct;
  }
*/}