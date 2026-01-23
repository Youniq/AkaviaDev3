public class CompanySearchResponse {
  //public String $schema;	//https://api.bisnode.com/bbc/v2/schemas/company-search.schema.json
  @AuraEnabled
  public cls_companies[] companies { get; set; }
  @AuraEnabled
  public Integer hitsTotal { get; set; }
  @AuraEnabled
  public Integer maxSize { get; set; }
  @AuraEnabled
  public Integer offset { get; set; }
  @AuraEnabled
  public Integer hitsReturned { get; set; }
  @AuraEnabled
  public clsLinks links { get; set; }

  public class cls_companies {
    @AuraEnabled
    public String id { get; set; }
    @AuraEnabled
    public String name { get; set; }
    @AuraEnabled
    public String country { get; set; }
    @AuraEnabled
    public cls_postalAddress postalAddress { get; set; }
    @AuraEnabled
    public cls_status status { get; set; }
    @AuraEnabled
    public cls_type type { get; set; }
    @AuraEnabled
    public Integer numberOfWorksites { get; set; }
    @AuraEnabled
    public clsLinks links { get; set; }
  }
  public class cls_postalAddress {
    @AuraEnabled
    public String city { get; set; }
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
  public class clsLinks {
    @AuraEnabled
    public cls_next next { get; set; }
    @AuraEnabled
    public cls_self self { get; set; }
    @AuraEnabled
    public cls_last last { get; set; }
    @AuraEnabled
    public cls_first first { get; set; }
  }
  public class cls_company {
    @AuraEnabled
    public String href { get; set; }
  }
  public class cls_next {
    @AuraEnabled
    public String href { get; set; }
  }
  public class cls_self {
    @AuraEnabled
    public String href { get; set; }
  }
  public class cls_last {
    @AuraEnabled
    public String href { get; set; }
  }
  public class cls_first {
    @AuraEnabled
    public String href { get; set; }
  }
  public static CompanySearchResponse parse(String json) {
    json = json.replaceAll('_links', 'links');
    return (CompanySearchResponse) System.JSON.deserialize(
      json,
      CompanySearchResponse.class
    );
  }

  /*static testMethod void testParse() {
		String json=		'{'+
		'  "$schema": "https://api.bisnode.com/bbc/v2/schemas/company-search.schema.json",'+
		'  "companies": ['+
		'    {'+
		'      "id": "1:101215255",'+
		'      "name": "Karl Pettersson",'+
		'      "country": "SE",'+
		'      "postalAddress": {'+
		'        "city": "NORRKÖPING"'+
		'      },'+
		'      "status": {'+
		'        "code": "ST15",'+
		'        "name": "Company deregistered"'+
		'      },'+
		'      "type": {'+
		'        "code": "TY99",'+
		'        "name": "Unknown"'+
		'      },'+
		'      "numberOfWorksites": 1,'+
		'      "_links": {'+
		'        "company": {'+
		'          "href": "https://api.bisnode.com/bbc/v2/companies/1:101215255"'+
		'        }'+
		'      }'+
		'    },'+
		'    {'+
		'      "id": "1:101755189",'+
		'      "name": "HB Norrköpings Läkar-Och Kuratortjänst",'+
		'      "country": "SE",'+
		'      "postalAddress": {'+
		'        "city": "NORRKÖPING"'+
		'      },'+
		'      "status": {'+
		'        "code": "ST15",'+
		'        "name": "Company deregistered"'+
		'      },'+
		'      "type": {'+
		'        "code": "TY99",'+
		'        "name": "Unknown"'+
		'      },'+
		'      "numberOfWorksites": 0,'+
		'      "_links": {'+
		'        "company": {'+
		'          "href": "https://api.bisnode.com/bbc/v2/companies/1:101755189"'+
		'        }'+
		'      }'+
		'    },'+
		'    {'+
		'      "id": "1:101755193",'+
		'      "name": "HB Lida Byggtjänst",'+
		'      "country": "SE",'+
		'      "postalAddress": {'+
		'        "city": "NORRKÖPING"'+
		'      },'+
		'      "status": {'+
		'        "code": "ST15",'+
		'        "name": "Company deregistered"'+
		'      },'+
		'      "type": {'+
		'        "code": "TY99",'+
		'        "name": "Unknown"'+
		'      },'+
		'      "numberOfWorksites": 0,'+
		'      "_links": {'+
		'        "company": {'+
		'          "href": "https://api.bisnode.com/bbc/v2/companies/1:101755193"'+
		'        }'+
		'      }'+
		'    },'+
		'    {'+
		'      "id": "1:101756058",'+
		'      "name": "Elefef Förvaltning HB",'+
		'      "country": "SE",'+
		'      "postalAddress": {'+
		'        "city": "NORRKÖPING"'+
		'      },'+
		'      "status": {'+
		'        "code": "ST15",'+
		'        "name": "Company deregistered"'+
		'      },'+
		'      "type": {'+
		'        "code": "TY99",'+
		'        "name": "Unknown"'+
		'      },'+
		'      "numberOfWorksites": 0,'+
		'      "_links": {'+
		'        "company": {'+
		'          "href": "https://api.bisnode.com/bbc/v2/companies/1:101756058"'+
		'        }'+
		'      }'+
		'    },'+
		'    {'+
		'      "id": "1:101755139",'+
		'      "name": "Restaurang Peking House HB",'+
		'      "country": "SE",'+
		'      "postalAddress": {'+
		'        "city": "NORRKÖPING"'+
		'      },'+
		'      "status": {'+
		'        "code": "ST15",'+
		'        "name": "Company deregistered"'+
		'      },'+
		'      "type": {'+
		'        "code": "TY99",'+
		'        "name": "Unknown"'+
		'      },'+
		'      "numberOfWorksites": 0,'+
		'      "_links": {'+
		'        "company": {'+
		'          "href": "https://api.bisnode.com/bbc/v2/companies/1:101755139"'+
		'        }'+
		'      }'+
		'    },'+
		'    {'+
		'      "id": "1:101757978",'+
		'      "name": "HB Comet Hyrbil",'+
		'      "country": "SE",'+
		'      "postalAddress": {'+
		'        "city": "NORRKÖPING"'+
		'      },'+
		'      "status": {'+
		'        "code": "ST15",'+
		'        "name": "Company deregistered"'+
		'      },'+
		'      "type": {'+
		'        "code": "TY99",'+
		'        "name": "Unknown"'+
		'      },'+
		'      "numberOfWorksites": 0,'+
		'      "_links": {'+
		'        "company": {'+
		'          "href": "https://api.bisnode.com/bbc/v2/companies/1:101757978"'+
		'        }'+
		'      }'+
		'    },'+
		'    {'+
		'      "id": "1:101757979",'+
		'      "name": "Nordisk Radio- & TVS-Service KB",'+
		'      "country": "SE",'+
		'      "postalAddress": {'+
		'        "city": "NORRKÖPING"'+
		'      },'+
		'      "status": {'+
		'        "code": "ST10",'+
		'        "name": "Discontinued company"'+
		'      },'+
		'      "type": {'+
		'        "code": "TY99",'+
		'        "name": "Unknown"'+
		'      },'+
		'      "numberOfWorksites": 0,'+
		'      "_links": {'+
		'        "company": {'+
		'          "href": "https://api.bisnode.com/bbc/v2/companies/1:101757979"'+
		'        }'+
		'      }'+
		'    },'+
		'    {'+
		'      "id": "1:101758045",'+
		'      "name": "Sankt Anna Rör & Smide HB",'+
		'      "country": "SE",'+
		'      "postalAddress": {'+
		'        "city": "NORRKÖPING"'+
		'      },'+
		'      "status": {'+
		'        "code": "ST15",'+
		'        "name": "Company deregistered"'+
		'      },'+
		'      "type": {'+
		'        "code": "TY99",'+
		'        "name": "Unknown"'+
		'      },'+
		'      "numberOfWorksites": 0,'+
		'      "_links": {'+
		'        "company": {'+
		'          "href": "https://api.bisnode.com/bbc/v2/companies/1:101758045"'+
		'        }'+
		'      }'+
		'    },'+
		'    {'+
		'      "id": "1:101758058",'+
		'      "name": "Screenprint i Norrköping HB",'+
		'      "country": "SE",'+
		'      "postalAddress": {'+
		'        "city": "NORRKÖPING"'+
		'      },'+
		'      "status": {'+
		'        "code": "ST15",'+
		'        "name": "Company deregistered"'+
		'      },'+
		'      "type": {'+
		'        "code": "TY99",'+
		'        "name": "Unknown"'+
		'      },'+
		'      "numberOfWorksites": 0,'+
		'      "_links": {'+
		'        "company": {'+
		'          "href": "https://api.bisnode.com/bbc/v2/companies/1:101758058"'+
		'        }'+
		'      }'+
		'    },'+
		'    {'+
		'      "id": "1:101533478",'+
		'      "name": "Carolina Ählman",'+
		'      "country": "SE",'+
		'      "postalAddress": {'+
		'        "city": "NORRKÖPING"'+
		'      },'+
		'      "status": {'+
		'        "code": "ST15",'+
		'        "name": "Company deregistered"'+
		'      },'+
		'      "type": {'+
		'        "code": "TY99",'+
		'        "name": "Unknown"'+
		'      },'+
		'      "numberOfWorksites": 0,'+
		'      "_links": {'+
		'        "company": {'+
		'          "href": "https://api.bisnode.com/bbc/v2/companies/1:101533478"'+
		'        }'+
		'      }'+
		'    }'+
		'  ],'+
		'  "hitsTotal": 28347,'+
		'  "maxSize": 10,'+
		'  "offset": 0,'+
		'  "hitsReturned": 10,'+
		'  "_links": {'+
		'    "next": {'+
		'      "href": "https://api.bisnode.com/bbc/v2/companies?companyCity=Norrk%C3%B6ping&offset=10"'+
		'    },'+
		'    "self": {'+
		'      "href": "https://api.bisnode.com/bbc/v2/companies?companyCity=Norrk%C3%B6ping"'+
		'    },'+
		'    "last": {'+
		'      "href": "https://api.bisnode.com/bbc/v2/companies?companyCity=Norrk%C3%B6ping&offset=28340"'+
		'    },'+
		'    "first": {'+
		'      "href": "https://api.bisnode.com/bbc/v2/companies?companyCity=Norrk%C3%B6ping"'+
		'    }'+
		'  }'+
		'}';
		CompanySearchResponseJSON obj = parse(json);
		System.assert(obj != null);
	}*/
}