public class CompanyDetails {
  //public String $schema;	//https://api.bisnode.com/bbc/v2/schemas/company.schema.json
  @AuraEnabled
  public String lastModified { get; set; } //2020-06-20T09:07:27.141Z
  @AuraEnabled
  public String name { get; set; }
  @AuraEnabled
  public cls_country country { get; set; }
  @AuraEnabled
  public cls_status status { get; set; }
  @AuraEnabled
  public cls_type type { get; set; }
  @AuraEnabled
  public String registrationDate { get; set; } //2002-01-07
  @AuraEnabled
  public String nationalRegistrationNumber { get; set; } //5566219050
  @AuraEnabled
  public String vatNo { get; set; } //SE556621905001
  @AuraEnabled
  public Integer numberOfWorksites { get; set; }
  @AuraEnabled
  public cls_postalAddress postalAddress 
      {
    get {
      if (postalAddress == null) {
        postalAddress = new CompanyDetails.cls_postalAddress();
      }
      return postalAddress;
    }
    set;
  }
  @AuraEnabled
  public cls_phones[] phones {
    get {
      if (phones == null) {
        phones = new List<CompanyDetails.cls_phones>();
      }
      return phones;
    }
    set;
  }

  @AuraEnabled
  public cls_internet internet {
    get {
      if (internet == null) {
        internet = new CompanyDetails.cls_internet();
      }
      return internet;
    }
    set;
  }
  @AuraEnabled
  public cls_legalForm legalForm { get; set; }
  //@AuraEnabled
  //public cls_economy economy;
  //@AuraEnabled
  //public cls_group clsGroup; // group
  @AuraEnabled
  public cls_business business { get; set; }
  //@AuraEnabled
  //public String addressSource;
  @AuraEnabled
  public String id { get; set; }
 // @AuraEnabled
//  public clsLinks links { get; set; } //_link
  @AuraEnabled
  public Integer numberOfEmployeesValue { get; set; }

  public class cls_country {
    @AuraEnabled
    public String code { get; set; } //SE
    @AuraEnabled
    public String name { get; set; } //Sweden
  }
  public class cls_status {
    @AuraEnabled
    public String code { get; set; }
    @AuraEnabled
    public String name { get; set; }
  }
  public class cls_type {
    @AuraEnabled
    public String code { get; set; } //TY10
    @AuraEnabled
    public String name { get; set; } //Head Office
  }
  public class cls_postalAddress {
    @AuraEnabled
    public String address { get; set; }
      
    @AuraEnabled
    public String zipcode { get; set; } //10302
    @AuraEnabled
    public String city { get; set; } //STOCKHOLM
    @AuraEnabled
    public String co { get; set; }
    @AuraEnabled
    public cls_country country {
      get {
        if (country == null) {
          country = new CompanyDetails.cls_country();
        }
        return country;
      }
      set;
    }

    @AuraEnabled
    public cls_county county {
      get {
        if (county == null) {
          county = new CompanyDetails.cls_county();
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
    public String code { get; set; } //GR01
    @AuraEnabled
    public String name { get; set; } //Stockholm
  }

  public class cls_municipality {
    public String code; //GK0180
    public String name; //Stockholm
  }
  public class cls_SE_Aregion {
    public String code; //GA01
    public String name; //Stockholm/Södertälje
  }
  public class cls_phones {
    @AuraEnabled
    public String type { get; set; }
    @AuraEnabled
    public String phoneNumber { get; set; }
    @AuraEnabled
    public boolean blocked { get; set; }
  }
  public class cls_internet {
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

    @AuraEnabled
    public cls_emails[] emails {
      get {
        if (emails == null) {
          emails = new List<CompanyDetails.cls_emails>();
        }
        return emails;
      }
      set;
    }
  }
  public class cls_emails {
    @AuraEnabled
    public String address { get; set; }
    @AuraEnabled
    public boolean blocked { get; set; }
  }
  public class cls_urls {
    @AuraEnabled
    public String href { get; set; }
  }
  public class cls_legalForm {
    @AuraEnabled
    public String code { get; set; }
    @AuraEnabled
    public String name { get; set; }
  }

  public class cls_business {
    @AuraEnabled
    public cls_activities activities { get; set; }
    @AuraEnabled
    public cls_numberOfEmployees numberOfEmployees { get; set; }
    public cls_numberOfOfficeEmployees numberOfOfficeEmployees;
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
          subActivities = new List<CompanyDetails.cls_subActivities>();
        }
        return subActivities;
      }
      set;
    }
  }
  public class cls_mainActivity {
    @AuraEnabled
    public String code { get; set; } //HG70220
    @AuraEnabled
    public String description { get; set; } //Business and other management consultancy activities
  }
  public class cls_subActivities {
    @AuraEnabled
    public String code { get; set; } //SN62010
    @AuraEnabled
    public String description { get; set; } //Computer programming activities
  }
  public class cls_numberOfEmployees {
    @AuraEnabled
    public String code { get; set; } //AA03
    @AuraEnabled
    public String name { get; set; } //5 - 9
  }
  class cls_numberOfOfficeEmployees {
    public String code; //KA99
    public String name; //Unknown
  }
 /* class clsLinks {
    public cls_self self { get; set; }
    public cls_worksites[] worksites { get; set; }
  }
  class cls_self {
    public String href { get; set; }
  }
  class cls_worksites {
    public String href { get; set; } //https://api.bisnode.com/bbc/v2/worksites/1:202025298
    public cls_status status { get; set; }
    public cls_type type { get; set; }
  }*/
  public static CompanyDetails parse(String json) {
    json = json.replace('"$lastModified":', '"lastModified":');
    json = json.replaceAll('_links', 'links');
    json = json.replaceAll('"number":', '"phoneNumber":');
    return (CompanyDetails) System.JSON.deserialize(json, CompanyDetails.class);
  }
}
/*
	static testMethod void testParse() {
		String json=		'{'+
		'  "$schema": "https://api.bisnode.com/bbc/v2/schemas/company.schema.json",'+
		'  "$lastModified": "2020-06-20T09:07:27.141Z",'+
		'  "name": "Stretch AB",'+
		'  "country": {'+
		'    "code": "SE",'+
		'    "name": "Sweden"'+
		'  },'+
		'  "status": {'+
		'    "code": "ST00",'+
		'    "name": "Active"'+
		'  },'+
		'  "type": {'+
		'    "code": "TY50",'+
		'    "name": "Private company"'+
		'  },'+
		'  "registrationDate": "2002-01-07",'+
		'  "nationalRegistrationNumber": "5566219050",'+
		'  "vatNo": "SE556621905001",'+
		'  "numberOfWorksites": 1,'+
		'  "postalAddress": {'+
		'    "address": "Box 13087",'+
		'    "zipcode": "10302",'+
		'    "city": "STOCKHOLM",'+
		'    "country": {'+
		'      "code": "SE",'+
		'      "name": "Sweden"'+
		'    },'+
		'    "county": {'+
		'      "code": "GR01",'+
		'      "name": "Stockholm"'+
		'    },'+
		'    "municipality": {'+
		'      "code": "GK0180",'+
		'      "name": "Stockholm"'+
		'    },'+
		'    "SE_Aregion": {'+
		'      "code": "GA01",'+
		'      "name": "Stockholm/Södertälje"'+
		'    }'+
		'  },'+
		'  "phones": ['+
		'    {'+
		'      "type": "LeasedLine",'+
		'      "number": "+46 8240080",'+
		'      "blocked": false'+
		'    }'+
		'  ],'+
		'  "internet": {'+
		'    "urls": ['+
		'      "www.stretch.se"'+
		'    ]'+
		'  },'+
		'  "legalForm": {'+
		'    "code": "JF49",'+
		'    "name": "Limited company"'+
		'  },'+
		'  "economy": {'+
		'    "shareCapital": {'+
		'      "code": "AK09",'+
		'      "name": "0 - 25",'+
		'      "nameCurrency": "KEUR",'+
		'      "value": 119000,'+
		'      "currency": "SEK",'+
		'      "accountingPeriodStart": "201801",'+
		'      "accountingPeriodEnd": "201812"'+
		'    },'+
		'    "turnover": {'+
		'      "code": "OM04",'+
		'      "name": "2000 - 5000",'+
		'      "nameCurrency": "KEUR",'+
		'      "value": 21972000,'+
		'      "currency": "SEK",'+
		'      "accountingPeriodStart": "201801",'+
		'      "accountingPeriodEnd": "201812"'+
		'    },'+
		'    "turnoverChange": {'+
		'      "code": "NO20",'+
		'      "name": "-50% - -25%",'+
		'      "rate": -45,'+
		'      "accountingPeriodStart": "201801",'+
		'      "accountingPeriodEnd": "201812"'+
		'    },'+
		'    "solvency": {'+
		'      "code": "NS80",'+
		'      "name": "> 50%",'+
		'      "rate": 69,'+
		'      "accountingPeriodStart": "201801",'+
		'      "accountingPeriodEnd": "201812"'+
		'    }'+
		'  },'+
		'  "group": {'+
		'    "groupParent": {'+
		'      "id": "1:101153181",'+
		'      "nationalRegistrationNumber": "5566298013",'+
		'      "name": "Maelum & Partner AB",'+
		'      "country": {'+
		'        "code": "SE",'+
		'        "name": "Sweden"'+
		'      }'+
		'    },'+
		'    "parent": {'+
		'      "id": "1:102754530",'+
		'      "nationalRegistrationNumber": "5568562184",'+
		'      "name": "Maelum Holding AB",'+
		'      "country": {'+
		'        "code": "SE",'+
		'        "name": "Sweden"'+
		'      }'+
		'    },'+
		'    "subsidiaries": ['+
		'      {'+
		'        "id": "1:102924065",'+
		'        "nationalRegistrationNumber": "5569174849",'+
		'        "name": "Stretch Addera AB",'+
		'        "country": {'+
		'          "code": "SE",'+
		'          "name": "Sweden"'+
		'        }'+
		'      },'+
		'      {'+
		'        "id": "1:102787884",'+
		'        "nationalRegistrationNumber": "5568679053",'+
		'        "name": "Stretch Public AB",'+
		'        "country": {'+
		'          "code": "SE",'+
		'          "name": "Sweden"'+
		'        }'+
		'      },'+
		'      {'+
		'        "id": "1:103528953",'+
		'        "nationalRegistrationNumber": "5591525398",'+
		'        "name": "Stretch Procurement AB",'+
		'        "country": {'+
		'          "code": "SE",'+
		'          "name": "Sweden"'+
		'        }'+
		'      },'+
		'      {'+
		'        "id": "1:103528952",'+
		'        "nationalRegistrationNumber": "5591525380",'+
		'        "name": "Stretch Evolve AB",'+
		'        "country": {'+
		'          "code": "SE",'+
		'          "name": "Sweden"'+
		'        }'+
		'      },'+
		'      {'+
		'        "id": "1:101876390",'+
		'        "nationalRegistrationNumber": "5567288039",'+
		'        "name": "Stretch Stockholm AB",'+
		'        "country": {'+
		'          "code": "SE",'+
		'          "name": "Sweden"'+
		'        }'+
		'      },'+
		'      {'+
		'        "nationalRegistrationNumber": "3330840491",'+
		'        "name": "Stretch Norge AS",'+
		'        "country": {'+
		'          "code": "NO",'+
		'          "name": "Norway"'+
		'        }'+
		'      },'+
		'      {'+
		'        "id": "1:101129630",'+
		'        "nationalRegistrationNumber": "5566297973",'+
		'        "name": "Stretch Öresund AB",'+
		'        "country": {'+
		'          "code": "SE",'+
		'          "name": "Sweden"'+
		'        }'+
		'      },'+
		'      {'+
		'        "id": "1:103528950",'+
		'        "nationalRegistrationNumber": "5591525364",'+
		'        "name": "Stretch Customer AB",'+
		'        "country": {'+
		'          "code": "SE",'+
		'          "name": "Sweden"'+
		'        }'+
		'      },'+
		'      {'+
		'        "id": "1:103528955",'+
		'        "nationalRegistrationNumber": "5591525414",'+
		'        "name": "Stretch Care AB",'+
		'        "country": {'+
		'          "code": "SE",'+
		'          "name": "Sweden"'+
		'        }'+
		'      },'+
		'      {'+
		'        "nationalRegistrationNumber": "3330866926",'+
		'        "name": "Stretch Denmark ApS",'+
		'        "country": {'+
		'          "code": "DK",'+
		'          "name": "Denmark"'+
		'        }'+
		'      },'+
		'      {'+
		'        "id": "1:102261789",'+
		'        "nationalRegistrationNumber": "5568357049",'+
		'        "name": "Stretch Select AB",'+
		'        "country": {'+
		'          "code": "SE",'+
		'          "name": "Sweden"'+
		'        }'+
		'      },'+
		'      {'+
		'        "id": "1:101930035",'+
		'        "nationalRegistrationNumber": "5567432090",'+
		'        "name": "Stretch Göteborg AB",'+
		'        "country": {'+
		'          "code": "SE",'+
		'          "name": "Sweden"'+
		'        }'+
		'      }'+
		'    ]'+
		'  },'+
		'  "business": {'+
		'    "activities": {'+
		'      "mainActivity": {'+
		'        "code": "HG7022",'+
		'        "description": "Business and other management consultancy activities"'+
		'      },'+
		'      "subActivities": ['+
		'        {'+
		'          "code": "NC6201",'+
		'          "description": "Computer programming activities"'+
		'        },'+
		'        {'+
		'          "code": "NC6202",'+
		'          "description": "Computer consultancy activities"'+
		'        },'+
		'        {'+
		'          "code": "NC6209",'+
		'          "description": "Other information technology and computer service activities"'+
		'        }'+
		'      ],'+
		'      "local": {'+
		'        "mainActivity": {'+
		'          "code": "HG70220",'+
		'          "description": "Business and other management consultancy activities"'+
		'        },'+
		'        "subActivities": ['+
		'          {'+
		'            "code": "SN62010",'+
		'            "description": "Computer programming activities"'+
		'          },'+
		'          {'+
		'            "code": "SN62020",'+
		'            "description": "Computer consultancy activities"'+
		'          },'+
		'          {'+
		'            "code": "SN62090",'+
		'            "description": "Other information technology and computer service activities"'+
		'          },'+
		'          {'+
		'            "code": "OV1129",'+
		'            "description": "Top Level companies 2009"'+
		'          }'+
		'        ]'+
		'      }'+
		'    },'+
		'    "numberOfEmployees": {'+
		'      "code": "AA03",'+
		'      "name": "5 - 9"'+
		'    },'+
		'    "numberOfOfficeEmployees": {'+
		'      "code": "KA99",'+
		'      "name": "Unknown"'+
		'    }'+
		'  },'+
		'  "addressSource": "PARAD, 169 93 Solna, Sweden",'+
		'  "id": "1:101081322",'+
		'  "_links": {'+
		'    "self": {'+
		'      "href": "https://api.bisnode.com/bbc/v2/companies/1:101081322"'+
		'    },'+
		'    "parent": {'+
		'      "href": "https://api.bisnode.com/bbc/v2/companies/1:102754530"'+
		'    },'+
		'    "groupParent": {'+
		'      "href": "https://api.bisnode.com/bbc/v2/companies/1:101153181"'+
		'    },'+
		'    "worksites": ['+
		'      {'+
		'        "href": "https://api.bisnode.com/bbc/v2/worksites/1:202025298",'+
		'        "status": {'+
		'          "code": "ST00",'+
		'          "name": "Active"'+
		'        },'+
		'        "type": {'+
		'          "code": "TY10",'+
		'          "name": "Head Office"'+
		'        }'+
		'      }'+
		'    ],'+
		'    "subsidiaries": ['+
		'      {'+
		'        "href": "https://api.bisnode.com/bbc/v2/companies/1:102924065"'+
		'      },'+
		'      {'+
		'        "href": "https://api.bisnode.com/bbc/v2/companies/1:102787884"'+
		'      },'+
		'      {'+
		'        "href": "https://api.bisnode.com/bbc/v2/companies/1:103528953"'+
		'      },'+
		'      {'+
		'        "href": "https://api.bisnode.com/bbc/v2/companies/1:103528952"'+
		'      },'+
		'      {'+
		'        "href": "https://api.bisnode.com/bbc/v2/companies/1:101876390"'+
		'      },'+
		'      {'+
		'        "href": "https://api.bisnode.com/bbc/v2/companies/1:101129630"'+
		'      },'+
		'      {'+
		'        "href": "https://api.bisnode.com/bbc/v2/companies/1:103528950"'+
		'      },'+
		'      {'+
		'        "href": "https://api.bisnode.com/bbc/v2/companies/1:103528955"'+
		'      },'+
		'      {'+
		'        "href": "https://api.bisnode.com/bbc/v2/companies/1:102261789"'+
		'      },'+
		'      {'+
		'        "href": "https://api.bisnode.com/bbc/v2/companies/1:101930035"'+
		'      }'+
		'    ]'+
		'  },'+
		'  "numberOfEmployeesValue": 7'+
		'}';
		CompanyDetails obj = parse(json);
		System.assert(obj != null);} */