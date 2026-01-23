public class WorksiteSearchResponse {
  @AuraEnabled
  public String schema { get; set; }
  @AuraEnabled
  public cls_worksites[] worksites { get; set; }
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

  public class cls_worksites {
    @AuraEnabled
    public String id { get; set; }
    @AuraEnabled
    public String name { get; set; }
    @AuraEnabled
    public String country { get; set; }
    @AuraEnabled
    public cls_visitingAddress visitingAddress { get; set; }
    @AuraEnabled
    public cls_postalAddress postalAddress { get; set; }
    @AuraEnabled
    public cls_status status { get; set; }
    @AuraEnabled
    public cls_type type { get; set; }
    @AuraEnabled
    public Integer numberOfContacts { get; set; }
    @AuraEnabled
    public cls_company company { get; set; }
    @AuraEnabled
    public clsLinks links { get; set; }
  }
  public class cls_visitingAddress {
    @AuraEnabled
    public String address { get; set; }
    @AuraEnabled
    public String city { get; set; }
  }
  public class cls_postalAddress {
    @AuraEnabled
    public String city;
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
  public class cls_company {
    @AuraEnabled
    public String href { get; set; }
  }
  public class clsLinks {
    @AuraEnabled
    public cls_next next { get; set; }
    public cls_self self;
    public cls_last last;
    public cls_first first;
  }
  public class cls_worksite {
    public String href; //https://api.bisnode.com/bbc/v2/worksites/1:201221352
  }
  public class cls_next {
    @AuraEnabled
    public String href { get; set; }
  }
  public class cls_self {
    public String href; //https://api.bisnode.com/bbc/v2/worksites?companyNumber=202100-2163
  }
  public class cls_last {
    public String href; //https://api.bisnode.com/bbc/v2/worksites?companyNumber=202100-2163&offset=160
  }
  public class cls_first {
    public String href; //https://api.bisnode.com/bbc/v2/worksites?companyNumber=202100-2163
  }
  public static WorksiteSearchResponse parse(String json) {
    json = json.replaceAll('\\$', '');
    json = json.replaceAll('_links', 'links');

    return (WorksiteSearchResponse) System.JSON.deserialize(
      json,
      WorksiteSearchResponse.class
    );
  }
}
/** 
	static testMethod void testParse() {
		String json=		'{'+
		'  "$schema": "https://api.bisnode.com/bbc/v2/schemas/worksite-search.schema.json",'+
		'  "worksites": ['+
		'    {'+
		'      "id": "1:201221352",'+
		'      "name": "Migrationsverket",'+
		'      "country": "SE",'+
		'      "visitingAddress": {'+
		'        "address": "Lars Janssonsgatan 10",'+
		'        "city": "KIRUNA"'+
		'      },'+
		'      "postalAddress": {'+
		'        "city": "KIRUNA"'+
		'      },'+
		'      "status": {'+
		'        "code": "ST00",'+
		'        "name": "Active"'+
		'      },'+
		'      "type": {'+
		'        "code": "TY20",'+
		'        "name": "Branch office"'+
		'      },'+
		'      "numberOfContacts": 0,'+
		'      "company": {'+
		'        "id": "1:100006601",'+
		'        "legalName": "Migrationsverket"'+
		'      },'+
		'      "_links": {'+
		'        "worksite": {'+
		'          "href": "https://api.bisnode.com/bbc/v2/worksites/1:201221352"'+
		'        },'+
		'        "company": {'+
		'          "href": "https://api.bisnode.com/bbc/v2/companies/1:100006601"'+
		'        }'+
		'      }'+
		'    },'+
		'    {'+
		'      "id": "1:201257025",'+
		'      "name": "Migrationsverket",'+
		'      "country": "SE",'+
		'      "visitingAddress": {'+
		'        "address": "Dalavägen 55 A",'+
		'        "city": "FAGERSTA"'+
		'      },'+
		'      "postalAddress": {'+
		'        "city": "FAGERSTA"'+
		'      },'+
		'      "status": {'+
		'        "code": "ST13",'+
		'        "name": "Discontinued unit"'+
		'      },'+
		'      "type": {'+
		'        "code": "TY20",'+
		'        "name": "Branch office"'+
		'      },'+
		'      "numberOfContacts": 0,'+
		'      "company": {'+
		'        "id": "1:100006601",'+
		'        "legalName": "Migrationsverket"'+
		'      },'+
		'      "_links": {'+
		'        "worksite": {'+
		'          "href": "https://api.bisnode.com/bbc/v2/worksites/1:201257025"'+
		'        },'+
		'        "company": {'+
		'          "href": "https://api.bisnode.com/bbc/v2/companies/1:100006601"'+
		'        }'+
		'      }'+
		'    },'+
		'    {'+
		'      "id": "1:201416831",'+
		'      "name": "Migrationsverket Mottagningsenheten & IT enheten",'+
		'      "country": "SE",'+
		'      "visitingAddress": {'+
		'        "address": "Slottsgatan 81-82",'+
		'        "city": "NORRKÖPING"'+
		'      },'+
		'      "postalAddress": {'+
		'        "city": "NORRKÖPING"'+
		'      },'+
		'      "status": {'+
		'        "code": "ST00",'+
		'        "name": "Active"'+
		'      },'+
		'      "type": {'+
		'        "code": "TY20",'+
		'        "name": "Branch office"'+
		'      },'+
		'      "numberOfContacts": 1,'+
		'      "company": {'+
		'        "id": "1:100006601",'+
		'        "legalName": "Migrationsverket"'+
		'      },'+
		'      "_links": {'+
		'        "worksite": {'+
		'          "href": "https://api.bisnode.com/bbc/v2/worksites/1:201416831"'+
		'        },'+
		'        "company": {'+
		'          "href": "https://api.bisnode.com/bbc/v2/companies/1:100006601"'+
		'        }'+
		'      }'+
		'    },'+
		'    {'+
		'      "id": "1:202570401",'+
		'      "name": "Migrationsverket",'+
		'      "country": "SE",'+
		'      "visitingAddress": {'+
		'        "address": "Östra Madenvägen 6",'+
		'        "city": "SUNDBYBERG"'+
		'      },'+
		'      "postalAddress": {'+
		'        "city": "SOLNA"'+
		'      },'+
		'      "status": {'+
		'        "code": "ST13",'+
		'        "name": "Discontinued unit"'+
		'      },'+
		'      "type": {'+
		'        "code": "TY20",'+
		'        "name": "Branch office"'+
		'      },'+
		'      "numberOfContacts": 0,'+
		'      "company": {'+
		'        "id": "1:100006601",'+
		'        "legalName": "Migrationsverket"'+
		'      },'+
		'      "_links": {'+
		'        "worksite": {'+
		'          "href": "https://api.bisnode.com/bbc/v2/worksites/1:202570401"'+
		'        },'+
		'        "company": {'+
		'          "href": "https://api.bisnode.com/bbc/v2/companies/1:100006601"'+
		'        }'+
		'      }'+
		'    },'+
		'    {'+
		'      "id": "1:200153637",'+
		'      "name": "Migrationsverket Enheten Laxå",'+
		'      "country": "SE",'+
		'      "visitingAddress": {'+
		'        "address": "Saltängsvägen 4",'+
		'        "city": "LAXÅ"'+
		'      },'+
		'      "postalAddress": {'+
		'        "city": "LAXÅ"'+
		'      },'+
		'      "status": {'+
		'        "code": "ST13",'+
		'        "name": "Discontinued unit"'+
		'      },'+
		'      "type": {'+
		'        "code": "TY20",'+
		'        "name": "Branch office"'+
		'      },'+
		'      "numberOfContacts": 1,'+
		'      "company": {'+
		'        "id": "1:100006601",'+
		'        "legalName": "Migrationsverket"'+
		'      },'+
		'      "_links": {'+
		'        "worksite": {'+
		'          "href": "https://api.bisnode.com/bbc/v2/worksites/1:200153637"'+
		'        },'+
		'        "company": {'+
		'          "href": "https://api.bisnode.com/bbc/v2/companies/1:100006601"'+
		'        }'+
		'      }'+
		'    },'+
		'    {'+
		'      "id": "1:202827677",'+
		'      "name": "Migrationsverket",'+
		'      "country": "SE",'+
		'      "visitingAddress": {'+
		'        "address": "Järnvägsgatan 14",'+
		'        "city": "SUNDBYBERG"'+
		'      },'+
		'      "postalAddress": {'+
		'        "city": "SOLNA"'+
		'      },'+
		'      "status": {'+
		'        "code": "ST00",'+
		'        "name": "Active"'+
		'      },'+
		'      "type": {'+
		'        "code": "TY20",'+
		'        "name": "Branch office"'+
		'      },'+
		'      "numberOfContacts": 0,'+
		'      "company": {'+
		'        "id": "1:100006601",'+
		'        "legalName": "Migrationsverket"'+
		'      },'+
		'      "_links": {'+
		'        "worksite": {'+
		'          "href": "https://api.bisnode.com/bbc/v2/worksites/1:202827677"'+
		'        },'+
		'        "company": {'+
		'          "href": "https://api.bisnode.com/bbc/v2/companies/1:100006601"'+
		'        }'+
		'      }'+
		'    },'+
		'    {'+
		'      "id": "1:202648874",'+
		'      "name": "Migrationsverket",'+
		'      "country": "SE",'+
		'      "visitingAddress": {'+
		'        "address": "Kyrkogatan 22 A",'+
		'        "city": "MORA"'+
		'      },'+
		'      "postalAddress": {'+
		'        "city": "MORA"'+
		'      },'+
		'      "status": {'+
		'        "code": "ST13",'+
		'        "name": "Discontinued unit"'+
		'      },'+
		'      "type": {'+
		'        "code": "TY20",'+
		'        "name": "Branch office"'+
		'      },'+
		'      "numberOfContacts": 0,'+
		'      "company": {'+
		'        "id": "1:100006601",'+
		'        "legalName": "Migrationsverket"'+
		'      },'+
		'      "_links": {'+
		'        "worksite": {'+
		'          "href": "https://api.bisnode.com/bbc/v2/worksites/1:202648874"'+
		'        },'+
		'        "company": {'+
		'          "href": "https://api.bisnode.com/bbc/v2/companies/1:100006601"'+
		'        }'+
		'      }'+
		'    },'+
		'    {'+
		'      "id": "1:200940734",'+
		'      "name": "Migrationsverket",'+
		'      "country": "SE",'+
		'      "visitingAddress": {'+
		'        "address": "Stormgatan 9-11",'+
		'        "city": "MALMÖ"'+
		'      },'+
		'      "postalAddress": {'+
		'        "city": "MALMÖ"'+
		'      },'+
		'      "status": {'+
		'        "code": "ST13",'+
		'        "name": "Discontinued unit"'+
		'      },'+
		'      "type": {'+
		'        "code": "TY20",'+
		'        "name": "Branch office"'+
		'      },'+
		'      "numberOfContacts": 0,'+
		'      "company": {'+
		'        "id": "1:100006601",'+
		'        "legalName": "Migrationsverket"'+
		'      },'+
		'      "_links": {'+
		'        "worksite": {'+
		'          "href": "https://api.bisnode.com/bbc/v2/worksites/1:200940734"'+
		'        },'+
		'        "company": {'+
		'          "href": "https://api.bisnode.com/bbc/v2/companies/1:100006601"'+
		'        }'+
		'      }'+
		'    },'+
		'    {'+
		'      "id": "1:202872041",'+
		'      "name": "Migrationsverket",'+
		'      "country": "SE",'+
		'      "visitingAddress": {'+
		'        "address": "Förrådsvägen 3",'+
		'        "city": "LJUNGBYHED"'+
		'      },'+
		'      "postalAddress": {'+
		'        "city": "LJUNGBYHED"'+
		'      },'+
		'      "status": {'+
		'        "code": "ST00",'+
		'        "name": "Active"'+
		'      },'+
		'      "type": {'+
		'        "code": "TY20",'+
		'        "name": "Branch office"'+
		'      },'+
		'      "numberOfContacts": 0,'+
		'      "company": {'+
		'        "id": "1:100006601",'+
		'        "legalName": "Migrationsverket"'+
		'      },'+
		'      "_links": {'+
		'        "worksite": {'+
		'          "href": "https://api.bisnode.com/bbc/v2/worksites/1:202872041"'+
		'        },'+
		'        "company": {'+
		'          "href": "https://api.bisnode.com/bbc/v2/companies/1:100006601"'+
		'        }'+
		'      }'+
		'    },'+
		'    {'+
		'      "id": "1:201255229",'+
		'      "name": "Migrationsverket",'+
		'      "country": "SE",'+
		'      "visitingAddress": {'+
		'        "address": "Bjursdalsvägen 15 C",'+
		'        "city": "BOXHOLM"'+
		'      },'+
		'      "postalAddress": {'+
		'        "city": "BOXHOLM"'+
		'      },'+
		'      "status": {'+
		'        "code": "ST13",'+
		'        "name": "Discontinued unit"'+
		'      },'+
		'      "type": {'+
		'        "code": "TY20",'+
		'        "name": "Branch office"'+
		'      },'+
		'      "numberOfContacts": 0,'+
		'      "company": {'+
		'        "id": "1:100006601",'+
		'        "legalName": "Migrationsverket"'+
		'      },'+
		'      "_links": {'+
		'        "worksite": {'+
		'          "href": "https://api.bisnode.com/bbc/v2/worksites/1:201255229"'+
		'        },'+
		'        "company": {'+
		'          "href": "https://api.bisnode.com/bbc/v2/companies/1:100006601"'+
		'        }'+
		'      }'+
		'    }'+
		'  ],'+
		'  "hitsTotal": 161,'+
		'  "maxSize": 10,'+
		'  "offset": 0,'+
		'  "hitsReturned": 10,'+
		'  "_links": {'+
		'    "next": {'+
		'      "href": "https://api.bisnode.com/bbc/v2/worksites?companyNumber=202100-2163&offset=10"'+
		'    },'+
		'    "self": {'+
		'      "href": "https://api.bisnode.com/bbc/v2/worksites?companyNumber=202100-2163"'+
		'    },'+
		'    "last": {'+
		'      "href": "https://api.bisnode.com/bbc/v2/worksites?companyNumber=202100-2163&offset=160"'+
		'    },'+
		'    "first": {'+
		'      "href": "https://api.bisnode.com/bbc/v2/worksites?companyNumber=202100-2163"'+
		'    }'+
		'  }'+
		'}';
		WorksiteSearchResponse obj = parse(json);
		System.assert(obj != null);
	}
}**/