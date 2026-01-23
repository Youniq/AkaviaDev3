@isTest
private class WorksiteSearchResponseTest {
  @isTest
  static void testParseResponse() {
    WorksiteSearchResponse resp = WorksiteSearchResponse.parse(
      MockHttpResponseGenerator.searchWorksiteString()
    );
    Integer hits = resp.hitsReturned;
    Integer hitTotal = resp.hitsTotal;
    WorksiteSearchResponse.clsLinks links = resp.links;
    WorksiteSearchResponse.cls_next nextLink = links.next;
    Integer maxSize = resp.maxSize;
    Integer offset = resp.offset;
    WorksiteSearchResponse.cls_worksites[] worksites = resp.worksites;
    String wid = worksites[0].id;
    String wc = worksites[0].country;
    WorksiteSearchResponse.cls_company comp = worksites[0].company;
    String href = comp.href;
    WorksiteSearchResponse.clsLinks linkList = worksites[0].links;
    String wName = worksites[0].name;
    Integer num = worksites[0].numberOfContacts;
    WorksiteSearchResponse.cls_postalAddress postAdress = worksites[0]
      .postalAddress;
    String city = postAdress.city;
    WorksiteSearchResponse.cls_status st = worksites[0].status;
    String sCode = st.code;
    String stName = st.name;
    WorksiteSearchResponse.cls_type wtype = worksites[0].type;
    String wCode = wtype.code;
    String wtName = wtype.name;
    WorksiteSearchResponse.cls_visitingAddress visit = worksites[0]
      .visitingAddress;
    String vaddress = visit.address;
    String vCity = visit.city;
  }
}