@isTest
private class PersonDataTest {
  @isTest
  static void testParseResponse() {
    PersonData resp = PersonData.parse(
      MockHttpResponseGenerator.personDataString()
    );

    PersonData.cls_person person = resp.person;
    String lastModified = resp.lastModified;
    String gedi = person.gedi;
    PersonData.cls_legalId legalId = person.legalId;
    boolean protectedIdentity = person.protectedIdentity;
    String[] firstNames = person.firstNames;
    String preferredFirstName = person.preferredFirstName;
    String additionalName = person.additionalName;
    String familyName = person.familyName;
    String fullName = person.fullName;
    String gender = person.gender;
    String dateOfBirth = person.dateOfBirth;
    Integer yearOfBirth = person.yearOfBirth;
    boolean deceased = person.deceased;
    String dateOfDeath = person.dateOfDeath;
    PersonData.cls_phoneList[] phoneList = person.phoneList;
    PersonData.cls_addressList[] addressList = person.addressList;
    boolean deregistered = person.deregistered;
    String socialSecurityNumber = legalId.socialSecurityNumber;
    String type = phoneList[0].type;
    String phoneNumber = phoneList[0].phoneNumber;
    boolean telemarketingRestriction = phoneList[0].telemarketingRestriction;
    boolean secretPhoneNumber = phoneList[0].secretPhoneNumber;
    String typeAddress = addressList[0].type;
    String subType = addressList[0].subType;
    String careOf = addressList[0].careOf;
    String streetName = addressList[0].streetName;
    String entrance = addressList[0].entrance;
    String apartment = addressList[0].apartment;
    String floor = addressList[0].floor;
    String postOfficeBox = addressList[0].postOfficeBox;
    String postalCode = addressList[0].postalCode;
    String city = addressList[0].city;
    String areaId = addressList[0].areaId;
    String county = addressList[0].county;
    String countyCode = addressList[0].countyCode;
    String districtCode = addressList[0].districtCode;
    String locality = addressList[0].locality;
    String municipality = addressList[0].municipality;
    String municipalityCode = addressList[0].municipalityCode;
    String province = addressList[0].province;
    String region = addressList[0].region;
    String xcoordinate = addressList[0].xcoordinate;
    String ycoordinate = addressList[0].ycoordinate;
    String country = addressList[0].country;
    String[] formattedAddress = addressList[0].formattedAddress;
  }
}