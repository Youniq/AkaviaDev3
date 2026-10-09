/**
 * REST for Mina sidor feed read/unread.
 *
 * GET  /services/apexrest/mina-sidor/v1/feeds?accountId=001...
 * GET  /services/apexrest/mina-sidor/v1/feeds?caseId=500...&accountId=001...
 * PATCH /services/apexrest/mina-sidor/v1/feeds
 *   Body: { "accountId": "001...", "feedItemIds": ["0D5..."], "isRead": true }
 */
@RestResource(urlMapping='/mina-sidor/v1/feeds')
global with sharing class CommunityFeedReadRestResource {
  global class PatchBody {
    public String accountId;
    public List<String> feedItemIds;
    public Boolean isRead;
  }

  @HttpGet
  global static void getFeeds() {
    RestRequest req = RestContext.request;
    RestResponse res = RestContext.response;

    String caseId = req.params.get('caseId');
    Id accountId = parseAccountId(req.params.get('accountId'));
    if (accountId == null) {
      writeError(res, 400, 'Ange accountId');
      return;
    }

    Integer rowLimit = parseLimit(req.params.get('limit'));

    try {
      List<CommunityFeedItem> items;
      if (String.isNotBlank(caseId)) {
        items = CommunityFeedReadService.getFeedItemsByCase(
          caseId,
          accountId,
          rowLimit
        );
      } else {
        items = CommunityFeedReadService.getFeedItemsForMember(
          accountId,
          rowLimit
        );
      }
      writeJson(res, 200, items);
    } catch (Exception ex) {
      writeError(res, 500, ex.getMessage());
    }
  }

  @HttpPatch
  global static void patchReadStatus() {
    RestRequest req = RestContext.request;
    RestResponse res = RestContext.response;

    String payload = req.requestBody != null ? req.requestBody.toString() : null;
    if (String.isBlank(payload)) {
      writeError(res, 400, 'Request body saknas');
      return;
    }

    PatchBody body;
    try {
      body = (PatchBody) JSON.deserialize(payload, PatchBody.class);
    } catch (Exception ex) {
      writeError(res, 400, 'Ogiltig JSON');
      return;
    }

    Id accountId = body == null ? null : parseAccountId(body.accountId);
    if (accountId == null) {
      writeError(res, 400, 'Ogiltigt accountId');
      return;
    }
    if (body.feedItemIds == null || body.feedItemIds.isEmpty()) {
      writeError(res, 400, 'Ange feedItemIds');
      return;
    }

    try {
      CommunityFeedReadService.setReadStatus(
        body.feedItemIds,
        accountId,
        body.isRead
      );
      writeJson(
        res,
        200,
        new Map<String, Object>{
          'success' => true,
          'isRead' => body.isRead == null ? true : body.isRead
        }
      );
    } catch (Exception ex) {
      writeError(res, 500, ex.getMessage());
    }
  }

  private static Integer parseLimit(String limitValue) {
    if (String.isBlank(limitValue)) {
      return null;
    }
    try {
      return Integer.valueOf(limitValue.trim());
    } catch (Exception ex) {
      return null;
    }
  }

  private static Id parseAccountId(String accountIdValue) {
    if (String.isBlank(accountIdValue)) {
      return null;
    }
    try {
      return (Id) accountIdValue.trim();
    } catch (Exception ex) {
      return null;
    }
  }

  private static void writeJson(
    RestResponse res,
    Integer statusCode,
    Object payload
  ) {
    res.statusCode = statusCode;
    res.addHeader('Content-Type', 'application/json');
    res.responseBody = Blob.valueOf(JSON.serialize(payload));
  }

  private static void writeError(
    RestResponse res,
    Integer statusCode,
    String message
  ) {
    writeJson(
      res,
      statusCode,
      new Map<String, Object>{ 'success' => false, 'message' => message }
    );
  }
}