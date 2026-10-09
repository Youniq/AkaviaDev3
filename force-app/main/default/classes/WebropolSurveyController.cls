/**
 * Experience Cloud / LWC: hämta personlig Webropol-länk för inloggad medlem.
 */
public with sharing class WebropolSurveyController {
  @AuraEnabled(cacheable=false)
  public static WebropolSurveyService.LinkResult getPersonalSurveyLink(
    String settingsDeveloperName
  ) {
    return WebropolSurveyService.ensurePersonalLinkForCurrentUser(
      settingsDeveloperName,
      true
    );
  }
}