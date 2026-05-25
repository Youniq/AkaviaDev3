@RestResource(urlMapping='/accounts/bulk')
global with sharing class VoteraAccountService {
    private static final Set<String> ALLOWED = new Set<String>{
        'Id','Name','LatestMembershipDate__c','MembershipGroup__c','MembershipStatus__c',
        'PersonSection__c','TradeAssociation__c','MembershipCategory__c',
        'CurrentState__c','IsLokaltFortroendevald__c','CurrentEmployer__r.Name'
    };

    @TestVisible static Map<Id, Id> testUserToAccountOverride; // For tests to inject mapping without portal users

    @HttpPost
    global static void doPost() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;

        // Parse request body
        String payload = req.requestBody != null ? req.requestBody.toString() : null;
        if (String.isBlank(payload)) {
            res.statusCode = 400;
            res.responseBody = Blob.valueOf('Missing request body');
            return;
        }
        Map<String,Object> body;
        try {
            body = (Map<String,Object>) JSON.deserializeUntyped(payload);
        } catch (Exception ex) {
            res.statusCode = 400;
            res.responseBody = Blob.valueOf('Invalid JSON');
            return;
        }

    // Accept either Account Ids (start 001) or User Ids (start 005). Partner will send 005 User Ids.
    // For User Ids we will resolve to the related Account via User.Contact.AccountId (assumes community/portal user model).
    List<Object> idsRaw = (List<Object>) body.get('ids');
        if (idsRaw == null || idsRaw.isEmpty()) {
            res.statusCode = 200;
            res.responseBody = Blob.valueOf(JSON.serialize(new Map<String,Object>{'records' => new List<Object>()}));
            return;
        }
        List<String> ids = new List<String>();
        for (Object o : idsRaw) ids.add(String.valueOf(o));

        // Classify ids: we now allow sending only User Ids (005...) or Account Ids (001...), or a mix.
        List<String> userIds = new List<String>();
        List<String> accountIds = new List<String>();
        for (String idVal : ids){
            if (String.isBlank(idVal)) continue;
            if (idVal.startsWith('005')) userIds.add(idVal);
            else if (idVal.startsWith('001')) accountIds.add(idVal);
            else {
                res.statusCode = 400;
                res.responseBody = Blob.valueOf('Unsupported Id prefix for value: '+idVal);
                return;
            }
        }
        Boolean anyUsers = !userIds.isEmpty();
        Boolean anyAccounts = !accountIds.isEmpty();

        List<Object> fieldsIn = (List<Object>) body.get('fields');
        List<String> fields = new List<String>{'Id','Name','MembershipStatus__c'}; // default
        if (fieldsIn != null && !fieldsIn.isEmpty()) {
            fields = new List<String>();
            for (Object f : fieldsIn) {
                String fs = String.valueOf(f);
                if (!ALLOWED.contains(fs)) {
                    res.statusCode = 400;
                    res.responseBody = Blob.valueOf('Invalid field: ' + fs);
                    return;
                }
                fields.add(fs);
            }
        }

        List<Map<String,Object>> userResults = anyUsers ? handleUserIds(userIds, fields) : new List<Map<String,Object>>();
        // Index user results by UserId (may have duplicates in order list, so build list in order later)
        Map<String, List<Map<String,Object>>> userIndex = new Map<String, List<Map<String,Object>>>();
        for (Map<String,Object> ur : userResults){
            String uid = (String) ur.get('UserId');
            if (!userIndex.containsKey(uid)) userIndex.put(uid, new List<Map<String,Object>>());
            userIndex.get(uid).add(ur);
        }
        List<Map<String,Object>> accountResults = anyAccounts ? queryAccountsByIds(accountIds, fields) : new List<Map<String,Object>>();
        Map<String, Map<String,Object>> accountIndex = new Map<String, Map<String,Object>>();
        for (Map<String,Object> ar : accountResults){
            accountIndex.put((String) ar.get('Id'), ar);
        }
        // Build output preserving original order; duplicate accounts for each user if needed.
        List<Map<String,Object>> out = new List<Map<String,Object>>();
        for (String original : ids){
            if (original.startsWith('005')){
                List<Map<String,Object>> entries = userIndex.get(original);
                if (entries == null || entries.isEmpty()){
                    out.add(new Map<String,Object>{'RequestedId' => original, 'UserId' => original, 'error' => 'NO_ACCOUNT', 'SourceIdType' => 'USER'});
                } else {
                    for (Map<String,Object> base : entries){
                        Map<String,Object> clone = new Map<String,Object>();
                        clone.putAll(base);
                        clone.put('RequestedId', original);
                        clone.put('SourceIdType', 'USER');
                        out.add(clone);
                    }
                }
            } else if (original.startsWith('001')) {
                Map<String,Object> acc = accountIndex.get(original);
                if (acc == null){
                    out.add(new Map<String,Object>{'RequestedId' => original, 'error' => 'NOT_FOUND', 'SourceIdType' => 'ACCOUNT'});
                } else {
                    Map<String,Object> clone = new Map<String,Object>();
                    clone.putAll(acc);
                    clone.put('RequestedId', original);
                    clone.put('SourceIdType', 'ACCOUNT');
                    out.add(clone);
                }
            }
        }
        String mode;
        if (anyUsers && anyAccounts) mode = 'MIXED';
        else if (anyUsers) mode = 'USER';
        else mode = 'ACCOUNT';

        res.statusCode = 200;
    res.responseBody = Blob.valueOf(JSON.serialize(new Map<String,Object>{'records' => out, 'mode' => mode}));
    }

    // Query Accounts directly by Ids
    private static List<Map<String,Object>> queryAccountsByIds(List<String> accountIds, List<String> fields){
        List<Map<String,Object>> out = new List<Map<String,Object>>();
        if (accountIds.isEmpty()) return out;
        Integer MAX_IDS = 200;
        Integer i = 0;
        while (i < accountIds.size()) {
            Integer endIdx = Math.min(i + MAX_IDS, accountIds.size());
            List<String> chunk = new List<String>();
            for (Integer k = i; k < endIdx; k++) {
                chunk.add(accountIds[k]);
            }
            for (Integer j=0; j<chunk.size(); j++) chunk[j] = '\'' + String.escapeSingleQuotes(chunk[j]) + '\'';
            String fieldString = String.join(fields, ',');
            String q = 'SELECT ' + fieldString + ' FROM Account WHERE Id IN (' + String.join(chunk, ',') + ')';
            try {
                List<sObject> recs = Database.query(q);
                for (sObject s : recs) {
                    Map<String,Object> m = (Map<String,Object>) JSON.deserializeUntyped(JSON.serialize(s));
                    out.add(m);
                }
            } catch (Exception ex) {
                // bubble up as generic error in top-level method by throwing
                throw ex;
            }
            i = endIdx;
        }
        return out;
    }

    // Resolve User Ids to related Account via User.Contact.AccountId, return account field maps and include UserId in each map.
    private static List<Map<String,Object>> handleUserIds(List<String> userIds, List<String> fields){
        List<Map<String,Object>> result = new List<Map<String,Object>>();
        if (userIds.isEmpty()) return result;
        // Query Users in chunks to respect limits
        Integer MAX_IDS = 200;
        Map<Id, Id> userToAccount = new Map<Id, Id>();
        for (Integer i=0; i<userIds.size(); i+=MAX_IDS){
            Integer endIdx = Math.min(i+MAX_IDS, userIds.size());
            List<Id> sub = new List<Id>();
            for (Integer k=i; k<endIdx; k++) sub.add((Id) userIds[k]);
            for (User u : [SELECT Id, Contact.AccountId FROM User WHERE Id IN :sub]){
                if (u.Contact != null && u.Contact.AccountId != null){
                    userToAccount.put(u.Id, u.Contact.AccountId);
                }
            }
        }

        if (Test.isRunningTest() && testUserToAccountOverride != null) {
            // Allow test to simulate mapping
            userToAccount.putAll(testUserToAccountOverride);
        }

        // Unique account ids preserving input order mapping
        List<String> acctIdOrder = new List<String>();
        Set<Id> seen = new Set<Id>();
        for (String uid : userIds){
            Id aid = userToAccount.get((Id) uid);
            if (aid != null && !seen.contains(aid)){
                seen.add(aid);
                acctIdOrder.add((String)aid);
            }
        }

        // Query accounts
        List<Map<String,Object>> accounts = queryAccountsByIds(acctIdOrder, fields);
        // Index by Id for quick lookup
        Map<String, Map<String,Object>> accById = new Map<String, Map<String,Object>>();
        for (Map<String,Object> m : accounts){
            accById.put((String) m.get('Id'), m);
        }
        // Build result per input user (can duplicate account for different users if needed)
        for (String uid : userIds){
            Id aid = userToAccount.get((Id) uid);
            if (aid != null && accById.containsKey((String)aid)){
                // Shallow clone map
                Map<String,Object> base = new Map<String,Object>();
                base.putAll(accById.get((String)aid));
                base.put('UserId', uid);
                result.add(base);
            } else {
                result.add(new Map<String,Object>{'UserId' => uid, 'error' => 'NO_ACCOUNT'});
            }
        }
        return result;
    }
}