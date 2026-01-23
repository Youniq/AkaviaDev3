@isTest
private class CompanySearchResponseTest {
  @isTest
  static void testParseResponse() {
    CompanySearchResponse resp = CompanySearchResponse.parse(
      MockHttpResponseGenerator.searchCompanyString()
    );
    Integer hits = resp.hitsReturned;
    Integer hitTotal = resp.hitsTotal;
    CompanySearchResponse.clsLinks links = resp.links;
    CompanySearchResponse.cls_next nextLink = links.next;
    String nexthr = nextLink.href;
    CompanySearchResponse.cls_self selfLink = links.self;
    String selfhr = selfLink.href;
    CompanySearchResponse.cls_last lastLink = links.last;
    String lasthr = lastLink.href;
    CompanySearchResponse.cls_first firstLink = links.first;
    String firsthr = firstLink.href;
    Integer maxSize = resp.maxSize;
    Integer offset = resp.offset;
    CompanySearchResponse.cls_companies[] companies = resp.companies;
    String wid = companies[0].id;
    String wc = companies[0].country;
    CompanySearchResponse.clsLinks linkList = companies[0].links;
    String wName = companies[0].name;
    Integer nr = companies[0].numberOfWorksites;
    CompanySearchResponse.cls_postalAddress postAdress = companies[0]
      .postalAddress;
    String city = postAdress.city;
    CompanySearchResponse.cls_status st = companies[0].status;
    String sCode = st.code;
    String stName = st.name;
    CompanySearchResponse.cls_type wtype = companies[0].type;
    String wCode = wtype.code;
    String wtName = wtype.name;
  }
}