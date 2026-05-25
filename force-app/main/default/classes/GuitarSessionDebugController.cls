global without sharing class GuitarSessionDebugController {

    // Master on/off switch for the debug panel — read from the Debug_Config__c custom setting
    // (org default). Toggle in Setup > Custom Settings > Guitar Debug Config > Manage. No deploy needed.
    @AuraEnabled(cacheable=false)
    public static Boolean isDebugEnabled() {
        Debug_Config__c cfg = Debug_Config__c.getOrgDefaults();
        return cfg != null && cfg.Enabled__c == true;
    }

    // Returns a full snapshot of the agent's-eye view of the MessagingSession for a given
    // conversationId. The session resolved here (by ConversationIdentifier) is the SAME record
    // the agent reads by routableId — so these field values are exactly what the agent sees.
    @AuraEnabled(cacheable=false)
    public static Map<String, String> getDebugSnapshot(String conversationId) {
        Map<String, String> r = new Map<String, String>();
        r.put('conversationId', conversationId != null ? conversationId : '');

        if (String.isBlank(conversationId)) {
            r.put('found', 'false');
            r.put('note', 'no conversationId yet');
            return r;
        }

        List<MessagingSession> sessions = [
            SELECT Id, Current_Page__c, Current_Video_Id__c, Current_Contact_Id__c, Action__c, ActionJSON__c,
                   MessagingEndUserId, MessagingEndUser.Name, MessagingEndUser.ContactId
            FROM MessagingSession
            WHERE Conversation.ConversationIdentifier = :conversationId
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];

        if (sessions.isEmpty()) {
            r.put('found', 'false');
            r.put('note', 'session not queryable yet for this conversationId');
            return r;
        }

        MessagingSession ms = sessions[0];
        String page  = ms.Current_Page__c != null ? ms.Current_Page__c : '';
        String video = ms.Current_Video_Id__c != null ? ms.Current_Video_Id__c : '';

        r.put('found', 'true');
        r.put('sessionId', ms.Id);
        r.put('currentPage', page);
        r.put('currentVideoId', video);
        r.put('action', ms.Action__c != null ? ms.Action__c : '');
        r.put('actionJson', ms.ActionJSON__c != null ? ms.ActionJSON__c : '');
        r.put('endUserName', ms.MessagingEndUser != null && ms.MessagingEndUser.Name != null ? ms.MessagingEndUser.Name : '');
        r.put('contactId', ms.MessagingEndUser != null && ms.MessagingEndUser.ContactId != null
                           ? String.valueOf(ms.MessagingEndUser.ContactId) : '');
        r.put('sessionContactId', ms.Current_Contact_Id__c != null ? ms.Current_Contact_Id__c : '');

        // Derived guard state — mirrors the agent's available-when conditions exactly.
        r.put('filterGuard',   page == 'catalog' ? 'OPEN' : 'closed');
        r.put('purchaseGuard', (page == 'video' || video != '') ? 'OPEN' : 'closed');

        return r;
    }
}
