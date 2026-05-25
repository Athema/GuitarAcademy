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

        if (String.isBlank(routableId)) {
            res.message = 'DEBUG: routableId was blank — no session to read.';
            return res;
        }

        List<MessagingSession> sessions = [
            SELECT Id, Current_Page__c, Current_Video_Id__c
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
        res.message = 'DEBUG: session ' + ms.Id + ' → page=[' + res.currentPage + '] video=[' + res.currentVideoId + ']';
        return res;
    }
}
