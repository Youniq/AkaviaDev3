public class PersonData {
  public cls_person person { get; set; }
  public String lastModified { get; set; }
  //  public cls_sourceList[] sourceList;
  public class cls_person {
    public String gedi { get; set; }
    public cls_legalId legalId { get; set; }
    public boolean protectedIdentity { get; set; }
    public String[] firstNames { get; set; }
   
      public String preferredFirstName {
      get {
        if (preferredFirstName == null) {
          preferredFirstName = '';
        }
        return preferredFirstName;
      }
      set;
    }
    public String additionalName { get; set; }
    
   public String familyName {
      get {
        if (familyName == null) {
          familyName = '';
        }
        return familyName;
      }
      set;
    }
      
    public String fullName { get; set; }
    
      public String gender {
      get {
        if (gender == null) {
          gender = '';
        }
        return gender;
      }
      set;
    }

    public String dateOfBirth { get; set; }
    public Integer yearOfBirth { get; set; }
    public boolean deceased { get; set; }
    public String dateOfDeath { get; set; }
    public cls_phoneList[] phoneList { get; set; }
    public cls_addressList[] addressList { get; set; }
    public boolean deregistered { get; set; }
  }
  public class cls_legalId {
  
      public String socialSecurityNumber {
      get {
        if (socialSecurityNumber == null) {
          socialSecurityNumber = '';
        }
        return socialSecurityNumber;
      }
      set;
    }
  }

  public class cls_firstNames {
    public String[] name { get; set; }
  }

  public class cls_phoneList {
    public String type { get; set; }
    public String phoneNumber { get; set; }
    public boolean telemarketingRestriction { get; set; }
    public boolean secretPhoneNumber { get; set; }
  }

  public class cls_addressList {
    public String type { get; set; }
    public String subType { get; set; }

    public String careOf {
      get {
        if (careOf == null) {
          careOf = '';
        }
        return careOf;
      }
      set;
    }

    public String streetName {
      get {
        if (streetName == null) {
          streetName = '';
        }
        return streetName;
      }
      set;
    }

    public String streetNumber {
      get {
        if (streetNumber == null) {
          streetNumber = '';
        }
        return streetNumber;
      }
      set;
    }
    public String entrance {
      get {
        if (entrance == null) {
          entrance = '';
        }
        return entrance;
      }
      set;
    }

    public String apartment {
      get {
        if (apartment == null) {
          apartment = '';
        }
        return apartment;
      }
      set;
    }

    public String floor { get; set; }
   public String postOfficeBox {
      get {
        if (postOfficeBox == null) {
          postOfficeBox = '';
        }
        return postOfficeBox;
      }
      set;
    }

    public String postalCode {
      get {
        if (postalCode == null) {
          postalCode = '';
        }
        return postalCode;
      }
      set;
    }

    public String city {
      get {
        if (city == null) {
          city = '';
        }
        return city;
      }
      set;
    }
    public String areaId { get; set; }
    public String county {
      get {
        if (county == null) {
          county = '';
        }
        return county;
      }
      set;
    }
    public String countyCode {
      get {
        if (countyCode == null) {
          countyCode = '';
        }
        return countyCode;
      }
      set;
    }

    public String districtCode { get; set; }
    public String locality { get; set; }
    public String municipality { get; set; }
    public String municipalityCode { get; set; }
    public String province { get; set; }
    public String region {
      get {
        if (region == null) {
          region = '';
        }
        return region;
      }
      set;
    }
    public String xcoordinate { get; set; }
    public String ycoordinate { get; set; }
    public String country { get; set; }
    public String[] formattedAddress { get; set; }
  }
  public static PersonData parse(String json) {
    json = json.replaceAll('"number":', '"phoneNumber":');
    return (PersonData) System.JSON.deserialize(json, PersonData.class);
  }
}