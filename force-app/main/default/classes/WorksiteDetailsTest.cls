@isTest
private class WorksiteDetailsTest {
  @isTest
  static void testParseResponse() {
    WorksiteDetails resp = WorksiteDetails.parse(
      MockHttpResponseGenerator.downloadWorksiteString()
    );
    string last = resp.lastModified;
    WorksiteDetails.cls_postalAddress postadress = resp.postalAddress;
    string adress = postadress.address;
    string city = postadress.city;
    string co = postadress.co;
    WorksiteDetails.cls_country postalCountry = postadress.country;
    String cCode = postalCountry.code;
    String cName = postalCountry.name;
    WorksiteDetails.cls_county postalCounty = postadress.county;
    String coCode = postalCounty.code;
    String coName = postalCounty.name;
    WorksiteDetails.cls_municipality municipality = postadress.municipality;
    WorksiteDetails.cls_SE_Aregion seregion = postadress.SE_Aregion;
    String rCode = seregion.code;
    String rName = seregion.name;
    String zipcode = postadress.zipcode;
    String name = resp.name;
    WorksiteDetails.cls_visitAddress visitadress = resp.visitAddress;
    string visitadressadress = visitadress.address;
    string visitadresscity = visitadress.city;
    string visitadressco = visitadress.co;
    WorksiteDetails.cls_country visitadressCountry = visitadress.country;
    WorksiteDetails.cls_county visitCounty = visitadress.county;
    WorksiteDetails.cls_municipality vmunicipality = visitadress.municipality;
    String mCode = vmunicipality.code;
    String mName = vmunicipality.name;
    WorksiteDetails.cls_SE_Aregion visitregion = visitadress.SE_Aregion;
    String vCode = visitregion.code;
    String vName = visitregion.name;
    String vzipcode = visitadress.zipcode;
    WorksiteDetails.cls_country country = resp.country;
    WorksiteDetails.cls_status status = resp.status;
    String statusoCode = status.code;
    String statusName = status.name;
    WorksiteDetails.cls_type type = resp.type;
    String typeCode = type.code;
    String typeName = type.name;
    String officialWorksiteNumber = resp.officialWorksiteNumber;
    WorksiteDetails.cls_company comp = resp.company;
    String href = comp.href;
    String compId = comp.id;
    String nrn = comp.nationalRegistrationNumber;
    WorksiteDetails.cls_phones[] phones = resp.phones;
    String phonestype = phones[0].type;
    String phonrNr = phones[0].phoneNumber;
    boolean b = phones[0].blocked;
    WorksiteDetails.cls_business business = resp.business;
    WorksiteDetails.clsInternet internet = resp.internet;
    String[] urls = internet.urls;
    WorksiteDetails.cls_activities bactiv = business.activities;
    // WorksiteDetails.cls_local blocal = bactiv.local;
    //WorksiteDetails.cls_mainActivity bmain = blocal.mainActivity;
    //WorksiteDetails.cls_subActivities[] subLocalList = blocal.subActivities;
    String addressSource = resp.addressSource;
    String wid = resp.id;
    WorksiteDetails.cls_mainActivity main = bactiv.mainActivity;
    String maincode = main.code;
    String mainDesc = main.description;
    WorksiteDetails.cls_subActivities[] subList = bactiv.subActivities;
    String subCode = subList[0].code;
    String subDesc = subList[0].description;
  }
}