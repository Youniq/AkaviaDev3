public class CompanyController {
  
  @AuraEnabled
  public static CodeTypesResponse fetchCodeTypes(String codeTypePrefix) {
    CodeTypesResponse resp = BasunCallout.getCodeTypes(codeTypePrefix);
    return resp;
  }
  
  @AuraEnabled
  public static CompanySearchResponse fetchCompany(
    String companyNumber,
    String companyCity,
    String companyLegalName,
    String companyPostalAddress,
    String companyStatus,
    String companyType
  ) {
    CompanySearchResponse resp = BasunCallout.getCompanies(
      companyNumber,
      companyCity,
      companyLegalName,
      companyPostalAddress,
      companyStatus, 
      companyType
    );
    return resp;
  }

  @AuraEnabled
  public static CompanySearchResponse fetchCompanyByUrl(String urlString) {
    CompanySearchResponse resp = BasunCallout.getCompaniesByLink(urlString);
    return resp;
  }

  @AuraEnabled
  public static WorksiteSearchResponse fetchWorksitesByUrl(String urlString) {
    WorksiteSearchResponse resp = BasunCallout.getWorksitesByLink(urlString);
    return resp;
  }

  @AuraEnabled
  public static CompanyDetails downloadCompany(String companyId, String lang) {
    CompanyDetails resp = BasunCallout.getCompanyInfo(companyId, lang);
    return resp;
  }

  @AuraEnabled
  public static WorksiteDetails downloadWorksite(
    String worksiteId,
    String lang
  ) {
    WorksiteDetails resp = BasunCallout.getWorksiteInfo(worksiteId, lang);
    return resp;
  }

  @AuraEnabled
  public static WorksiteSearchResponse fetchWorksite(
    String companyNumber,
    String worksiteNumber,
    String companyLegalNameWorksite,
    String worksiteAddress,
    String worksiteCity,
    String worksiteStatus,
    String worksiteType
  ) {
    WorksiteSearchResponse resp = BasunCallout.getWorksites(
      companyNumber,
      worksiteNumber,
      companyLegalNameWorksite,
      worksiteAddress,
      worksiteCity,
      worksiteStatus,
      worksiteType
    );
    return resp;
  }

  @AuraEnabled
  public static wrapperResponse upsertCompany(CompanyDetails compInfo) {
    system.debug(compInfo.nationalRegistrationNumber);
    system.debug(compInfo.name);
    system.debug(compInfo);
    wrapperResponse resp = new wrapperResponse();
    boolean uppsert = true;
    boolean isUpserted = true;

    String msg = '';
    List<Account> acctList = [
      SELECT Id, BasunID__c, ExcludeFromUpdate__c
      FROM Account
      WHERE BasunID__c = :compInfo.id
    ];

    try {
      if (acctList.size() > 0 && acctList[0].ExcludeFromUpdate__c) {
        msg = 'Arbetsgivare kan ej uppdateras. Undanta från BASUN uppdatering';
        uppsert = false;
        isUpserted = false;
      }

      if (uppsert) {
        List<Account> acclist = new List<Account>();

        acclist.add(createCompanyUpdate(compInfo));
        Schema.SObjectField bidnodeId = Account.Fields.BasunID__c;
        Database.UpsertResult[] upsertList = Database.upsert(
          acclist,
          bidnodeId,
          false
        );

        if (upsertList[0].isSuccess()) {
          System.debug(
            'Successfully inserted account. Account ID: ' +
            upsertList[0].getId()
          );
          resp.accountId = upsertList[0].getId();
        } else {
          for (Database.Error err : upsertList[0].getErrors()) {
            System.debug('The following error has occurred.');
            System.debug(err.getStatusCode() + ': ' + err.getMessage());
            System.debug(
              'Account fields that affected this error: ' + err.getFields()
            );
            msg +=
              'Arbetsgivare kan ej uppdateras. ' +
              err.getStatusCode() +
              ' : ' +
              err.getMessage();
            msg +=
              ' /n Account fields that affected this error: ' + err.getFields();
            isUpserted = false;
          }
        }
      }
    } catch (Exception e) {
      msg += 'Något har gått fel. ';
      msg +=
        ' *** ' +
        e.getMessage() +
        '*** Line number--> ' +
        e.getLineNumber();
      msg += ' *** StackTraceString --> ' + e.getStackTraceString();
      isUpserted = false;
    }

    resp.isUpserted = isUpserted;
    resp.message = msg;
    return resp;
  }

  public static Account createCompanyUpdate(CompanyDetails compInfo) {
    Id companyRecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName()
      .get(GlobalConstants.RECORDTYPE_EMPLOYER)
      .getRecordTypeId();

    Account acct = new Account();
    acct.BasunID__c = compInfo.id;
    acct.recordtypeId = companyRecordTypeId;
    acct.name = compInfo.name;
    acct.BasunLastModified__c = (DateTime) JSON.deserialize(
      '"' +
      compInfo.lastModified +
      '"',
      DateTime.class
    );
    acct.NumberOfEmployees__c = compInfo.business.numberOfEmployees.name;
    acct.OrganisationNumber__c = compInfo.nationalRegistrationNumber;
    acct.BasunStatus__c = compInfo.status.name;
    acct.BasunType__c = compInfo.type.name;
    acct.RegistrationDate__c = Date.valueOf(compInfo.registrationDate);

    if (compInfo.business.activities.mainActivity.code != null) {
      String hgCode = compInfo.business.activities.mainActivity.code;
      acct.MainActivity__c =
        compInfo.business.activities.mainActivity.code +
        ' ' +
        compInfo.business.activities.mainActivity.description;

      if (hgCode.length() > 2)
        acct.SNICode__c = hgCode.substring(2);
    }

    if (compInfo.business.activities.subActivities.size() > 0) {
      string temp = '';
      for (
        CompanyDetails.cls_subActivities sub : compInfo.business.activities.subActivities
      ) {
        temp += sub.code + ' ' + sub.description;
      }
      acct.SubActivitites__c = temp;
    }


    acct.shippingStreet = compInfo.postalAddress.address;
    acct.shippingCity = compInfo.postalAddress.city;
    acct.shippingPostalCode = compInfo.postalAddress.zipcode;

    if (compInfo.postalAddress.county.name != null)
      acct.shippingState = compInfo.postalAddress.county.name;

    if (compInfo.postalAddress.country.name != null)
      acct.shippingCountry = compInfo.postalAddress.country.name;

    acct.shippingcareof__c = compInfo.postalAddress.co;

    acct.LegalFormCode__c = Decimal.valueOf(
      compInfo.legalForm.code.substring(2)
    );
    acct.NumberOfWorksites__c = compInfo.numberOfWorksites;
    if (compInfo.internet.urls.size() > 0)
      acct.Website = string.join(compInfo.internet.urls, ',');

    if (compInfo.internet.emails.size() > 0)
      acct.email__c = compInfo.internet.emails[0].address;

    if (compInfo.phones.size() > 0) {
      for (CompanyDetails.cls_phones ph : compInfo.phones) {
        if (ph.type == 'LeasedLine')
          acct.Phone = ph.phoneNumber;
        else if (ph.type == 'Mobile')
          acct.PersonMobilePhone = ph.phoneNumber;
      }
    }

    return acct;
  }

  @AuraEnabled
  public static wrapperResponse upsertWorksite(WorksiteDetails worksiteInfo) {
    system.debug(
      'Worksite-->  org nummber: ' +
      worksiteInfo.company.nationalRegistrationNumber
    );
    system.debug(
      'Worksite-->  Bisnide arbetsgivare id: ' + worksiteInfo.company.id
    );
    wrapperResponse resp = new wrapperResponse();
    boolean uppsert = true;
    boolean isUpserted = true;

    String msg = '';
    List<Account> worksiteList = [
      SELECT
        Id,
        BasunID__c,
        Parent.ExcludeFromUpdate__c,
        Parent.BasunID__c,
        ParentId
      FROM Account
      WHERE BasunID__c = :worksiteInfo.id
    ];

    try {
      if (
        worksiteList.size() > 0 && worksiteList[0].Parent.ExcludeFromUpdate__c
      ) {
        msg = 'Arbetsställe kan ej uppdateras. Undanta från BASUN uppdatering';
        uppsert = false;
        isUpserted = false;
      }

      if (isUpserted) {
        List<Account> acclist = new List<Account>();
        acclist.add(createWorksiteUpdate(worksiteInfo));
        Schema.SObjectField bidnodeId = Account.Fields.BasunID__c;

        Database.UpsertResult[] upsertList = Database.upsert(
          acclist,
          bidnodeId,
          false
        );

        if (upsertList[0].isSuccess()) {
          System.debug(
            'Successfully inserted account. Account ID: ' +
            upsertList[0].getId()
          );
          resp.accountId = upsertList[0].getId();
        } else {
          isUpserted = false;
          System.debug('upsertList[0].getErrors()' + upsertList[0].getErrors());
          for (Database.Error err : upsertList[0].getErrors()) {
            System.debug('The following error has occurred.');
            System.debug(err.getStatusCode() + ': ' + err.getMessage());
            System.debug(
              'Account fields that affected this error: ' + err.getFields()
            );
            msg +=
              'Arbetsställe kan ej uppdateras. ' +
              err.getStatusCode() +
              ' : ' +
              err.getMessage();
            msg +=
              ' Account fields that affected this error: ' + err.getFields();
          }
        }
      }
    } catch (Exception e) {
      msg += 'Något har gått fel. ';
      msg +=
        ' *** ' +
        e.getMessage() +
        '*** Line number--> ' +
        e.getLineNumber();
      msg += ' *** StackTraceString --> ' + e.getStackTraceString();
      isUpserted = false;
    }

    resp.isUpserted = isUpserted;
    resp.message = msg;
    return resp;
  }

  public static Account createWorksiteUpdate(WorksiteDetails worksiteInfo) {
    String lang = 'sv';
    List<Account> parentAccountList = [
      SELECT Id, BasunID__c, Parent.ExcludeFromUpdate__c, Parent.BasunID__c
      FROM Account
      WHERE BasunID__c = :worksiteInfo.company.id
    ];
    String parentId;

    if (parentAccountList.size() > 0) {
      parentId = parentAccountList[0].Id;
      System.debug('parentId ' + parentId);
    } else {
      CompanyDetails comInfo = BasunCallout.getCompanyInfo(
        worksiteInfo.company.id,
        lang
      );
      System.debug('comInfo ' + comInfo);
      wrapperResponse newCompany = upsertCompany(comInfo);
      System.debug('newCompany ' + newCompany);
      parentId = newCompany.accountId;
    }

    Id worksiteRecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName()
      .get(GlobalConstants.RECORDTYPE_WORKPLACE)
      .getRecordTypeId();

    Account acct = new Account();
    acct.recordtypeId = worksiteRecordTypeId;
    acct.ParentId = parentId;
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

  public class wrapperResponse {
    @AuraEnabled
    public String accountId { get; set; }
    @AuraEnabled
    public String message { get; set; }
    @AuraEnabled
    public Boolean isUpserted { get; set; }
  }
}