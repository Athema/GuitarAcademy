global without sharing class GuitarVideoController {

    global class AccessInfo {
        @AuraEnabled public Boolean isSubscribed;
        @AuraEnabled public List<Id> purchasedVideoIds;
        @AuraEnabled public Date subscriptionEndDate;
        AccessInfo(Boolean sub, List<Id> ids, Date endDate) {
            this.isSubscribed = sub;
            this.purchasedVideoIds = ids;
            this.subscriptionEndDate = endDate;
        }
    }

    @AuraEnabled(cacheable=true)
    global static List<Guitar_Video__c> getVideos(String level, String category) {
        String q = 'SELECT Id, Name, YouTube_ID__c, Thumbnail_URL__c, Level__c, Category__c, Price__c, Duration_Minutes__c, Description__c FROM Guitar_Video__c';
        List<String> conditions = new List<String>();
        if (String.isNotBlank(level))    conditions.add('Level__c = \'' + String.escapeSingleQuotes(level) + '\'');
        if (String.isNotBlank(category)) conditions.add('Category__c = \'' + String.escapeSingleQuotes(category) + '\'');
        if (!conditions.isEmpty()) q += ' WHERE ' + String.join(conditions, ' AND ');
        q += ' ORDER BY Level__c, Name LIMIT 200';
        return Database.query(q);
    }

    @AuraEnabled(cacheable=true)
    global static List<Guitar_Video__c> getFeaturedVideos() {
        return [SELECT Id, Name, YouTube_ID__c, Thumbnail_URL__c, Level__c, Category__c, Price__c, Duration_Minutes__c
                FROM Guitar_Video__c
                WHERE Is_Featured__c = true
                ORDER BY Level__c, Name
                LIMIT 3];
    }

    @AuraEnabled(cacheable=false)
    global static Boolean hasVideoAccess(Id videoId) {
        Id contactId = getContactId();
        if (contactId == null) return false;
        if ([SELECT COUNT() FROM Video_Purchase__c WHERE Contact__c = :contactId AND Video__c = :videoId] > 0) return true;
        return [SELECT COUNT() FROM Subscription__c WHERE Contact__c = :contactId AND Status__c = 'Active'] > 0;
    }

    @AuraEnabled(cacheable=false)
    global static AccessInfo getMyAccess() {
        Id contactId = getContactId();
        if (contactId == null) return new AccessInfo(false, new List<Id>(), null);
        List<Subscription__c> subs = [SELECT End_Date__c FROM Subscription__c WHERE Contact__c = :contactId AND Status__c = 'Active' LIMIT 1];
        Boolean isSubscribed = !subs.isEmpty();
        Date endDate = isSubscribed ? subs[0].End_Date__c : null;
        List<Id> purchasedIds = new List<Id>();
        for (Video_Purchase__c vp : [SELECT Video__c FROM Video_Purchase__c WHERE Contact__c = :contactId]) {
            purchasedIds.add(vp.Video__c);
        }
        return new AccessInfo(isSubscribed, purchasedIds, endDate);
    }

    @AuraEnabled(cacheable=false)
    global static String purchaseVideo(Id videoId) {
        Id contactId = getContactId();
        if (contactId == null) throw new AuraHandledException('Not a community user.');
        if ([SELECT COUNT() FROM Video_Purchase__c WHERE Contact__c = :contactId AND Video__c = :videoId] > 0) {
            Guitar_Video__c already = [SELECT Name FROM Guitar_Video__c WHERE Id = :videoId LIMIT 1];
            return 'You already own "' + already.Name + '". You can watch it any time.';
        }
        Guitar_Video__c video = [SELECT Name, Price__c FROM Guitar_Video__c WHERE Id = :videoId LIMIT 1];
        insert new Video_Purchase__c(Contact__c = contactId, Video__c = videoId, Amount_Paid__c = video.Price__c);
        return 'Purchase successful! "' + video.Name + '" is now unlocked. Refresh the page to watch the full lesson.';
    }

    @AuraEnabled(cacheable=false)
    global static String createSubscription(String plan) {
        Id contactId = getContactId();
        if (contactId == null) throw new AuraHandledException('Not a community user.');
        List<Subscription__c> existing = [SELECT Id FROM Subscription__c WHERE Contact__c = :contactId AND Status__c = 'Active'];
        for (Subscription__c s : existing) s.Status__c = 'Cancelled';
        if (!existing.isEmpty()) update existing;
        Date endDate = plan == 'Annual' ? Date.today().addYears(1) : Date.today().addMonths(1);
        insert new Subscription__c(Contact__c = contactId, Plan__c = plan, Status__c = 'Active', End_Date__c = endDate);
        String price = plan == 'Annual' ? '$79.99/yr' : '$9.99/mo';
        return 'Subscribed! Your ' + plan + ' plan (' + price + ') is active until ' + endDate.format() + '. All lessons are now unlocked — refresh the page to start watching.';
    }

    @AuraEnabled(cacheable=false)
    global static String filterCatalog(String level, String category) {
        List<String> parts = new List<String>();
        if (String.isNotBlank(level))    parts.add(level);
        if (String.isNotBlank(category)) parts.add(category);
        String filterDesc = parts.isEmpty() ? 'all lessons' : String.join(parts, ' ') + ' lessons';
        return 'Done! The catalog is now showing ' + filterDesc + '.';
    }

    // Reads the agent action straight from the MessagingSession (by conversationId) and
    // flattens ActionJSON__c into the same keys getFilterSettings returns, so the LWC outbound
    // path can swap source with minimal change. This is the session-based replacement for the
    // FilterState__c polling.
    @AuraEnabled(cacheable=false)
    global static Map<String, String> getAgentAction(String conversationId) {
        Map<String, String> result = new Map<String, String>{
            'action' => '', 'level' => '', 'category' => '', 'actionVideoId' => ''
        };
        if (String.isBlank(conversationId)) return result;
        try {
            List<MessagingSession> sessions = [
                SELECT Id, Action__c, ActionJSON__c
                FROM MessagingSession
                WHERE Conversation.ConversationIdentifier = :conversationId
                ORDER BY CreatedDate DESC
                LIMIT 1
            ];
            if (sessions.isEmpty()) return result;
            MessagingSession ms = sessions[0];
            result.put('action', ms.Action__c != null ? ms.Action__c : '');
            if (String.isNotBlank(ms.ActionJSON__c)) {
                Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(ms.ActionJSON__c);
                if (payload.get('level') != null)    result.put('level', String.valueOf(payload.get('level')));
                if (payload.get('category') != null) result.put('category', String.valueOf(payload.get('category')));
                if (payload.get('videoId') != null)  result.put('actionVideoId', String.valueOf(payload.get('videoId')));
            }
            return result;
        } catch (Exception e) {
            return new Map<String, String>{ 'error' => e.getMessage() };
        }
    }

    public class FilterCatalogRequest {
        @InvocableVariable(label='Level' description='Skill level: Beginner, Intermediate, or Advanced')
        public String level;
        @InvocableVariable(label='Category' description='Category e.g. Blues, Rock, Classical')
        public String category;
        @InvocableVariable(label='Messaging Session Id' description='Pass @variables.RoutableId from the agent context')
        public String inRoutableId;
    }

    public class FilterCatalogResult {
        @InvocableVariable(label='Result Message')
        public String message;
    }

    @InvocableMethod(label='Filter Video Catalog' description='Filters the Guitar Academy video catalog by skill level and/or category. Only call when the student is on the Catalog page.')
    public static List<FilterCatalogResult> filterCatalogInvocable(List<FilterCatalogRequest> requests) {
        List<FilterCatalogResult> results = new List<FilterCatalogResult>();
        for (FilterCatalogRequest req : requests) {
            FilterCatalogResult res = new FilterCatalogResult();
            String currentPage = getSessionPage(req.inRoutableId);
            if (currentPage != 'catalog') {
                res.message = 'Please navigate to the catalog page first, then I can filter the lessons for you.';
                results.add(res);
                continue;
            }
            Map<String, String> payload = new Map<String, String>{
                'level'    => req.level    != null ? req.level    : '',
                'category' => req.category != null ? req.category : ''
            };
            // Write to FilterState__c for polling-based catalog update
            FilterState__c state = FilterState__c.getOrgDefaults();
            state.Level__c    = req.level;
            state.Category__c = req.category;
            upsert state;
            // Also write to MessagingSession for event-driven approach
            if (String.isNotBlank(req.inRoutableId)) {
                List<MessagingSession> sessions = [SELECT Id FROM MessagingSession WHERE Id = :req.inRoutableId LIMIT 1];
                if (!sessions.isEmpty()) {
                    SObject sessionUpdate = new MessagingSession(Id = sessions[0].Id);
                    sessionUpdate.put('Action__c', 'FILTER');
                    sessionUpdate.put('ActionJSON__c', JSON.serialize(payload));
                    update sessionUpdate;
                }
            }
            res.message = filterCatalog(req.level, req.category);
            results.add(res);
        }
        return results;
    }

    @AuraEnabled(cacheable=false)
    public static void resetDemo() {
        delete [SELECT Id FROM Video_Purchase__c];
        delete [SELECT Id FROM Subscription__c];
        FilterState__c state = FilterState__c.getOrgDefaults();
        state.Level__c = null;
        state.Category__c = null;
        state.Action__c = null;
        state.Action_Video_Id__c = null;
        upsert state;
    }

    @AuraEnabled(cacheable=false)
    public static void updateContactPage(String pageName, String sessionKey, String videoId) {
        if (String.isBlank(pageName)) return;
        try {
            savePageState(pageName, videoId);
            if (String.isBlank(sessionKey)) return;
            List<MessagingSession> sessions = [
                SELECT Id FROM MessagingSession
                WHERE Conversation.ConversationIdentifier = :sessionKey
                LIMIT 1
            ];
            if (!sessions.isEmpty()) {
                SObject ms = new MessagingSession(Id = sessions[0].Id);
                ms.put('Current_Page__c', pageName);
                ms.put('Current_Video_Id__c', String.isNotBlank(videoId) ? videoId : null);
                // Stamp the logged-in student's Contact Id so the guest-context agent can identify
                // them for purchase/subscribe without FilterState__c.
                Id stampContactId = getContactId();
                if (stampContactId != null) ms.put('Current_Contact_Id__c', String.valueOf(stampContactId));
                // Navigating to any non-video page clears the agent FILTER action, so the catalog
                // opens clean — cleared in session context, not just hidden in the UI.
                if (pageName != 'video') {
                    ms.put('Action__c', null);
                    ms.put('ActionJSON__c', null);
                }
                update ms;
            } else {
                retryUpdatePage(pageName, sessionKey, videoId);
            }
        } catch (Exception e) {
            System.debug('updateContactPage error: ' + e.getMessage());
        }
    }

    @future
    private static void retryUpdatePage(String pageName, String sessionKey, String videoId) {
        try {
            savePageState(pageName, videoId);
            List<MessagingSession> sessions = [
                SELECT Id FROM MessagingSession
                WHERE Conversation.ConversationIdentifier = :sessionKey
                LIMIT 1
            ];
            if (!sessions.isEmpty()) {
                SObject ms = new MessagingSession(Id = sessions[0].Id);
                ms.put('Current_Page__c', pageName);
                ms.put('Current_Video_Id__c', String.isNotBlank(videoId) ? videoId : null);
                // Stamp the logged-in student's Contact Id so the guest-context agent can identify
                // them for purchase/subscribe without FilterState__c.
                Id stampContactId = getContactId();
                if (stampContactId != null) ms.put('Current_Contact_Id__c', String.valueOf(stampContactId));
                // Navigating to any non-video page clears the agent FILTER action, so the catalog
                // opens clean — cleared in session context, not just hidden in the UI.
                if (pageName != 'video') {
                    ms.put('Action__c', null);
                    ms.put('ActionJSON__c', null);
                }
                update ms;
            }
        } catch (Exception e) {
            System.debug('retryUpdatePage error: ' + e.getMessage());
        }
    }

    @AuraEnabled(cacheable=false)
    public static String getAgentPageContext(String sessionKey) {
        try {
            FilterState__c state = FilterState__c.getOrgDefaults();
            return state.Current_Page__c != null ? state.Current_Page__c : '(blank)';
        } catch (Exception e) {
            return 'error: ' + e.getMessage().left(60);
        }
    }

    @AuraEnabled(cacheable=false)
    global static Map<String, String> getFilterSettings() {
        FilterState__c state = FilterState__c.getOrgDefaults();
        Map<String, String> result = new Map<String, String>();
        result.put('level',    state.Level__c    != null ? state.Level__c    : '');
        result.put('category', state.Category__c != null ? state.Category__c : '');
        result.put('action', state.Action__c != null ? state.Action__c : '');
        result.put('actionVideoId', state.Action_Video_Id__c != null ? state.Action_Video_Id__c : '');
        return result;
    }

    private static Id getContactId() {
        List<User> users = [SELECT ContactId FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];
        return (users.isEmpty() || users[0].ContactId == null) ? null : users[0].ContactId;
    }

    private static String getSessionPage(String routableId) {
        FilterState__c state = FilterState__c.getOrgDefaults();
        return state.Current_Page__c != null ? state.Current_Page__c : '';
    }

    private static void savePageState(String pageName, String videoId) {
        FilterState__c state = FilterState__c.getOrgDefaults();
        state.Current_Page__c = pageName;
        state.Current_Video_Id__c = String.isNotBlank(videoId) ? videoId : null;
        if (pageName == 'catalog') {
            state.Level__c = null;
            state.Category__c = null;
        }
        if (pageName != 'video') {
            state.Action__c = null;
            state.Action_Video_Id__c = null;
        }
        Id contactId = getContactId();
        state.Current_Contact_Id__c = contactId != null ? String.valueOf(contactId) : null;
        upsert state;
    }
}
