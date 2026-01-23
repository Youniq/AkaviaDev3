@isTest
private class CompanyDetailsTest {
  @isTest
  static void testParseResponse() {
    CompanyDetails resp = CompanyDetails.parse(
      MockHttpResponseGenerator.downloadCompanyString()
    );
    string last = resp.lastModified;
    CompanyDetails.cls_postalAddress postadress = resp.postalAddress;
    string adress = postadress.address;
    string city = postadress.city;
    string co = postadress.co;
    CompanyDetails.cls_country postalCountry = postadress.country;
    String cCode = postalCountry.code;
    String cName = postalCountry.name;
    CompanyDetails.cls_county postalCounty = postadress.county;
    String coCode = postalCounty.code;
    String coName = postalCounty.name;
    CompanyDetails.cls_municipality municipality = postadress.municipality;
    String munCode = municipality.code;
    String munName = municipality.name;
    CompanyDetails.cls_SE_Aregion seregion = postadress.SE_Aregion;
    String rCode = seregion.code;
    String rName = seregion.name;
    String zipcode = postadress.zipcode;
    String name = resp.name;

    CompanyDetails.cls_country country = resp.country;
    CompanyDetails.cls_status status = resp.status;
    String statusoCode = status.code;
    String statusName = status.name;
    CompanyDetails.cls_type type = resp.type;
    String typeCode = type.code;
    String typeName = type.name;
    CompanyDetails.cls_phones[] phones = resp.phones;
    String phonestype = phones[0].type;
    String phonrNr = phones[0].phoneNumber;
    boolean b = phones[0].blocked;
    CompanyDetails.cls_business business = resp.business;
    CompanyDetails.cls_numberOfEmployees numberEmpl = business.numberOfEmployees;
    String numName = numberEmpl.name;
    String numCode = numberEmpl.code;
    CompanyDetails.cls_activities bactiv = business.activities;
    // CompanyDetails.cls_local blocal = bactiv.local;
    //CompanyDetails.cls_mainActivity bmain = blocal.mainActivity;
    //CompanyDetails.cls_subActivities[] subLocalList = blocal.subActivities;
    //String addressSource = resp.addressSource;
    String wid = resp.id;
    CompanyDetails.cls_mainActivity main = bactiv.mainActivity;
    String maincode = main.code;
    String mainDesc = main.description;
    CompanyDetails.cls_subActivities[] subList = bactiv.subActivities;
    String subCode = subList[0].code;
    String subDesc = subList[0].description;
    String registrationDate = resp.registrationDate;
    String nationalRegistrationNumber = resp.nationalRegistrationNumber;
    String vatNo = resp.vatNo;
    Integer numberOfWorksites = resp.numberOfWorksites;
    CompanyDetails.cls_internet internet = resp.internet;
    CompanyDetails.cls_emails[] emails = internet.emails;
    String[] url = internet.urls;
    String urls = url[0];

    CompanyDetails.cls_legalForm legalForm = new CompanyDetails.cls_legalForm(); // = resp.legalForm;
    legalForm.name = 'lname';
    legalForm.code = 'lCode';
    Integer nre = resp.numberOfEmployeesValue;
  }
}