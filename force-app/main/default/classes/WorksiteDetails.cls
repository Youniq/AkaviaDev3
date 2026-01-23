public class WorksiteDetails {
  @AuraEnabled
  public String lastModified { get; set; }
  @AuraEnabled
  public String name { get; set; }
  @AuraEnabled
  public cls_country country { get; set; }
  @AuraEnabled
  public cls_status status { get; set; }
  @AuraEnabled
  public cls_type type { get; set; }
  @AuraEnabled
  public String officialWorksiteNumber { get; set; }
  @AuraEnabled
  public cls_postalAddress postalAddress {
    get {
      if (postalAddress == null) {
        postalAddress = new cls_postalAddress();
      }
      return postalAddress;
    }
    set;
  }
  @AuraEnabled
  public cls_visitAddress visitAddress {
    get {
      if (visitAddress == null) {
        visitAddress = new cls_visitAddress();
      }
      return visitAddress;
    }
    set;
  }

  @AuraEnabled
  public cls_company company { get; set; }
  @AuraEnabled
  public cls_phones[] phones {
    get {
      if (phones == null) {
        phones = new List<WorksiteDetails.cls_phones>();
      }
      return phones;
    }
    set;
  }
  @AuraEnabled
  public clsInternet internet {
    get {
      if (internet == null) {
        internet = new WorksiteDetails.clsInternet();
      }
      return internet;
    }
    set;
  }
  @AuraEnabled
  public cls_business business { get; set; }
  @AuraEnabled
  public String addressSource { get; set; }
  @AuraEnabled
  public String id { get; set; }
  @AuraEnabled
  public clsLinks links { get; set; }

  public class cls_country {
    @AuraEnabled
    public String code { get; set; }
    @AuraEnabled
    public String name { get; set; }
  }
  public class cls_status {
    @AuraEnabled
    public String code { get; set; }
    @AuraEnabled
    public String name { get; set; }
  }

  public class cls_type {
    @AuraEnabled
    public String code { get; set; }
    @AuraEnabled
    public String name { get; set; }
  }
  public class cls_postalAddress {
    @AuraEnabled
    public String address { get; set; }
    @AuraEnabled
    public String zipcode { get; set; }
    @AuraEnabled
    public String co { get; set; }
    @AuraEnabled
    public String city { get; set; }
    @AuraEnabled
    public cls_country country {
      get {
        if (country == null) {
          country = new WorksiteDetails.cls_country();
        }
        return country;
      }
      set;
    }

    @AuraEnabled
    public cls_county county {
      get {
        if (county == null) {
          county = new WorksiteDetails.cls_county();
        }
        return county;
      }
      set;
    }
    @AuraEnabled
    public cls_municipality municipality {
      get {
        if (municipality == null) {
          municipality = new cls_municipality();
        }
        return municipality;
      }
      set;
    }

    @AuraEnabled
    public cls_SE_Aregion SE_Aregion {
      get {
        if (SE_Aregion == null) {
          SE_Aregion = new cls_SE_Aregion();
        }
        return SE_Aregion;
      }
      set;
    }
  }
  public class cls_county {
    @AuraEnabled
    public String code { get; set; }
    @AuraEnabled
    public String name { get; set; }
  }
  public class cls_municipality {
    @AuraEnabled
    public String code {
      get {
        if (code == null) {
          code = '';
        }
        return code;
      }
      set;
    }
    @AuraEnabled
    public String name {
      get {
        if (name == null) {
          name = '';
        }
        return name;
      }
      set;
    }
  }
  public class cls_SE_Aregion {
    @AuraEnabled
    public String code {
      get {
        if (code == null) {
          code = '';
        }
        return code;
      }
      set;
    }

    @AuraEnabled
    public String name {
      get {
        if (name == null) {
          name = '';
        }
        return name;
      }
      set;
    }
  }
  public class cls_visitAddress {
    @AuraEnabled
    public String address { get; set; }
    @AuraEnabled
    public String co { get; set; }
    @AuraEnabled
    public String zipcode { get; set; }
    @AuraEnabled
    public String city { get; set; }
    @AuraEnabled
    public cls_country country {
      get {
        if (country == null) {
          country = new WorksiteDetails.cls_country();
        }
        return country;
      }
      set;
    }

    @AuraEnabled
    public cls_county county {
      get {
        if (county == null) {
          county = new WorksiteDetails.cls_county();
        }
        return county;
      }
      set;
    }
    @AuraEnabled
    public cls_municipality municipality {
      get {
        if (municipality == null) {
          municipality = new cls_municipality();
        }
        return municipality;
      }
      set;
    }

    @AuraEnabled
    public cls_SE_Aregion SE_Aregion {
      get {
        if (SE_Aregion == null) {
          SE_Aregion = new cls_SE_Aregion();
        }
        return SE_Aregion;
      }
      set;
    }
  }
  public class cls_company {
    @AuraEnabled
    public String id { get; set; }
    @AuraEnabled
    public String nationalRegistrationNumber { get; set; }
    @AuraEnabled
    public String href { get; set; } //https://api.bisnode.com/bbc/v2/companies/1:100006601
  }
  public class cls_phones {
    @AuraEnabled
    public String type { get; set; }
    @AuraEnabled
    public String phoneNumber { get; set; }
    @AuraEnabled
    public boolean blocked { get; set; }
  }
  public class clsInternet {
    @AuraEnabled
    public String[] urls {
      get {
        if (urls == null) {
          urls = new List<String>();
        }
        return urls;
      }
      set;
    }
  }

  public class cls_business {
    @AuraEnabled
    public cls_activities activities { get; set; }
    @AuraEnabled
    public cls_mainCommunicationLanguage mainCommunicationLanguage { get; set; }
    @AuraEnabled
    public cls_numberOfEmployees numberOfEmployees { get; set; }
    @AuraEnabled
    public cls_numberOfOfficeEmployees numberOfOfficeEmployees { get; set; }
    public cls_trade trade;
  }
  public class cls_activities {
    @AuraEnabled
    public cls_mainActivity mainActivity {
      get {
        if (mainActivity == null) {
          mainActivity = new cls_mainActivity();
        }
        return mainActivity;
      }
      set;
    }

    @AuraEnabled
    public cls_subActivities[] subActivities {
      get {
        if (subActivities == null) {
          subActivities = new List<WorksiteDetails.cls_subActivities>();
        }
        return subActivities;
      }
      set;
    }
    // public cls_local local;
  }
  public class cls_mainActivity {
    @AuraEnabled
    public String code { get; set; } //HG84115
    @AuraEnabled
    public String description { get; set; } //Supporting service activities for the government as a whole
  }
  public class cls_subActivities {
    @AuraEnabled
    public String code { get; set; } //SN84112
    @AuraEnabled
    public String description { get; set; } //Inspection, control, licensing activ
  }
  public class cls_mainCommunicationLanguage {
    public String code; //SV
    public String name; //Swedish
  }
  public class cls_numberOfEmployees {
    @AuraEnabled
    public String code; //AA09
    @AuraEnabled
    public String name; //500 - 999
  }
  public class cls_numberOfOfficeEmployees {
    public String code; //KA99
    public String name; //Unknown
  }
  public class cls_trade {
    public boolean importing;
    public boolean exporting;
  }
  public class clsLinks {
    public cls_self self;
    public cls_company company;
    public cls_employments[] employments;
  }
  public class cls_self {
    public String href; //https://api.bisnode.com/bbc/v2/worksites/1:201416831
  }
  public class cls_employments {
    public String href; //https://api.bisnode.com/bbc/v2/employments/1:402458683
    public cls_status status;
    public cls_mainPosition mainPosition;
  }
  public class cls_mainPosition {
    public String code; //BE2540001
    public String description; //Other Decision Maker
  }
  public static WorksiteDetails parse(String json) {
    json = json.replace('"$lastModified":', '"lastModified":');
    json = json.replaceAll('_links', 'links');
    json = json.replaceAll('"number":', '"phoneNumber":');

    return (WorksiteDetails) System.JSON.deserialize(
      json,
      WorksiteDetails.class
    );
  }
}
/*
	static testMethod void testParse() {
		String json=		'{'+
		'  "$schema": "https://api.bisnode.com/bbc/v2/schemas/worksite.schema.json",'+
		'  "$lastModified": "2019-09-17T09:22:25.339Z",'+
		'  "name": "Migrationsverket Mottagningsenheten & IT enheten",'+
		'  "country": {'+
		'    "code": "SE",'+
		'    "name": "Sweden"'+
		'  },'+
		'  "status": {'+
		'    "code": "ST00",'+
		'    "name": "Active"'+
		'  },'+
		'  "type": {'+
		'    "code": "TY20",'+
		'    "name": "Branch office"'+
		'  },'+
		'  "officialWorksiteNumber": "42338723",'+
		'  "postalAddress": {'+
		'    "zipcode": "60170",'+
		'    "city": "NORRKÖPING",'+
		'    "country": {'+
		'      "code": "SE",'+
		'      "name": "Sweden"'+
		'    },'+
		'    "county": {'+
		'      "code": "GR05",'+
		'      "name": "Östergötland"'+
		'    },'+
		'    "municipality": {'+
		'      "code": "GK0581",'+
		'      "name": "Norrköping"'+
		'    },'+
		'    "SE_Aregion": {'+
		'      "code": "GA10",'+
		'      "name": "Norrköping"'+
		'    }'+
		'  },'+
		'  "visitAddress": {'+
		'    "address": "Slottsgatan 81-82",'+
		'    "zipcode": "60222",'+
		'    "city": "NORRKÖPING",'+
		'    "country": {'+
		'      "code": "SE",'+
		'      "name": "Sweden"'+
		'    },'+
		'    "county": {'+
		'      "code": "GR05",'+
		'      "name": "Östergötland"'+
		'    },'+
		'    "municipality": {'+
		'      "code": "GK0581",'+
		'      "name": "Norrköping"'+
		'    },'+
		'    "SE_Aregion": {'+
		'      "code": "GA10",'+
		'      "name": "Norrköping"'+
		'    }'+
		'  },'+
		'  "company": {'+
		'    "nationalRegistrationNumber": "2021002163",'+
		'    "id": "1:100006601"'+
		'  },'+
		'  "phones": ['+
		'    {'+
		'      "type": "LeasedLine",'+
		'      "number": "+46 771235235",'+
		'      "blocked": false'+
		'    }'+
		'  ],'+
		'  "internet": {'+
		'    "urls": ['+
		'      "www.migrationsverket.se"'+
		'    ]'+
		'  },'+
		'  "business": {'+
		'    "activities": {'+
		'      "mainActivity": {'+
		'        "code": "HG8411",'+
		'        "description": "General public administration activities"'+
		'      },'+
		'      "subActivities": [],'+
		'      "local": {'+
		'        "mainActivity": {'+
		'          "code": "HG84115",'+
		'          "description": "Supporting service activities for the government as a whole"'+
		'        },'+
		'        "subActivities": ['+
		'          {'+
		'            "code": "SN84112",'+
		'            "description": "Inspection, control, licensing activ"'+
		'          }'+
		'        ]'+
		'      }'+
		'    },'+
		'    "mainCommunicationLanguage": {'+
		'      "code": "SV",'+
		'      "name": "Swedish"'+
		'    },'+
		'    "numberOfEmployees": {'+
		'      "code": "AA09",'+
		'      "name": "500 - 999"'+
		'    },'+
		'    "numberOfOfficeEmployees": {'+
		'      "code": "KA99",'+
		'      "name": "Unknown"'+
		'    },'+
		'    "trade": {'+
		'      "importing": false,'+
		'      "exporting": false'+
		'    }'+
		'  },'+
		'  "addressSource": "PARAD, 169 93 Solna, Sweden",'+
		'  "id": "1:201416831",'+
		'  "_links": {'+
		'    "self": {'+
		'      "href": "https://api.bisnode.com/bbc/v2/worksites/1:201416831"'+
		'    },'+
		'    "company": {'+
		'      "href": "https://api.bisnode.com/bbc/v2/companies/1:100006601"'+
		'    },'+
		'    "employments": ['+
		'      {'+
		'        "href": "https://api.bisnode.com/bbc/v2/employments/1:402458683",'+
		'        "status": {'+
		'          "code": "ST00",'+
		'          "name": "Active"'+
		'        },'+
		'        "mainPosition": {'+
		'          "code": "BE2540001",'+
		'          "description": "Other Decision Maker"'+
		'        }'+
		'      }'+
		'    ]'+
		'  }'+
		'}';
		WorksiteSearchResponse obj = parse(json);
		System.assert(obj != null);
	}*/