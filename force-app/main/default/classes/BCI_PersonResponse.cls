/**
 * @Author Jenny Blomberg
 * @description Class to represent response from BCI when asking for personData
 */
public class BCI_PersonResponse {

    public PersonData[] persons;
    

    public static BCI_PersonResponse parse(String json) {
        return (BCI_PersonResponse) System.JSON.deserialize(
            json.replaceAll('"number":', '"phoneNumber":'),
          BCI_PersonResponse.class
        ); 
    }

    public class PersonData {
        public BCI_Person person;
        public String lastModified;
    }

    public class BCI_Person {
        public String gedi;
        public BCI_LegalId legalId;
        public boolean protectedIdentity;
        public String[] firstNames;
        public String preferredFirstName;
        public String additionalName;
        public String familyName;
        public String fullName;
        public String gender;
        public String dateOfBirth;
        public Integer yearOfBirth;
        public boolean deceased;
        public String dateOfDeath;
        public BCI_PhoneList[] phoneList;
        public BCI_AddressList[] addressList;
        public boolean deregistered;

    }

    public class BCI_LegalId {
        public String socialSecurityNumber;
    }
    
    public class BCI_PhoneList {
        public String type;
        public String phoneNumber;
        public boolean telemarketingRestriction;
        public boolean secretPhoneNumber;
    }
    
    public class BCI_AddressList {
        public String type;
        public String subType;
        public String careOf;
        public String streetName;
        public String streetNumber;
        public String entrance;
        public String apartment;
        public String floor;
        public String postOfficeBox;
        public String postalCode;
        public String city;
        public String areaId;
        public String county;
        public String countyCode;
        public String districtCode;
        public String locality;
        public String municipality;
        public String municipalityCode;
        public String province;
        public String region;
        public String xcoordinate;
        public String ycoordinate;
        public String country;
        public String fullAddressString;
        public String[] formattedAddress;
    }

}