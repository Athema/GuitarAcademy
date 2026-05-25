global without sharing class GuitarPurchaseController {

    public class PurchaseVideoRequest {
        @InvocableVariable(label='Video Id' description='The Guitar_Video__c record Id to purchase')
        public String videoId;
        @InvocableVariable(label='Contact Id' description='The student Contact Id — pass @variables.ContactId')
        public String contactId;
        @InvocableVariable(label='Routable Id' description='The MessagingSession Id — pass @variables.RoutableId')
        public String routableId;
    }

    public class PurchaseVideoResult {
        @InvocableVariable(label='Result Message')
        public String message;
    }

    @InvocableMethod(label='Purchase Video' description='Purchases the Guitar_Video__c the student is currently watching.')
    public static List<PurchaseVideoResult> purchaseVideoInvocable(List<PurchaseVideoRequest> requests) {
        List<PurchaseVideoResult> results = new List<PurchaseVideoResult>();
        for (PurchaseVideoRequest req : requests) {
            PurchaseVideoResult res = new PurchaseVideoResult();
            try {
                SessionContext context = getSessionContext(req.routableId);
                // Resolve contactId from the passed variable (agent user ≠ student)
                String contactIdStr = String.isNotBlank(req.contactId) ? req.contactId : context.currentContactId;
                Id contactId = String.isNotBlank(contactIdStr) ? (Id)contactIdStr : null;
                if (contactId == null) {
                    res.message = 'Could not identify your account. Please try again.';
                    results.add(res);
                    continue;
                }
                // Resolve videoId — prefer explicit param, fall back to reading session record
                String videoIdStr = req.videoId;
                if (String.isBlank(videoIdStr)) videoIdStr = context.currentVideoId;
                if (String.isBlank(videoIdStr)) {
                    res.message = 'No video detected. Please navigate to a video page and try again.';
                    results.add(res);
                    continue;
                }
                Id videoId = (Id)videoIdStr;
                if ([SELECT COUNT() FROM Video_Purchase__c WHERE Contact__c = :contactId AND Video__c = :videoId] > 0) {
                    Guitar_Video__c already = [SELECT Name FROM Guitar_Video__c WHERE Id = :videoId LIMIT 1];
                    res.message = 'You already own "' + already.Name + '". You can watch it any time.';
                    results.add(res);
                    continue;
                }
                Guitar_Video__c video = [SELECT Name, Price__c FROM Guitar_Video__c WHERE Id = :videoId LIMIT 1];
                insert new Video_Purchase__c(Contact__c = contactId, Video__c = videoId, Amount_Paid__c = video.Price__c);
                publishAccessAction('PURCHASE', String.valueOf(videoId), req.routableId);
                res.message = 'Purchase successful! "' + video.Name + '" is now unlocked. You can play the full lesson now.';
            } catch (Exception e) {
                res.message = 'Something went wrong: ' + e.getMessage().left(100);
            }
            results.add(res);
        }
        return results;
    }

    private class SessionContext {
        String currentPage = '';
        String currentVideoId = '';
        String currentContactId = '';
    }

    private static SessionContext getSessionContext(String routableId) {
        SessionContext context = new SessionContext();
        FilterState__c state = FilterState__c.getOrgDefaults();
        context.currentPage = state.Current_Page__c != null ? state.Current_Page__c : '';
        context.currentVideoId = state.Current_Video_Id__c != null ? state.Current_Video_Id__c : '';
        context.currentContactId = state.Current_Contact_Id__c != null ? state.Current_Contact_Id__c : '';
        return context;
    }

    private static void publishAccessAction(String action, String videoId, String routableId) {
        // Legacy FilterState__c write — kept during migration so the polling UI keeps working.
        FilterState__c state = FilterState__c.getOrgDefaults();
        state.Action__c = action;
        state.Action_Video_Id__c = videoId;
        upsert state;
        // New: stamp the agent's own MessagingSession so the outbound read can move off FilterState__c.
        stampSession(routableId, action, videoId);
    }

    private static void stampSession(String routableId, String action, String videoId) {
        if (String.isBlank(routableId)) return;
        List<MessagingSession> sessions = [SELECT Id FROM MessagingSession WHERE Id = :routableId LIMIT 1];
        if (sessions.isEmpty()) return;
        SObject ms = new MessagingSession(Id = sessions[0].Id);
        ms.put('Action__c', action);
        ms.put('ActionJSON__c', String.isNotBlank(videoId)
            ? JSON.serialize(new Map<String, Object>{ 'videoId' => videoId })
            : null);
        update ms;
    }
}
