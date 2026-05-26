global without sharing class GuitarPageContextController {

    public class PageContextRequest {
        @InvocableVariable(label='Routable Id' description='The active MessagingSession Id')
        public String routableId;
    }

    public class PageContextResult {
        @InvocableVariable(label='Current Page')
        public String currentPage;
        @InvocableVariable(label='Current Video Id')
        public String currentVideoId;
        @InvocableVariable(label='Current Video Owned')
        public String currentVideoOwned;
        @InvocableVariable(label='Message')
        public String message;
    }

    @InvocableMethod(label='Get Page Context' description='Returns the current Experience Cloud page and video for the active MessagingSession.')
    public static List<PageContextResult> getPageContext(List<PageContextRequest> requests) {
        List<PageContextResult> results = new List<PageContextResult>();
        for (PageContextRequest req : requests) {
            results.add(readContext(req.routableId));
        }
        return results;
    }

    // Live, system-mode read of the agent's own MessagingSession by routableId.
    // Each agent utterance re-invokes this, so the value is always fresh — no stale linked variable.
    private static PageContextResult readContext(String routableId) {
        PageContextResult res = new PageContextResult();
        res.currentPage = '';
        res.currentVideoId = '';
        res.currentVideoOwned = 'false';

        if (String.isBlank(routableId)) {
            res.message = 'DEBUG: routableId was blank — no session to read.';
            return res;
        }

        List<MessagingSession> sessions = [
            SELECT Id, Current_Page__c, Current_Video_Id__c, Current_Contact_Id__c
            FROM MessagingSession
            WHERE Id = :routableId
            LIMIT 1
        ];

        if (sessions.isEmpty()) {
            res.message = 'DEBUG: no MessagingSession found for routableId ' + routableId + '.';
            return res;
        }

        MessagingSession ms = sessions[0];
        res.currentPage = ms.Current_Page__c != null ? ms.Current_Page__c : '';
        res.currentVideoId = ms.Current_Video_Id__c != null ? ms.Current_Video_Id__c : '';

        // Compute whether the student already has access to currentVideoId:
        // an active subscription unlocks everything, otherwise check for a direct purchase.
        // Mirrors the UI's "owned" badge so the agent can hide purchase_video up front.
        String contactIdStr = ms.Current_Contact_Id__c;
        if (String.isNotBlank(contactIdStr)) {
            Id contactId = (Id) contactIdStr;
            Boolean owned = false;
            if ([SELECT COUNT() FROM Subscription__c WHERE Contact__c = :contactId AND Status__c = 'Active'] > 0) {
                owned = true;
            } else if (String.isNotBlank(res.currentVideoId)) {
                Id videoId = (Id) res.currentVideoId;
                owned = [SELECT COUNT() FROM Video_Purchase__c WHERE Contact__c = :contactId AND Video__c = :videoId] > 0;
            }
            res.currentVideoOwned = owned ? 'true' : 'false';
        }

        res.message = 'DEBUG: session ' + ms.Id + ' → page=[' + res.currentPage + '] video=[' + res.currentVideoId + '] owned=[' + res.currentVideoOwned + ']';
        return res;
    }
}
