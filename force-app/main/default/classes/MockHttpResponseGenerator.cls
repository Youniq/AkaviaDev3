/**
 * @description       :
 * @author            : Malin Nilsson (Stretch Customer AB)
 * @group             :
 * @last modified on  : 2024-04-23
 * @last modified by  : Malin Nilsson (Stretch Customer AB)
 **/
@isTest
global class MockHttpResponseGenerator implements HttpCalloutMock {
  String endPoint;
  public MockHttpResponseGenerator(String endPoint) {
    this.endPoint = endPoint;
  }

  global HTTPResponse respond(HTTPRequest req) {
    HttpResponse res;
    if (endPoint == 'token')
      res = getTokenResponse();
    else if (endpoint == 'getCompanies')
      res = getCompnaniesResponse();
    else if (endpoint == 'getCompanyInfo')
      res = getCompanyInfoResponse();
    else if (endpoint == 'subscribeCompany')
      res = subscribeCompanyResponse();
    else if (endpoint == 'getWorksites')
      res = getWorksitesResponse();
    else if (endpoint == 'getWorksiteInfo')
      res = getWorksiteInfoResponse();
    else if (endpoint == 'subscribeWorksite')
      res = subscribeWorksiteResponse();
    else if (endpoint == 'subscribeRemovedWorksite')
      res = subscribeWorksiteRemovedResponse();
    else if (endpoint == 'getDownloadPersonInfo')
      res = downloadPersonInfo();
    else if (endpoint == 'getRecordFromPortfolio')
      res = getRecordFromPortfolio();
    else if (endpoint == 'BCIMonitoringResponseString')
      res = BCIMonitoringResponse();
    else if (endpoint == 'BCIMonitoringResponseFalse')
      res = BCIMonitoringResponseFalse();
    else if (endPoint == 'responseCode500')
      res = responseCode500();

    return res;
  }

  public static HttpResponse getTokenResponse() {
    HttpResponse res = new HttpResponse();
    res.setHeader('Content-Type', 'application/json');
    res.setBody('{"access_token":"8UT28QKGTiAhjNk5yJj","token_type":"Bearer"}');
    return res;
  }

  public static HttpResponse BCIMonitoringResponse() {
    HttpResponse res = new HttpResponse();
    res.setHeader('Content-Type', 'application/json');
    res.setBody(BCIMonitoringResponseString());
    res.setStatusCode(200);
    return res;
  }

  public static HttpResponse BCIMonitoringResponseFalse() {
    HttpResponse res = new HttpResponse();
    res.setHeader('Content-Type', 'application/json');
    res.setBody(BCIMonitoringResponseString());
    res.setStatusCode(201);
    return res;
  }

  public static HttpResponse downloadPersonInfo() {
    HttpResponse res = new HttpResponse();
    res.setHeader('Content-Type', 'application/json');
    res.setBody(personDataString());
    res.setStatusCode(200);
    return res;
  }

  public static HttpResponse getRecordFromPortfolio() {
    HttpResponse res = new HttpResponse();
    res.setHeader('Content-Type', 'application/json');
    res.setBody('{"status":"single_hit","gedi":"12345"}');
    res.setStatusCode(200);
    return res;
  }

  public static HttpResponse getCompnaniesResponse() {
    HttpResponse res = new HttpResponse();
    res.setHeader('Content-Type', 'application/json');
    res.setBody(searchCompanyString());
    res.setStatusCode(200);
    return res;
  }

  public static HttpResponse getCompanyInfoResponse() {
    HttpResponse res = new HttpResponse();
    res.setHeader('Content-Type', 'application/json');
    res.setBody(downloadCompanyString());
    res.setStatusCode(200);
    return res;
  }

  public static HttpResponse subscribeCompanyResponse() {
    HttpResponse res = new HttpResponse();
    res.setBody(subscribeCompanyString());
    res.setStatusCode(200);
    return res;
  }

  public static HttpResponse getWorksitesResponse() {
    HttpResponse res = new HttpResponse();
    res.setHeader('Content-Type', 'application/json');
    res.setBody(searchWorksiteString());
    res.setStatusCode(200);
    return res;
  }

  public static HttpResponse getWorksiteInfoResponse() {
    HttpResponse res = new HttpResponse();
    res.setHeader('Content-Type', 'application/json');
    res.setBody(downloadWorksiteString());
    res.setStatusCode(200);
    return res;
  }

  public static HttpResponse subscribeWorksiteResponse() {
    HttpResponse res = new HttpResponse();
    res.setBody(subscribeWorksiteString());
    res.setStatusCode(200);
    return res;
  }

  public static HttpResponse subscribeWorksiteRemovedResponse() {
    HttpResponse res = new HttpResponse();
    res.setBody(subscribeRemovedWorksiteString());
    res.setStatusCode(200);
    return res;
  }

  public static HttpResponse responseCode500() {
    HttpResponse res = new HttpResponse();
    res.setBody('{}');
    res.setStatusCode(500);
    return res;
  }

  public static string searchCompanyString() {
    String resp =
      '{' +
      '  "$schema": "https://api.bisnode.com/bbc/v2/schemas/company-search.schema.json",' +
      '  "companies": [' +
      '    {' +
      '      "id": "1:101215255",' +
      '      "name": "Karl Pettersson",' +
      '      "country": "SE",' +
      '      "postalAddress": {' +
      '        "city": "NORRKÖPING"' +
      '      },' +
      '      "status": {' +
      '        "code": "ST15",' +
      '        "name": "Company deregistered"' +
      '      },' +
      '      "type": {' +
      '        "code": "TY99",' +
      '        "name": "Unknown"' +
      '      },' +
      '      "numberOfWorksites": 1,' +
      '      "_links": {' +
      '        "company": {' +
      '          "href": "https://api.bisnode.com/bbc/v2/companies/1:101215255"' +
      '        }' +
      '      }' +
      '    },' +
      '    {' +
      '      "id": "1:101755189",' +
      '      "name": "HB Norrköpings Läkar-Och Kuratortjänst",' +
      '      "country": "SE",' +
      '      "postalAddress": {' +
      '        "city": "NORRKÖPING"' +
      '      },' +
      '      "status": {' +
      '        "code": "ST15",' +
      '        "name": "Company deregistered"' +
      '      },' +
      '      "type": {' +
      '        "code": "TY99",' +
      '        "name": "Unknown"' +
      '      },' +
      '      "numberOfWorksites": 0,' +
      '      "_links": {' +
      '        "company": {' +
      '          "href": "https://api.bisnode.com/bbc/v2/companies/1:101755189"' +
      '        }' +
      '      }' +
      '    },' +
      '    {' +
      '      "id": "1:101755193",' +
      '      "name": "HB Lida Byggtjänst",' +
      '      "country": "SE",' +
      '      "postalAddress": {' +
      '        "city": "NORRKÖPING"' +
      '      },' +
      '      "status": {' +
      '        "code": "ST15",' +
      '        "name": "Company deregistered"' +
      '      },' +
      '      "type": {' +
      '        "code": "TY99",' +
      '        "name": "Unknown"' +
      '      },' +
      '      "numberOfWorksites": 0,' +
      '      "_links": {' +
      '        "company": {' +
      '          "href": "https://api.bisnode.com/bbc/v2/companies/1:101755193"' +
      '        }' +
      '      }' +
      '    },' +
      '    {' +
      '      "id": "1:101756058",' +
      '      "name": "Elefef Förvaltning HB",' +
      '      "country": "SE",' +
      '      "postalAddress": {' +
      '        "city": "NORRKÖPING"' +
      '      },' +
      '      "status": {' +
      '        "code": "ST15",' +
      '        "name": "Company deregistered"' +
      '      },' +
      '      "type": {' +
      '        "code": "TY99",' +
      '        "name": "Unknown"' +
      '      },' +
      '      "numberOfWorksites": 0,' +
      '      "_links": {' +
      '        "company": {' +
      '          "href": "https://api.bisnode.com/bbc/v2/companies/1:101756058"' +
      '        }' +
      '      }' +
      '    },' +
      '    {' +
      '      "id": "1:101755139",' +
      '      "name": "Restaurang Peking House HB",' +
      '      "country": "SE",' +
      '      "postalAddress": {' +
      '        "city": "NORRKÖPING"' +
      '      },' +
      '      "status": {' +
      '        "code": "ST15",' +
      '        "name": "Company deregistered"' +
      '      },' +
      '      "type": {' +
      '        "code": "TY99",' +
      '        "name": "Unknown"' +
      '      },' +
      '      "numberOfWorksites": 0,' +
      '      "_links": {' +
      '        "company": {' +
      '          "href": "https://api.bisnode.com/bbc/v2/companies/1:101755139"' +
      '        }' +
      '      }' +
      '    },' +
      '    {' +
      '      "id": "1:101757978",' +
      '      "name": "HB Comet Hyrbil",' +
      '      "country": "SE",' +
      '      "postalAddress": {' +
      '        "city": "NORRKÖPING"' +
      '      },' +
      '      "status": {' +
      '        "code": "ST15",' +
      '        "name": "Company deregistered"' +
      '      },' +
      '      "type": {' +
      '        "code": "TY99",' +
      '        "name": "Unknown"' +
      '      },' +
      '      "numberOfWorksites": 0,' +
      '      "_links": {' +
      '        "company": {' +
      '          "href": "https://api.bisnode.com/bbc/v2/companies/1:101757978"' +
      '        }' +
      '      }' +
      '    },' +
      '    {' +
      '      "id": "1:101757979",' +
      '      "name": "Nordisk Radio- & TVS-Service KB",' +
      '      "country": "SE",' +
      '      "postalAddress": {' +
      '        "city": "NORRKÖPING"' +
      '      },' +
      '      "status": {' +
      '        "code": "ST10",' +
      '        "name": "Discontinued company"' +
      '      },' +
      '      "type": {' +
      '        "code": "TY99",' +
      '        "name": "Unknown"' +
      '      },' +
      '      "numberOfWorksites": 0,' +
      '      "_links": {' +
      '        "company": {' +
      '          "href": "https://api.bisnode.com/bbc/v2/companies/1:101757979"' +
      '        }' +
      '      }' +
      '    },' +
      '    {' +
      '      "id": "1:101758045",' +
      '      "name": "Sankt Anna Rör & Smide HB",' +
      '      "country": "SE",' +
      '      "postalAddress": {' +
      '        "city": "NORRKÖPING"' +
      '      },' +
      '      "status": {' +
      '        "code": "ST15",' +
      '        "name": "Company deregistered"' +
      '      },' +
      '      "type": {' +
      '        "code": "TY99",' +
      '        "name": "Unknown"' +
      '      },' +
      '      "numberOfWorksites": 0,' +
      '      "_links": {' +
      '        "company": {' +
      '          "href": "https://api.bisnode.com/bbc/v2/companies/1:101758045"' +
      '        }' +
      '      }' +
      '    },' +
      '    {' +
      '      "id": "1:101758058",' +
      '      "name": "Screenprint i Norrköping HB",' +
      '      "country": "SE",' +
      '      "postalAddress": {' +
      '        "city": "NORRKÖPING"' +
      '      },' +
      '      "status": {' +
      '        "code": "ST15",' +
      '        "name": "Company deregistered"' +
      '      },' +
      '      "type": {' +
      '        "code": "TY99",' +
      '        "name": "Unknown"' +
      '      },' +
      '      "numberOfWorksites": 0,' +
      '      "_links": {' +
      '        "company": {' +
      '          "href": "https://api.bisnode.com/bbc/v2/companies/1:101758058"' +
      '        }' +
      '      }' +
      '    },' +
      '    {' +
      '      "id": "1:101533478",' +
      '      "name": "Carolina Ählman",' +
      '      "country": "SE",' +
      '      "postalAddress": {' +
      '        "city": "NORRKÖPING"' +
      '      },' +
      '      "status": {' +
      '        "code": "ST15",' +
      '        "name": "Company deregistered"' +
      '      },' +
      '      "type": {' +
      '        "code": "TY99",' +
      '        "name": "Unknown"' +
      '      },' +
      '      "numberOfWorksites": 0,' +
      '      "_links": {' +
      '        "company": {' +
      '          "href": "https://api.bisnode.com/bbc/v2/companies/1:101533478"' +
      '        }' +
      '      }' +
      '    }' +
      '  ],' +
      '  "hitsTotal": 28347,' +
      '  "maxSize": 10,' +
      '  "offset": 0,' +
      '  "hitsReturned": 10,' +
      '  "_links": {' +
      '    "next": {' +
      '      "href": "https://api.bisnode.com/bbc/v2/companies?companyCity=Norrk%C3%B6ping&offset=10"' +
      '    },' +
      '    "self": {' +
      '      "href": "https://api.bisnode.com/bbc/v2/companies?companyCity=Norrk%C3%B6ping"' +
      '    },' +
      '    "last": {' +
      '      "href": "https://api.bisnode.com/bbc/v2/companies?companyCity=Norrk%C3%B6ping&offset=28340"' +
      '    },' +
      '    "first": {' +
      '      "href": "https://api.bisnode.com/bbc/v2/companies?companyCity=Norrk%C3%B6ping"' +
      '    }' +
      '  }' +
      '}';
    return resp;
  }

  public static string downloadCompanyString() {
    String resp =
      '{' +
      '  "$schema": "https://api.bisnode.com/bbc/v2/schemas/company.schema.json",' +
      '  "$lastModified": "2020-06-20T09:07:27.141Z",' +
      '  "name": "Stretch AB",' +
      '  "country": {' +
      '    "code": "SE",' +
      '    "name": "Sweden"' +
      '  },' +
      '  "status": {' +
      '    "code": "ST00",' +
      '    "name": "Active"' +
      '  },' +
      '  "type": {' +
      '    "code": "TY50",' +
      '    "name": "Private company"' +
      '  },' +
      '  "registrationDate": "2002-01-07",' +
      '  "nationalRegistrationNumber": "5566219050",' +
      '  "vatNo": "SE556621905001",' +
      '  "numberOfWorksites": 1,' +
      '  "postalAddress": {' +
      '    "address": "Box 13087",' +
      '    "zipcode": "10302",' +
      '    "city": "STOCKHOLM",' +
      '    "country": {' +
      '      "code": "SE",' +
      '      "name": "Sweden"' +
      '    },' +
      '    "county": {' +
      '      "code": "GR01",' +
      '      "name": "Stockholm"' +
      '    },' +
      '    "municipality": {' +
      '      "code": "GK0180",' +
      '      "name": "Stockholm"' +
      '    },' +
      '    "SE_Aregion": {' +
      '      "code": "GA01",' +
      '      "name": "Stockholm/Södertälje"' +
      '    }' +
      '  },' +
      '  "phones": [' +
      '    {' +
      '      "type": "LeasedLine",' +
      '      "number": "+46 8240080",' +
      '      "blocked": false' +
      '    }' +
      '  ],' +
      '  "internet": {' +
      '    "urls": [' +
      '      "www.stretch.se"' +
      '    ]' +
      '  },' +
      '  "legalForm": {' +
      '    "code": "JF49",' +
      '    "name": "Limited company"' +
      '  },' +
      '  "economy": {' +
      '    "shareCapital": {' +
      '      "code": "AK09",' +
      '      "name": "0 - 25",' +
      '      "nameCurrency": "KEUR",' +
      '      "value": 119000,' +
      '      "currency": "SEK",' +
      '      "accountingPeriodStart": "201801",' +
      '      "accountingPeriodEnd": "201812"' +
      '    },' +
      '    "turnover": {' +
      '      "code": "OM04",' +
      '      "name": "2000 - 5000",' +
      '      "nameCurrency": "KEUR",' +
      '      "value": 21972000,' +
      '      "currency": "SEK",' +
      '      "accountingPeriodStart": "201801",' +
      '      "accountingPeriodEnd": "201812"' +
      '    },' +
      '    "turnoverChange": {' +
      '      "code": "NO20",' +
      '      "name": "-50% - -25%",' +
      '      "rate": -45,' +
      '      "accountingPeriodStart": "201801",' +
      '      "accountingPeriodEnd": "201812"' +
      '    },' +
      '    "solvency": {' +
      '      "code": "NS80",' +
      '      "name": "> 50%",' +
      '      "rate": 69,' +
      '      "accountingPeriodStart": "201801",' +
      '      "accountingPeriodEnd": "201812"' +
      '    }' +
      '  },' +
      '  "group": {' +
      '    "groupParent": {' +
      '      "id": "1:101153181",' +
      '      "nationalRegistrationNumber": "5566298013",' +
      '      "name": "Maelum & Partner AB",' +
      '      "country": {' +
      '        "code": "SE",' +
      '        "name": "Sweden"' +
      '      }' +
      '    },' +
      '    "parent": {' +
      '      "id": "1:102754530",' +
      '      "nationalRegistrationNumber": "5568562184",' +
      '      "name": "Maelum Holding AB",' +
      '      "country": {' +
      '        "code": "SE",' +
      '        "name": "Sweden"' +
      '      }' +
      '    },' +
      '    "subsidiaries": [' +
      '      {' +
      '        "id": "1:102924065",' +
      '        "nationalRegistrationNumber": "5569174849",' +
      '        "name": "Stretch Addera AB",' +
      '        "country": {' +
      '          "code": "SE",' +
      '          "name": "Sweden"' +
      '        }' +
      '      },' +
      '      {' +
      '        "id": "1:102787884",' +
      '        "nationalRegistrationNumber": "5568679053",' +
      '        "name": "Stretch Public AB",' +
      '        "country": {' +
      '          "code": "SE",' +
      '          "name": "Sweden"' +
      '        }' +
      '      },' +
      '      {' +
      '        "id": "1:103528953",' +
      '        "nationalRegistrationNumber": "5591525398",' +
      '        "name": "Stretch Procurement AB",' +
      '        "country": {' +
      '          "code": "SE",' +
      '          "name": "Sweden"' +
      '        }' +
      '      },' +
      '      {' +
      '        "id": "1:103528952",' +
      '        "nationalRegistrationNumber": "5591525380",' +
      '        "name": "Stretch Evolve AB",' +
      '        "country": {' +
      '          "code": "SE",' +
      '          "name": "Sweden"' +
      '        }' +
      '      },' +
      '      {' +
      '        "id": "1:101876390",' +
      '        "nationalRegistrationNumber": "5567288039",' +
      '        "name": "Stretch Stockholm AB",' +
      '        "country": {' +
      '          "code": "SE",' +
      '          "name": "Sweden"' +
      '        }' +
      '      },' +
      '      {' +
      '        "nationalRegistrationNumber": "3330840491",' +
      '        "name": "Stretch Norge AS",' +
      '        "country": {' +
      '          "code": "NO",' +
      '          "name": "Norway"' +
      '        }' +
      '      },' +
      '      {' +
      '        "id": "1:101129630",' +
      '        "nationalRegistrationNumber": "5566297973",' +
      '        "name": "Stretch Öresund AB",' +
      '        "country": {' +
      '          "code": "SE",' +
      '          "name": "Sweden"' +
      '        }' +
      '      },' +
      '      {' +
      '        "id": "1:103528950",' +
      '        "nationalRegistrationNumber": "5591525364",' +
      '        "name": "Stretch Customer AB",' +
      '        "country": {' +
      '          "code": "SE",' +
      '          "name": "Sweden"' +
      '        }' +
      '      },' +
      '      {' +
      '        "id": "1:103528955",' +
      '        "nationalRegistrationNumber": "5591525414",' +
      '        "name": "Stretch Care AB",' +
      '        "country": {' +
      '          "code": "SE",' +
      '          "name": "Sweden"' +
      '        }' +
      '      },' +
      '      {' +
      '        "nationalRegistrationNumber": "3330866926",' +
      '        "name": "Stretch Denmark ApS",' +
      '        "country": {' +
      '          "code": "DK",' +
      '          "name": "Denmark"' +
      '        }' +
      '      },' +
      '      {' +
      '        "id": "1:102261789",' +
      '        "nationalRegistrationNumber": "5568357049",' +
      '        "name": "Stretch Select AB",' +
      '        "country": {' +
      '          "code": "SE",' +
      '          "name": "Sweden"' +
      '        }' +
      '      },' +
      '      {' +
      '        "id": "1:101930035",' +
      '        "nationalRegistrationNumber": "5567432090",' +
      '        "name": "Stretch Göteborg AB",' +
      '        "country": {' +
      '          "code": "SE",' +
      '          "name": "Sweden"' +
      '        }' +
      '      }' +
      '    ]' +
      '  },' +
      '  "business": {' +
      '    "activities": {' +
      '      "mainActivity": {' +
      '        "code": "HG7022",' +
      '        "description": "Business and other management consultancy activities"' +
      '      },' +
      '      "subActivities": [' +
      '        {' +
      '          "code": "NC6201",' +
      '          "description": "Computer programming activities"' +
      '        },' +
      '        {' +
      '          "code": "NC6202",' +
      '          "description": "Computer consultancy activities"' +
      '        },' +
      '        {' +
      '          "code": "NC6209",' +
      '          "description": "Other information technology and computer service activities"' +
      '        }' +
      '      ],' +
      '      "local": {' +
      '        "mainActivity": {' +
      '          "code": "HG70220",' +
      '          "description": "Business and other management consultancy activities"' +
      '        },' +
      '        "subActivities": [' +
      '          {' +
      '            "code": "SN62010",' +
      '            "description": "Computer programming activities"' +
      '          },' +
      '          {' +
      '            "code": "SN62020",' +
      '            "description": "Computer consultancy activities"' +
      '          },' +
      '          {' +
      '            "code": "SN62090",' +
      '            "description": "Other information technology and computer service activities"' +
      '          },' +
      '          {' +
      '            "code": "OV1129",' +
      '            "description": "Top Level companies 2009"' +
      '          }' +
      '        ]' +
      '      }' +
      '    },' +
      '    "numberOfEmployees": {' +
      '      "code": "AA03",' +
      '      "name": "5 - 9"' +
      '    },' +
      '    "numberOfOfficeEmployees": {' +
      '      "code": "KA99",' +
      '      "name": "Unknown"' +
      '    }' +
      '  },' +
      '  "addressSource": "PARAD, 169 93 Solna, Sweden",' +
      '  "id": "1:101081322",' +
      '  "_links": {' +
      '    "self": {' +
      '      "href": "https://api.bisnode.com/bbc/v2/companies/1:101081322"' +
      '    },' +
      '    "parent": {' +
      '      "href": "https://api.bisnode.com/bbc/v2/companies/1:102754530"' +
      '    },' +
      '    "groupParent": {' +
      '      "href": "https://api.bisnode.com/bbc/v2/companies/1:101153181"' +
      '    },' +
      '    "worksites": [' +
      '      {' +
      '        "href": "https://api.bisnode.com/bbc/v2/worksites/1:202025298",' +
      '        "status": {' +
      '          "code": "ST00",' +
      '          "name": "Active"' +
      '        },' +
      '        "type": {' +
      '          "code": "TY10",' +
      '          "name": "Head Office"' +
      '        }' +
      '      }' +
      '    ],' +
      '    "subsidiaries": [' +
      '      {' +
      '        "href": "https://api.bisnode.com/bbc/v2/companies/1:102924065"' +
      '      },' +
      '      {' +
      '        "href": "https://api.bisnode.com/bbc/v2/companies/1:102787884"' +
      '      },' +
      '      {' +
      '        "href": "https://api.bisnode.com/bbc/v2/companies/1:103528953"' +
      '      },' +
      '      {' +
      '        "href": "https://api.bisnode.com/bbc/v2/companies/1:103528952"' +
      '      },' +
      '      {' +
      '        "href": "https://api.bisnode.com/bbc/v2/companies/1:101876390"' +
      '      },' +
      '      {' +
      '        "href": "https://api.bisnode.com/bbc/v2/companies/1:101129630"' +
      '      },' +
      '      {' +
      '        "href": "https://api.bisnode.com/bbc/v2/companies/1:103528950"' +
      '      },' +
      '      {' +
      '        "href": "https://api.bisnode.com/bbc/v2/companies/1:103528955"' +
      '      },' +
      '      {' +
      '        "href": "https://api.bisnode.com/bbc/v2/companies/1:102261789"' +
      '      },' +
      '      {' +
      '        "href": "https://api.bisnode.com/bbc/v2/companies/1:101930035"' +
      '      }' +
      '    ]' +
      '  },' +
      '  "numberOfEmployeesValue": 7' +
      '}';
    return resp;
  }

  public static string subscribeCompanyString() {
    String resp =
      '{' +
      '  "$schema": "string",' +
      '  "changes": [' +
      '    {' +
      '      "addedAndRemovedWorksites": [' +
      '        {' +
      '          "at": "2015-02-13T12:05:16.565Z",' +
      '          "id": "110:404396642",' +
      '          "type": "removal"' +
      '        }' +
      '      ],' +
      //'      "changeType": "updated",' +
      '      "changeType": "removed",' +
      '      "changedFields": [' +
      '        {' +
      '          "jsonPath": "$.positions.mainPosition",' +
      '          "lastModifiedAt": "2015-03-23T11:02:32.527Z"' +
      '        }' +
      '      ],' +
      '      "companyId": "110:103793982"' +
      '    }' +
      '  ]' +
      '}';
    return resp;
  }

  public static string searchWorksiteString() {
    String resp =
      '{' +
      '  "worksites": [' +
      '    {' +
      '      "id": "1:201221352",' +
      '      "name": "Migrationsverket",' +
      '      "country": "SE",' +
      '      "visitingAddress": {' +
      '        "address": "Lars Janssonsgatan 10",' +
      '        "city": "KIRUNA"' +
      '      },' +
      '      "postalAddress": {' +
      '        "city": "KIRUNA"' +
      '      },' +
      '      "status": {' +
      '        "code": "ST00",' +
      '        "name": "Active"' +
      '      },' +
      '      "type": {' +
      '        "code": "TY20",' +
      '        "name": "Branch office"' +
      '      },' +
      '      "numberOfContacts": 0,' +
      '      "company": {' +
      '        "id": "1:100006601",' +
      '        "legalName": "Migrationsverket"' +
      '      },' +
      '      "_links": {' +
      '        "worksite": {' +
      '          "href": "https://api.bisnode.com/bbc/v2/worksites/1:201221352"' +
      '        },' +
      '        "company": {' +
      '          "href": "https://api.bisnode.com/bbc/v2/companies/1:100006601"' +
      '        }' +
      '      }' +
      '    },' +
      '    {' +
      '      "id": "1:201257025",' +
      '      "name": "Migrationsverket",' +
      '      "country": "SE",' +
      '      "visitingAddress": {' +
      '        "address": "Dalavägen 55 A",' +
      '        "city": "FAGERSTA"' +
      '      },' +
      '      "postalAddress": {' +
      '        "city": "FAGERSTA"' +
      '      },' +
      '      "status": {' +
      '        "code": "ST13",' +
      '        "name": "Discontinued unit"' +
      '      },' +
      '      "type": {' +
      '        "code": "TY20",' +
      '        "name": "Branch office"' +
      '      },' +
      '      "numberOfContacts": 0,' +
      '      "company": {' +
      '        "id": "1:100006601",' +
      '        "legalName": "Migrationsverket"' +
      '      },' +
      '      "_links": {' +
      '        "worksite": {' +
      '          "href": "https://api.bisnode.com/bbc/v2/worksites/1:201257025"' +
      '        },' +
      '        "company": {' +
      '          "href": "https://api.bisnode.com/bbc/v2/companies/1:100006601"' +
      '        }' +
      '      }' +
      '    },' +
      '    {' +
      '      "id": "1:201416831",' +
      '      "name": "Migrationsverket Mottagningsenheten & IT enheten",' +
      '      "country": "SE",' +
      '      "visitingAddress": {' +
      '        "address": "Slottsgatan 81-82",' +
      '        "city": "NORRKÖPING"' +
      '      },' +
      '      "postalAddress": {' +
      '        "city": "NORRKÖPING"' +
      '      },' +
      '      "status": {' +
      '        "code": "ST00",' +
      '        "name": "Active"' +
      '      },' +
      '      "type": {' +
      '        "code": "TY20",' +
      '        "name": "Branch office"' +
      '      },' +
      '      "numberOfContacts": 1,' +
      '      "company": {' +
      '        "id": "1:100006601",' +
      '        "legalName": "Migrationsverket"' +
      '      },' +
      '      "_links": {' +
      '        "worksite": {' +
      '          "href": "https://api.bisnode.com/bbc/v2/worksites/1:201416831"' +
      '        },' +
      '        "company": {' +
      '          "href": "https://api.bisnode.com/bbc/v2/companies/1:100006601"' +
      '        }' +
      '      }' +
      '    },' +
      '    {' +
      '      "id": "1:202570401",' +
      '      "name": "Migrationsverket",' +
      '      "country": "SE",' +
      '      "visitingAddress": {' +
      '        "address": "Östra Madenvägen 6",' +
      '        "city": "SUNDBYBERG"' +
      '      },' +
      '      "postalAddress": {' +
      '        "city": "SOLNA"' +
      '      },' +
      '      "status": {' +
      '        "code": "ST13",' +
      '        "name": "Discontinued unit"' +
      '      },' +
      '      "type": {' +
      '        "code": "TY20",' +
      '        "name": "Branch office"' +
      '      },' +
      '      "numberOfContacts": 0,' +
      '      "company": {' +
      '        "id": "1:100006601",' +
      '        "legalName": "Migrationsverket"' +
      '      },' +
      '      "_links": {' +
      '        "worksite": {' +
      '          "href": "https://api.bisnode.com/bbc/v2/worksites/1:202570401"' +
      '        },' +
      '        "company": {' +
      '          "href": "https://api.bisnode.com/bbc/v2/companies/1:100006601"' +
      '        }' +
      '      }' +
      '    },' +
      '    {' +
      '      "id": "1:200153637",' +
      '      "name": "Migrationsverket Enheten Laxå",' +
      '      "country": "SE",' +
      '      "visitingAddress": {' +
      '        "address": "Saltängsvägen 4",' +
      '        "city": "LAXÅ"' +
      '      },' +
      '      "postalAddress": {' +
      '        "city": "LAXÅ"' +
      '      },' +
      '      "status": {' +
      '        "code": "ST13",' +
      '        "name": "Discontinued unit"' +
      '      },' +
      '      "type": {' +
      '        "code": "TY20",' +
      '        "name": "Branch office"' +
      '      },' +
      '      "numberOfContacts": 1,' +
      '      "company": {' +
      '        "id": "1:100006601",' +
      '        "legalName": "Migrationsverket"' +
      '      },' +
      '      "_links": {' +
      '        "worksite": {' +
      '          "href": "https://api.bisnode.com/bbc/v2/worksites/1:200153637"' +
      '        },' +
      '        "company": {' +
      '          "href": "https://api.bisnode.com/bbc/v2/companies/1:100006601"' +
      '        }' +
      '      }' +
      '    },' +
      '    {' +
      '      "id": "1:202827677",' +
      '      "name": "Migrationsverket",' +
      '      "country": "SE",' +
      '      "visitingAddress": {' +
      '        "address": "Järnvägsgatan 14",' +
      '        "city": "SUNDBYBERG"' +
      '      },' +
      '      "postalAddress": {' +
      '        "city": "SOLNA"' +
      '      },' +
      '      "status": {' +
      '        "code": "ST00",' +
      '        "name": "Active"' +
      '      },' +
      '      "type": {' +
      '        "code": "TY20",' +
      '        "name": "Branch office"' +
      '      },' +
      '      "numberOfContacts": 0,' +
      '      "company": {' +
      '        "id": "1:100006601",' +
      '        "legalName": "Migrationsverket"' +
      '      },' +
      '      "_links": {' +
      '        "worksite": {' +
      '          "href": "https://api.bisnode.com/bbc/v2/worksites/1:202827677"' +
      '        },' +
      '        "company": {' +
      '          "href": "https://api.bisnode.com/bbc/v2/companies/1:100006601"' +
      '        }' +
      '      }' +
      '    },' +
      '    {' +
      '      "id": "1:202648874",' +
      '      "name": "Migrationsverket",' +
      '      "country": "SE",' +
      '      "visitingAddress": {' +
      '        "address": "Kyrkogatan 22 A",' +
      '        "city": "MORA"' +
      '      },' +
      '      "postalAddress": {' +
      '        "city": "MORA"' +
      '      },' +
      '      "status": {' +
      '        "code": "ST13",' +
      '        "name": "Discontinued unit"' +
      '      },' +
      '      "type": {' +
      '        "code": "TY20",' +
      '        "name": "Branch office"' +
      '      },' +
      '      "numberOfContacts": 0,' +
      '      "company": {' +
      '        "id": "1:100006601",' +
      '        "legalName": "Migrationsverket"' +
      '      },' +
      '      "_links": {' +
      '        "worksite": {' +
      '          "href": "https://api.bisnode.com/bbc/v2/worksites/1:202648874"' +
      '        },' +
      '        "company": {' +
      '          "href": "https://api.bisnode.com/bbc/v2/companies/1:100006601"' +
      '        }' +
      '      }' +
      '    },' +
      '    {' +
      '      "id": "1:200940734",' +
      '      "name": "Migrationsverket",' +
      '      "country": "SE",' +
      '      "visitingAddress": {' +
      '        "address": "Stormgatan 9-11",' +
      '        "city": "MALMÖ"' +
      '      },' +
      '      "postalAddress": {' +
      '        "city": "MALMÖ"' +
      '      },' +
      '      "status": {' +
      '        "code": "ST13",' +
      '        "name": "Discontinued unit"' +
      '      },' +
      '      "type": {' +
      '        "code": "TY20",' +
      '        "name": "Branch office"' +
      '      },' +
      '      "numberOfContacts": 0,' +
      '      "company": {' +
      '        "id": "1:100006601",' +
      '        "legalName": "Migrationsverket"' +
      '      },' +
      '      "_links": {' +
      '        "worksite": {' +
      '          "href": "https://api.bisnode.com/bbc/v2/worksites/1:200940734"' +
      '        },' +
      '        "company": {' +
      '          "href": "https://api.bisnode.com/bbc/v2/companies/1:100006601"' +
      '        }' +
      '      }' +
      '    },' +
      '    {' +
      '      "id": "1:202872041",' +
      '      "name": "Migrationsverket",' +
      '      "country": "SE",' +
      '      "visitingAddress": {' +
      '        "address": "Förrådsvägen 3",' +
      '        "city": "LJUNGBYHED"' +
      '      },' +
      '      "postalAddress": {' +
      '        "city": "LJUNGBYHED"' +
      '      },' +
      '      "status": {' +
      '        "code": "ST00",' +
      '        "name": "Active"' +
      '      },' +
      '      "type": {' +
      '        "code": "TY20",' +
      '        "name": "Branch office"' +
      '      },' +
      '      "numberOfContacts": 0,' +
      '      "company": {' +
      '        "id": "1:100006601",' +
      '        "legalName": "Migrationsverket"' +
      '      },' +
      '      "_links": {' +
      '        "worksite": {' +
      '          "href": "https://api.bisnode.com/bbc/v2/worksites/1:202872041"' +
      '        },' +
      '        "company": {' +
      '          "href": "https://api.bisnode.com/bbc/v2/companies/1:100006601"' +
      '        }' +
      '      }' +
      '    },' +
      '    {' +
      '      "id": "1:201255229",' +
      '      "name": "Migrationsverket",' +
      '      "country": "SE",' +
      '      "visitingAddress": {' +
      '        "address": "Bjursdalsvägen 15 C",' +
      '        "city": "BOXHOLM"' +
      '      },' +
      '      "postalAddress": {' +
      '        "city": "BOXHOLM"' +
      '      },' +
      '      "status": {' +
      '        "code": "ST13",' +
      '        "name": "Discontinued unit"' +
      '      },' +
      '      "type": {' +
      '        "code": "TY20",' +
      '        "name": "Branch office"' +
      '      },' +
      '      "numberOfContacts": 0,' +
      '      "company": {' +
      '        "id": "1:100006601",' +
      '        "legalName": "Migrationsverket"' +
      '      },' +
      '      "_links": {' +
      '        "worksite": {' +
      '          "href": "https://api.bisnode.com/bbc/v2/worksites/1:201255229"' +
      '        },' +
      '        "company": {' +
      '          "href": "https://api.bisnode.com/bbc/v2/companies/1:100006601"' +
      '        }' +
      '      }' +
      '    }' +
      '  ],' +
      '  "hitsTotal": 161,' +
      '  "maxSize": 10,' +
      '  "offset": 0,' +
      '  "hitsReturned": 10,' +
      '  "_links": {' +
      '    "next": {' +
      '      "href": "https://api.bisnode.com/bbc/v2/worksites?companyNumber=202100-2163&offset=10"' +
      '    },' +
      '    "self": {' +
      '      "href": "https://api.bisnode.com/bbc/v2/worksites?companyNumber=202100-2163"' +
      '    },' +
      '    "last": {' +
      '      "href": "https://api.bisnode.com/bbc/v2/worksites?companyNumber=202100-2163&offset=160"' +
      '    },' +
      '    "first": {' +
      '      "href": "https://api.bisnode.com/bbc/v2/worksites?companyNumber=202100-2163"' +
      '    }' +
      '  }' +
      '}';
    return resp;
  }

  public static string downloadWorksiteString() {
    String resp =
      '{' +
      '  "$schema": "https://api.bisnode.com/bbc/v2/schemas/worksite.schema.json",' +
      '  "$lastModified": "2019-09-17T09:22:25.339Z",' +
      '  "name": "Stretch AB",' +
      '  "country": {' +
      '    "code": "SE",' +
      '    "name": "Sweden"' +
      '  },' +
      '  "status": {' +
      '    "code": "ST00",' +
      '    "name": "Active"' +
      '  },' +
      '  "type": {' +
      '    "code": "TY20",' +
      '    "name": "Branch office"' +
      '  },' +
      '  "officialWorksiteNumber": "42338723",' +
      '  "postalAddress": {' +
      '    "zipcode": "60170",' +
      '    "city": "NORRKÖPING",' +
      '    "country": {' +
      '      "code": "SE",' +
      '      "name": "Sweden"' +
      '    },' +
      '    "county": {' +
      '      "code": "GR05",' +
      '      "name": "Östergötland"' +
      '    },' +
      '    "municipality": {' +
      '      "code": "GK0581",' +
      '      "name": "Norrköping"' +
      '    },' +
      '    "SE_Aregion": {' +
      '      "code": "GA10",' +
      '      "name": "Norrköping"' +
      '    }' +
      '  },' +
      '  "visitAddress": {' +
      '    "address": "Slottsgatan 81-82",' +
      '    "zipcode": "60222",' +
      '    "city": "NORRKÖPING",' +
      '    "country": {' +
      '      "code": "SE",' +
      '      "name": "Sweden"' +
      '    },' +
      '    "county": {' +
      '      "code": "GR05",' +
      '      "name": "Östergötland"' +
      '    },' +
      '    "municipality": {' +
      '      "code": "GK0581",' +
      '      "name": "Norrköping"' +
      '    },' +
      '    "SE_Aregion": {' +
      '      "code": "GA10",' +
      '      "name": "Norrköping"' +
      '    }' +
      '  },' +
      '  "company": {' +
      '    "nationalRegistrationNumber": "2021002163",' +
      '    "id": "1:100006601"' +
      '  },' +
      '  "phones": [' +
      '    {' +
      '      "type": "LeasedLine",' +
      '      "number": "+46 771235235",' +
      '      "blocked": false' +
      '    }' +
      '  ],' +
      '  "internet": {' +
      '    "urls": [' +
      '      "www.migrationsverket.se"' +
      '    ]' +
      '  },' +
      '  "business": {' +
      '    "activities": {' +
      '      "mainActivity": {' +
      '        "code": "HG8411",' +
      '        "description": "General public administration activities"' +
      '      },' +
      '      "subActivities": [' +
      ' {' +
      '            "code": "SN84112",' +
      '            "description": "Inspection, control, licensing activ"' +
      '          }' +
      '],' +
      '      "local": {' +
      '        "mainActivity": {' +
      '          "code": "HG84115",' +
      '          "description": "Supporting service activities for the government as a whole"' +
      '        },' +
      '        "subActivities": [' +
      '          {' +
      '            "code": "SN84112",' +
      '            "description": "Inspection, control, licensing activ"' +
      '          }' +
      '        ]' +
      '      }' +
      '    },' +
      '    "mainCommunicationLanguage": {' +
      '      "code": "SV",' +
      '      "name": "Swedish"' +
      '    },' +
      '    "numberOfEmployees": {' +
      '      "code": "AA09",' +
      '      "name": "500 - 999"' +
      '    },' +
      '    "numberOfOfficeEmployees": {' +
      '      "code": "KA99",' +
      '      "name": "Unknown"' +
      '    },' +
      '    "trade": {' +
      '      "importing": false,' +
      '      "exporting": false' +
      '    }' +
      '  },' +
      '  "addressSource": "PARAD, 169 93 Solna, Sweden",' +
      '  "id": "1:201416831",' +
      '  "_links": {' +
      '    "self": {' +
      '      "href": "https://api.bisnode.com/bbc/v2/worksites/1:201416831"' +
      '    },' +
      '    "company": {' +
      '      "href": "https://api.bisnode.com/bbc/v2/companies/1:100006601"' +
      '    },' +
      '    "employments": [' +
      '      {' +
      '        "href": "https://api.bisnode.com/bbc/v2/employments/1:402458683",' +
      '        "status": {' +
      '          "code": "ST00",' +
      '          "name": "Active"' +
      '        },' +
      '        "mainPosition": {' +
      '          "code": "BE2540001",' +
      '          "description": "Other Decision Maker"' +
      '        }' +
      '      }' +
      '    ]' +
      '  }' +
      '}';
    return resp;
  }

  public static string subscribeWorksiteString() {
    String resp =
      '{' +
      '  "$schema": "string",' +
      '  "changes": [' +
      '    {' +
      '      "addedAndRemovedEmployments": [' +
      '        {' +
      '          "at": "2015-02-13T12:05:16.565Z",' +
      '          "id": "110:404396642",' +
      '          "type": "removal"' +
      '        }' +
      '      ],' +
      '      "changeType": "updated",' +
      '      "changedFields": [' +
      '        {' +
      '          "jsonPath": "$.positions.mainPosition",' +
      '          "lastModifiedAt": "2015-03-23T11:02:32.527Z"' +
      '        }' +
      '      ],' +
      '      "worksiteId": "1"' +
      '    }' +
      '  ]' +
      '}';
    return resp;
  }

  public static string subscribeRemovedWorksiteString() {
    String resp =
      '{' +
      '  "$schema": "string",' +
      '  "changes": [' +
      '    {' +
      '      "addedAndRemovedEmployments": [' +
      '        {' +
      '          "at": "2015-02-13T12:05:16.565Z",' +
      '          "id": "110:404396642",' +
      '          "type": "removal"' +
      '        }' +
      '      ],' +
      '      "changeType": "removed",' +
      '      "changedFields": [' +
      '        {' +
      '          "jsonPath": "$.positions.mainPosition",' +
      '          "lastModifiedAt": "2015-03-23T11:02:32.527Z"' +
      '        }' +
      '      ],' +
      '      "worksiteId": "2"' +
      '    }' +
      '  ]' +
      '}';
    return resp;
  }

  public static string personDataString() {
    String resp =
      '{' +
      '  "person": {' +
      '    "gedi": "123456",' +
      '    "legalId": {' +
      '      "socialSecurityNumber": "198101145211"' +
      '    },' +
      '    " legalId": {' +
      '      "dataController": {' +
      '        "role": "Data provider",' +
      '        "name": "string",' +
      '        "subProvider": {}' +
      '      },' +
      '      "dataProcessor": {' +
      '        "role": "Data provider",' +
      '        "name": "string",' +
      '        "subProvider": {}' +
      '      },' +
      '      "dataProvider": {' +
      '        "role": "Data provider",' +
      '        "name": "string",' +
      '        "subProvider": {}' +
      '      },' +
      '      "expiresAt": "2017-12-29T09:00:08.000+0000"' +
      '    },' +
      '    "protectedIdentity": false,' +
      '    " protectedIdentity": {' +
      '      "dataController": {' +
      '        "role": "Data provider",' +
      '        "name": "string",' +
      '        "subProvider": {}' +
      '      },' +
      '      "dataProcessor": {' +
      '        "role": "Data provider",' +
      '        "name": "string",' +
      '        "subProvider": {}' +
      '      },' +
      '      "dataProvider": {' +
      '        "role": "Data provider",' +
      '        "name": "string",' +
      '        "subProvider": {}' +
      '      },' +
      '      "expiresAt": "2017-12-29T09:00:08.000+0000"' +
      '    },' +
      '    "firstNames": [' +
      '      "string"' +
      '    ],' +
      '    " firstNames": {' +
      '      "dataController": {' +
      '        "role": "Data provider",' +
      '        "name": "string",' +
      '        "subProvider": {}' +
      '      },' +
      '      "dataProcessor": {' +
      '        "role": "Data provider",' +
      '        "name": "string",' +
      '        "subProvider": {}' +
      '      },' +
      '      "dataProvider": {' +
      '        "role": "Data provider",' +
      '        "name": "string",' +
      '        "subProvider": {}' +
      '      },' +
      '      "expiresAt": "2017-12-29T09:00:08.000+0000"' +
      '    },' +
      '    "preferredFirstName": "string",' +
      '    " preferredFirstName": {' +
      '      "dataController": {' +
      '        "role": "Data provider",' +
      '        "name": "string",' +
      '        "subProvider": {}' +
      '      },' +
      '      "dataProcessor": {' +
      '        "role": "Data provider",' +
      '        "name": "string",' +
      '        "subProvider": {}' +
      '      },' +
      '      "dataProvider": {' +
      '        "role": "Data provider",' +
      '        "name": "string",' +
      '        "subProvider": {}' +
      '      },' +
      '      "expiresAt": "2017-12-29T09:00:08.000+0000"' +
      '    },' +
      '    "additionalName": "string",' +
      '    " additionalName": {' +
      '      "dataController": {' +
      '        "role": "Data provider",' +
      '        "name": "string",' +
      '        "subProvider": {}' +
      '      },' +
      '      "dataProcessor": {' +
      '        "role": "Data provider",' +
      '        "name": "string",' +
      '        "subProvider": {}' +
      '      },' +
      '      "dataProvider": {' +
      '        "role": "Data provider",' +
      '        "name": "string",' +
      '        "subProvider": {}' +
      '      },' +
      '      "expiresAt": "2017-12-29T09:00:08.000+0000"' +
      '    },' +
      '    "familyName": "string",' +
      '    " familyName": {' +
      '      "dataController": {' +
      '        "role": "Data provider",' +
      '        "name": "string",' +
      '        "subProvider": {}' +
      '      },' +
      '      "dataProcessor": {' +
      '        "role": "Data provider",' +
      '        "name": "string",' +
      '        "subProvider": {}' +
      '      },' +
      '      "dataProvider": {' +
      '        "role": "Data provider",' +
      '        "name": "string",' +
      '        "subProvider": {}' +
      '      },' +
      '      "expiresAt": "2017-12-29T09:00:08.000+0000"' +
      '    },' +
      '    "honorificPrefix": "string",' +
      '    " honorificPrefix": {' +
      '      "dataController": {' +
      '        "role": "Data provider",' +
      '        "name": "string",' +
      '        "subProvider": {}' +
      '      },' +
      '      "dataProcessor": {' +
      '        "role": "Data provider",' +
      '        "name": "string",' +
      '        "subProvider": {}' +
      '      },' +
      '      "dataProvider": {' +
      '        "role": "Data provider",' +
      '        "name": "string",' +
      '        "subProvider": {}' +
      '      },' +
      '      "expiresAt": "2017-12-29T09:00:08.000+0000"' +
      '    },' +
      '    "honorificSuffix": "string",' +
      '    " honorificSuffix": {' +
      '      "dataController": {' +
      '        "role": "Data provider",' +
      '        "name": "string",' +
      '        "subProvider": {}' +
      '      },' +
      '      "dataProcessor": {' +
      '        "role": "Data provider",' +
      '        "name": "string",' +
      '        "subProvider": {}' +
      '      },' +
      '      "dataProvider": {' +
      '        "role": "Data provider",' +
      '        "name": "string",' +
      '        "subProvider": {}' +
      '      },' +
      '      "expiresAt": "2017-12-29T09:00:08.000+0000"' +
      '    },' +
      '    "fullName": "string",' +
      '    " fullName": {' +
      '      "dataController": {' +
      '        "role": "Data provider",' +
      '        "name": "string",' +
      '        "subProvider": {}' +
      '      },' +
      '      "dataProcessor": {' +
      '        "role": "Data provider",' +
      '        "name": "string",' +
      '        "subProvider": {}' +
      '      },' +
      '      "dataProvider": {' +
      '        "role": "Data provider",' +
      '        "name": "string",' +
      '        "subProvider": {}' +
      '      },' +
      '      "expiresAt": "2017-12-29T09:00:08.000+0000"' +
      '    },' +
      '    "gender": "Male",' +
      '    " gender": {' +
      '      "dataController": {' +
      '        "role": "Data provider",' +
      '        "name": "string",' +
      '        "subProvider": {}' +
      '      },' +
      '      "dataProcessor": {' +
      '        "role": "Data provider",' +
      '        "name": "string",' +
      '        "subProvider": {}' +
      '      },' +
      '      "dataProvider": {' +
      '        "role": "Data provider",' +
      '        "name": "string",' +
      '        "subProvider": {}' +
      '      },' +
      '      "expiresAt": "2017-12-29T09:00:08.000+0000"' +
      '    },' +
      '    "dateOfBirth": "2011-12-29T09:00:08.000+0000",' +
      '    " dateOfBirth": {' +
      '      "dataController": {' +
      '        "role": "Data provider",' +
      '        "name": "string",' +
      '        "subProvider": {}' +
      '      },' +
      '      "dataProcessor": {' +
      '        "role": "Data provider",' +
      '        "name": "string",' +
      '        "subProvider": {}' +
      '      },' +
      '      "dataProvider": {' +
      '        "role": "Data provider",' +
      '        "name": "string",' +
      '        "subProvider": {}' +
      '      },' +
      '      "expiresAt": "2017-12-29T09:00:08.000+0000"' +
      '    },' +
      '    "yearOfBirth": 2011,' +
      '    " yearOfBirth": {' +
      '      "dataController": {' +
      '        "role": "Data provider",' +
      '        "name": "string",' +
      '        "subProvider": {}' +
      '      },' +
      '      "dataProcessor": {' +
      '        "role": "Data provider",' +
      '        "name": "string",' +
      '        "subProvider": {}' +
      '      },' +
      '      "dataProvider": {' +
      '        "role": "Data provider",' +
      '        "name": "string",' +
      '        "subProvider": {}' +
      '      },' +
      '      "expiresAt": "2017-12-29T09:00:08.000+0000"' +
      '    },' +
      '    "deceased": false,' +
      '    " deceased": {' +
      '      "dataController": {' +
      '        "role": "Data provider",' +
      '        "name": "string",' +
      '        "subProvider": {}' +
      '      },' +
      '      "dataProcessor": {' +
      '        "role": "Data provider",' +
      '        "name": "string",' +
      '        "subProvider": {}' +
      '      },' +
      '      "dataProvider": {' +
      '        "role": "Data provider",' +
      '        "name": "string",' +
      '        "subProvider": {}' +
      '      },' +
      '      "expiresAt": "2017-12-29T09:00:08.000+0000"' +
      '    },' +
      '    "dateOfDeath": "2020-11-09",' +
      '    " dateOfDeath": {' +
      '      "dataController": {' +
      '        "role": "Data provider",' +
      '        "name": "string",' +
      '        "subProvider": {}' +
      '      },' +
      '      "dataProcessor": {' +
      '        "role": "Data provider",' +
      '        "name": "string",' +
      '        "subProvider": {}' +
      '      },' +
      '      "dataProvider": {' +
      '        "role": "Data provider",' +
      '        "name": "string",' +
      '        "subProvider": {}' +
      '      },' +
      '      "expiresAt": "2017-12-29T09:00:08.000+0000"' +
      '    },' +
      '    "communicationLanguageScript": "string",' +
      '    " communicationLanguageScript": {' +
      '      "dataController": {' +
      '        "role": "Data provider",' +
      '        "name": "string",' +
      '        "subProvider": {}' +
      '      },' +
      '      "dataProcessor": {' +
      '        "role": "Data provider",' +
      '        "name": "string",' +
      '        "subProvider": {}' +
      '      },' +
      '      "dataProvider": {' +
      '        "role": "Data provider",' +
      '        "name": "string",' +
      '        "subProvider": {}' +
      '      },' +
      '      "expiresAt": "2017-12-29T09:00:08.000+0000"' +
      '    },' +
      '    "directMarketingRestriction": true,' +
      '    " directMarketingRestriction": {' +
      '      "dataController": {' +
      '        "role": "Data provider",' +
      '        "name": "string",' +
      '        "subProvider": {}' +
      '      },' +
      '      "dataProcessor": {' +
      '        "role": "Data provider",' +
      '        "name": "string",' +
      '        "subProvider": {}' +
      '      },' +
      '      "dataProvider": {' +
      '        "role": "Data provider",' +
      '        "name": "string",' +
      '        "subProvider": {}' +
      '      },' +
      '      "expiresAt": "2017-12-29T09:00:08.000+0000"' +
      '    },' +
      '    "charityMarketingRestriction": true,' +
      '    " charityMarketingRestriction": {' +
      '      "dataController": {' +
      '        "role": "Data provider",' +
      '        "name": "string",' +
      '        "subProvider": {}' +
      '      },' +
      '      "dataProcessor": {' +
      '        "role": "Data provider",' +
      '        "name": "string",' +
      '        "subProvider": {}' +
      '      },' +
      '      "dataProvider": {' +
      '        "role": "Data provider",' +
      '        "name": "string",' +
      '        "subProvider": {}' +
      '      },' +
      '      "expiresAt": "2017-12-29T09:00:08.000+0000"' +
      '    },' +
      '    "onlineMarketingRestriction": true,' +
      '    " onlineMarketingRestriction": {' +
      '      "dataController": {' +
      '        "role": "Data provider",' +
      '        "name": "string",' +
      '        "subProvider": {}' +
      '      },' +
      '      "dataProcessor": {' +
      '        "role": "Data provider",' +
      '        "name": "string",' +
      '        "subProvider": {}' +
      '      },' +
      '      "dataProvider": {' +
      '        "role": "Data provider",' +
      '        "name": "string",' +
      '        "subProvider": {}' +
      '      },' +
      '      "expiresAt": "2017-12-29T09:00:08.000+0000"' +
      '    },' +
      '    "merged": true,' +
      '    " merged": {' +
      '      "dataController": {' +
      '        "role": "Data provider",' +
      '        "name": "string",' +
      '        "subProvider": {}' +
      '      },' +
      '      "dataProcessor": {' +
      '        "role": "Data provider",' +
      '        "name": "string",' +
      '        "subProvider": {}' +
      '      },' +
      '      "dataProvider": {' +
      '        "role": "Data provider",' +
      '        "name": "string",' +
      '        "subProvider": {}' +
      '      },' +
      '      "expiresAt": "2017-12-29T09:00:08.000+0000"' +
      '    },' +
      '    "seeOther": [' +
      '      {' +
      '        "gedi": "string"' +
      '      }' +
      '    ],' +
      '    " seeOther": {' +
      '      "dataController": {' +
      '        "role": "Data provider",' +
      '        "name": "string",' +
      '        "subProvider": {}' +
      '      },' +
      '      "dataProcessor": {' +
      '        "role": "Data provider",' +
      '        "name": "string",' +
      '        "subProvider": {}' +
      '      },' +
      '      "dataProvider": {' +
      '        "role": "Data provider",' +
      '        "name": "string",' +
      '        "subProvider": {}' +
      '      },' +
      '      "expiresAt": "2017-12-29T09:00:08.000+0000"' +
      '    },' +
      '    "phoneList": [' +
      '      {' +
      '        "type": "Mobile",' +
      '        "number": "string",' +
      '        "telemarketingRestriction": true,' +
      '        "secretPhoneNumber": true' +
      '      }' +
      '    ],' +
      '    " phoneList": {' +
      '      "dataController": {' +
      '        "role": "Data provider",' +
      '        "name": "string",' +
      '        "subProvider": {}' +
      '      },' +
      '      "dataProcessor": {' +
      '        "role": "Data provider",' +
      '        "name": "string",' +
      '        "subProvider": {}' +
      '      },' +
      '      "dataProvider": {' +
      '        "role": "Data provider",' +
      '        "name": "string",' +
      '        "subProvider": {}' +
      '      },' +
      '      "expiresAt": "2017-12-29T09:00:08.000+0000"' +
      '    },' +
      '    "addressList": [' +
      '      {' +
      '        "type": "Postal",' +
      '        "subType": "Domicile",' +
      '        "careOf": "string",' +
      '        "streetName": "string",' +
      '        "streetNumber": "string",' +
      '        "entrance": "string",' +
      '        "apartment": "string",' +
      '        "floor": "string",' +
      '        "postOfficeBox": "string",' +
      '        "postalCode": "string",' +
      '        "city": "string",' +
      '        "areaId": "string",' +
      '        "county": "string",' +
      '        "countyCode": "ss",' +
      '        "districtCode": "string",' +
      '        "locality": "string",' +
      '        "municipality": "string",' +
      '        "municipalityCode": "string",' +
      '        "province": "string",' +
      '        "region": "string",' +
      '        "xcoordinate": "string",' +
      '        "ycoordinate": "string",' +
      '        "country": "string",' +
      '        "formattedAddress": [' +
      '          "string"' +
      '        ]' +
      '      }' +
      '    ],' +
      '    " addressList": {' +
      '      "dataController": {' +
      '        "role": "Data provider",' +
      '        "name": "string",' +
      '        "subProvider": {}' +
      '      },' +
      '      "dataProcessor": {' +
      '        "role": "Data provider",' +
      '        "name": "string",' +
      '        "subProvider": {}' +
      '      },' +
      '      "dataProvider": {' +
      '        "role": "Data provider",' +
      '        "name": "string",' +
      '        "subProvider": {}' +
      '      },' +
      '      "expiresAt": "2017-12-29T09:00:08.000+0000"' +
      '    },' +
      '    "enrichment": {' +
      '      "paymentDisruptionScore": "Unproblematic",' +
      '      "purchasingPower": "High",' +
      '      "phaseOfLife": "Pre-Established",' +
      '      "housingType": "Single Dwelling Building",' +
      '      "education": "Academic",' +
      '      "housingOwnership": "Owned",' +
      '      "vacationHomeOwnership": "string"' +
      '    },' +
      '    " enrichment": {' +
      '      "dataController": {' +
      '        "role": "Data provider",' +
      '        "name": "string",' +
      '        "subProvider": {}' +
      '      },' +
      '      "dataProcessor": {' +
      '        "role": "Data provider",' +
      '        "name": "string",' +
      '        "subProvider": {}' +
      '      },' +
      '      "dataProvider": {' +
      '        "role": "Data provider",' +
      '        "name": "string",' +
      '        "subProvider": {}' +
      '      },' +
      '      "expiresAt": "2017-12-29T09:00:08.000+0000"' +
      '    },' +
      '    "deregistered": false' +
      '  },' +
      '  "lastModified": "2017-12-29T09:00:08.000+0000",' +
      '  "sourceList": [' +
      '    "string"' +
      '  ]' +
      '}';
    return resp;
  }

  public static string BCIMonitoringResponseString() {
    String json =
      '{' +
      '  "changedEntities": [' +
      '    {' +
      '      "person": {' +
      '        "gedi": "A2VT6BE7WP2J",' +
      '        "legalId": {' +
      '          "socialSecurityNumber": "198701270491"' +
      '        },' +
      '        "protectedIdentity": false,' +
      '        "firstNames": [' +
      '          "Hans",' +
      '          "Michael"' +
      '        ],' +
      '        "preferredFirstName": "Michael",' +
      '        "familyName": "Liljenström",' +
      '        "gender": "Male",' +
      '        "dateOfBirth": "1987-01-27",' +
      '        "yearOfBirth": 1987,' +
      '        "communicationLanguageScript": "sv-Latn-SE",' +
      '        "directMarketingRestriction": false,' +
      '        "phoneList": [],' +
      '        "addressList": [' +
      '          {' +
      '            "type": "Visiting",' +
      '            "subType": "Domicile",' +
      '            "streetName": "Banérgatan",' +
      '            "streetNumber": "31",' +
      '            "entrance": "A",' +
      '            "apartment": "1003",' +
      '            "postalCode": "11522",' +
      '            "city": "Stockholm",' +
      '            "country": "SE",' +
      '            "fullAddressString": "Banérgatan 31A lgh 1003",' +
      '            "formattedAddress": [' +
      '              "Banérgatan 31 A lgh 1003",' +
      '              "11522 Stockholm"' +
      '            ]' +
      '          }' +
      '        ],' +
      '        "relationshipList": [],' +
      '        "deregistered": false' +
      '      },' +
      '      "lastModified": "2020-05-15T11:10:55.923+0000",' +
      '      "clientData": {},' +
      '      "tags": [],' +
      '      "sourceList": []' +
      '    },' +
      '    {' +
      '      "person": {' +
      '        "gedi": "A2XZ4G46VM9U",' +
      '        "legalId": {' +
      '          "socialSecurityNumber": "196208268513"' +
      '        },' +
      '        "protectedIdentity": false,' +
      '        "firstNames": [' +
      '          "Björn",' +
      '          "Anders"' +
      '        ],' +
      '        "preferredFirstName": "Björn",' +
      '        "familyName": "Persson",' +
      '        "gender": "Male",' +
      '        "dateOfBirth": "1962-08-26",' +
      '        "yearOfBirth": 1962,' +
      '        "communicationLanguageScript": "sv-Latn-SE",' +
      '        "directMarketingRestriction": false,' +
      '        "phoneList": [],' +
      '        "addressList": [' +
      '          {' +
      '            "type": "Visiting",' +
      '            "subType": "Domicile",' +
      '            "streetName": "Umevägen",' +
      '            "streetNumber": "131",' +
      '            "postalCode": "91136",' +
      '            "city": "Vännäsby",' +
      '            "country": "SE",' +
      '            "fullAddressString": "Umevägen 131",' +
      '            "formattedAddress": [' +
      '              "Umevägen 131",' +
      '              "91136 Vännäsby"' +
      '            ]' +
      '          }' +
      '        ],' +
      '        "relationshipList": [],' +
      '        "deregistered": false' +
      '      },' +
      '      "lastModified": "2020-05-12T04:24:03.079+0000",' +
      '      "clientData": {},' +
      '      "tags": [],' +
      '      "sourceList": []' +
      '    },' +
      '    {' +
      '      "person": {' +
      '        "gedi": "A2MW8V87JD5U",' +
      '        "legalId": {' +
      '          "socialSecurityNumber": "197912042905"' +
      '        },' +
      '        "protectedIdentity": false,' +
      '        "firstNames": [' +
      '          "Sophie",' +
      '          "Elisabeth",' +
      '          "Matilda"' +
      '        ],' +
      '        "preferredFirstName": "Sophie",' +
      '        "familyName": "Agevik",' +
      '        "gender": "Female",' +
      '        "dateOfBirth": "1979-12-04",' +
      '        "yearOfBirth": 1979,' +
      '        "communicationLanguageScript": "sv-Latn-SE",' +
      '        "directMarketingRestriction": false,' +
      '        "phoneList": [],' +
      '        "addressList": [' +
      '          {' +
      '            "type": "Visiting",' +
      '            "subType": "Domicile",' +
      '            "streetName": "Pukslagargatan",' +
      '            "streetNumber": "43",' +
      '            "postalCode": "12530",' +
      '            "city": "Älvsjö",' +
      '            "country": "SE",' +
      '            "fullAddressString": "Pukslagargatan 43",' +
      '            "formattedAddress": [' +
      '              "Pukslagargatan 43",' +
      '              "12530 Älvsjö"' +
      '            ]' +
      '          }' +
      '        ],' +
      '        "relationshipList": [],' +
      '        "deregistered": false' +
      '      },' +
      '      "lastModified": "2020-05-15T08:53:15.578+0000",' +
      '      "clientData": {},' +
      '      "tags": [],' +
      '      "sourceList": []' +
      '    },' +
      '    {' +
      '      "person": {' +
      '        "gedi": "A2MG2CT72E4S",' +
      '        "legalId": {' +
      '          "socialSecurityNumber": "199011070845"' +
      '        },' +
      '        "protectedIdentity": false,' +
      '        "firstNames": [' +
      '          "Moa",' +
      '          "Joanna"' +
      '        ],' +
      '        "preferredFirstName": "Moa",' +
      '        "familyName": "Gezelius",' +
      '        "gender": "Female",' +
      '        "dateOfBirth": "1990-11-07",' +
      '        "yearOfBirth": 1990,' +
      '        "communicationLanguageScript": "sv-Latn-SE",' +
      '        "directMarketingRestriction": false,' +
      '        "phoneList": [],' +
      '        "addressList": [' +
      '          {' +
      '            "type": "Visiting",' +
      '            "subType": "Domicile",' +
      '            "streetName": "Banérgatan",' +
      '            "streetNumber": "31",' +
      '            "entrance": "A",' +
      '            "apartment": "1003",' +
      '            "postalCode": "11522",' +
      '            "city": "Stockholm",' +
      '            "country": "SE",' +
      '            "fullAddressString": "Banérgatan 31A lgh 1003",' +
      '            "formattedAddress": [' +
      '              "Banérgatan 31 A lgh 1003",' +
      '              "11522 Stockholm"' +
      '            ]' +
      '          }' +
      '        ],' +
      '        "relationshipList": [],' +
      '        "deregistered": false' +
      '      },' +
      '      "lastModified": "2020-05-15T12:29:02.282+0000",' +
      '      "clientData": {},' +
      '      "tags": [],' +
      '      "sourceList": []' +
      '    },' +
      '    {' +
      '      "person": {' +
      '        "gedi": "A27K5YM5CU5L",' +
      '        "legalId": {' +
      '          "socialSecurityNumber": "198303220746"' +
      '        },' +
      '        "protectedIdentity": false,' +
      '        "firstNames": [' +
      '          "Elahe"' +
      '        ],' +
      '        "familyName": "Abdolian",' +
      '        "gender": "Female",' +
      '        "dateOfBirth": "1983-03-22",' +
      '        "yearOfBirth": 1983,' +
      '        "communicationLanguageScript": "sv-Latn-SE",' +
      '        "directMarketingRestriction": false,' +
      '        "phoneList": [],' +
      '        "addressList": [' +
      '          {' +
      '            "type": "Visiting",' +
      '            "subType": "Domicile",' +
      '            "streetName": "Trädgårdsvägen",' +
      '            "streetNumber": "139",' +
      '            "postalCode": "19146",' +
      '            "city": "Sollentuna",' +
      '            "country": "SE",' +
      '            "fullAddressString": "Trädgårdsvägen 139",' +
      '            "formattedAddress": [' +
      '              "Trädgårdsvägen 139",' +
      '              "19146 Sollentuna"' +
      '            ]' +
      '          }' +
      '        ],' +
      '        "relationshipList": [],' +
      '        "deregistered": false' +
      '      },' +
      '      "lastModified": "2020-05-15T09:57:58.159+0000",' +
      '      "clientData": {},' +
      '      "tags": [],' +
      '      "sourceList": []' +
      '    },' +
      '    {' +
      '      "person": {' +
      '        "gedi": "A2MW8V87JD5U",' +
      '        "legalId": {' +
      '          "socialSecurityNumber": "197912042905"' +
      '        },' +
      '        "protectedIdentity": false,' +
      '        "firstNames": [' +
      '          "Sophie",' +
      '          "Elisabeth",' +
      '          "Matilda"' +
      '        ],' +
      '        "preferredFirstName": "Sophie",' +
      '        "familyName": "Agevik",' +
      '        "gender": "Female",' +
      '        "dateOfBirth": "1979-12-04",' +
      '        "yearOfBirth": 1979,' +
      '        "communicationLanguageScript": "sv-Latn-SE",' +
      '        "directMarketingRestriction": false,' +
      '        "phoneList": [],' +
      '        "addressList": [' +
      '          {' +
      '            "type": "Visiting",' +
      '            "subType": "Domicile",' +
      '            "streetName": "Pukslagargatan",' +
      '            "streetNumber": "43",' +
      '            "postalCode": "12530",' +
      '            "city": "Älvsjö",' +
      '            "country": "SE",' +
      '            "fullAddressString": "Pukslagargatan 43",' +
      '            "formattedAddress": [' +
      '              "Pukslagargatan 43",' +
      '              "12530 Älvsjö"' +
      '            ]' +
      '          }' +
      '        ],' +
      '        "relationshipList": [],' +
      '        "deregistered": false' +
      '      },' +
      '      "lastModified": "2020-05-15T08:53:15.578+0000",' +
      '      "clientData": {},' +
      '      "tags": [],' +
      '      "sourceList": []' +
      '    },' +
      '    {' +
      '      "person": {' +
      '        "gedi": "A2MG2CT72E4S",' +
      '        "legalId": {' +
      '          "socialSecurityNumber": "199011070845"' +
      '        },' +
      '        "protectedIdentity": false,' +
      '        "firstNames": [' +
      '          "Moa",' +
      '          "Joanna"' +
      '        ],' +
      '        "preferredFirstName": "Moa",' +
      '        "familyName": "Gezelius",' +
      '        "gender": "Female",' +
      '        "dateOfBirth": "1990-11-07",' +
      '        "yearOfBirth": 1990,' +
      '        "communicationLanguageScript": "sv-Latn-SE",' +
      '        "directMarketingRestriction": false,' +
      '        "phoneList": [],' +
      '        "addressList": [' +
      '          {' +
      '            "type": "Visiting",' +
      '            "subType": "Domicile",' +
      '            "streetName": "Banérgatan",' +
      '            "streetNumber": "31",' +
      '            "entrance": "A",' +
      '            "apartment": "1003",' +
      '            "postalCode": "11522",' +
      '            "city": "Stockholm",' +
      '            "country": "SE",' +
      '            "fullAddressString": "Banérgatan 31A lgh 1003",' +
      '            "formattedAddress": [' +
      '              "Banérgatan 31 A lgh 1003",' +
      '              "11522 Stockholm"' +
      '            ]' +
      '          }' +
      '        ],' +
      '        "relationshipList": [],' +
      '        "deregistered": false' +
      '      },' +
      '      "lastModified": "2020-05-15T12:29:02.282+0000",' +
      '      "clientData": {},' +
      '      "tags": [],' +
      '      "sourceList": []' +
      '    },' +
      '    {' +
      '      "person": {' +
      '        "gedi": "A27K5YM5CU5X",' +
      '        "legalId": {' +
      '          "socialSecurityNumber": "196303220748"' +
      '        },' +
      '        "protectedIdentity": true,' +
      '        "firstNames": [' +
      '          "Kalle"' +
      '        ],' +
      '        "familyName": "Anka",' +
      '        "gender": "Male",' +
      '        "dateOfBirth": "1963-03-22",' +
      '        "yearOfBirth": 1963,' +
      '        "communicationLanguageScript": "sv-Latn-SE",' +
      '        "directMarketingRestriction": false,' +
      '        "phoneList": [],' +
      '        "addressList": [' +
      '          {' +
      '            "type": "Visiting",' +
      '            "subType": "Domicile",' +
      '            "streetName": "Trädgårdsvägen",' +
      '            "streetNumber": "139",' +
      '            "postalCode": "19146",' +
      '            "city": "Sollentuna",' +
      '            "country": "SE",' +
      '            "fullAddressString": "Trädgårdsvägen 139",' +
      '            "formattedAddress": [' +
      '              "Trädgårdsvägen 139",' +
      '              "19146 Sollentuna"' +
      '            ]' +
      '          }' +
      '        ],' +
      '        "relationshipList": [],' +
      '        "deregistered": false' +
      '      },' +
      '      "lastModified": "2020-05-15T09:57:58.159+0000",' +
      '      "clientData": {},' +
      '      "tags": [],' +
      '      "sourceList": []' +
      '    }' +
      '  ],' +
      '  "errorEntities": [],' +
      '  "hasMoreEntities": true,' +
      '  "cursor": {' +
      '    "next": "5fbe20d9a57bb0e4f1282848"' +
      '  },' +
      '  "numberOfEntities": 8' +
      '}';
    return json;
  }
}