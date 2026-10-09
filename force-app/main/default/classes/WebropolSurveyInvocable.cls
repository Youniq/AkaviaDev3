/**
 * Flow: hämta personlig Webropol-länk via MemberID och e-post (eller Account).
 */
public with sharing class WebropolSurveyInvocable {
  public class Request {
    @InvocableVariable(
      label='Settings Developer Name'
      description='DeveloperName för Webropol_Settings__mdt, t.ex. Default'
      required=true
    )
    public String settingsDeveloperName;

    @InvocableVariable(
      label='Account Id'
      description='Personkonto – MemberNumber__c och PersonEmail används om angivet'
    )
    public Id accountId;

    @InvocableVariable(label='Member Id' description='Medlemsnummer (MemberNumber__c)')
    public String memberId;

    @InvocableVariable(label='Email' description='Medlemmens e-post')
    public String email;
  }

  public class Response {
    @InvocableVariable
    public Boolean success;

    @InvocableVariable
    public String personalLink;

    @InvocableVariable
    public String errorMessage;
  }

  @InvocableMethod(
    label='Hämta Webropol personlig länk'
    description='Matchar MemberID mot Webropol getByEmail och returnerar PersonalLinkToSurvey'
  )
  public static List<Response> getPersonalLinks(List<Request> requests) {
    List<Response> results = new List<Response>();
    if (requests == null) {
      return results;
    }

    for (Request req : requests) {
      Response res = new Response();
      res.success = false;
      try {
        WebropolSurveyService.LinkResult linkResult;
        if (req.accountId != null) {
          linkResult = WebropolSurveyService.getPersonalLinkForAccount(
            req.accountId,
            req.settingsDeveloperName
          );
        } else {
          linkResult = WebropolSurveyService.getPersonalLink(
            req.settingsDeveloperName,
            req.memberId,
            req.email
          );
        }
        res.success = linkResult.success;
        res.personalLink = linkResult.personalLink;
        res.errorMessage = linkResult.success ? null : linkResult.message;
      } catch (Exception ex) {
        res.errorMessage = ex.getMessage();
      }
      results.add(res);
    }
    return results;
  }
}