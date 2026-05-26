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
                // Backstop: an active subscription already grants access to every lesson.
                // The agent's `available when` gate normally hides this action, but never rely on the gate alone.
                if ([SELECT COUNT() FROM Subscription__c WHERE Contact__c = :contactId AND Status__c = 'Active'] > 0) {
                    res.message = 'Your active subscription already gives you full access to every lesson, including this one — no purchase needed. Just hit play!';
                    results.add(res);
                    continue;
                }
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
        if (String.isBlank(routableId)) return context;
        List<MessagingSession> sessions = [
            SELECT Current_Page__c, Current_Video_Id__c, Current_Contact_Id__c
            FROM MessagingSession
            WHERE Id = :routableId
            LIMIT 1
        ];
        if (sessions.isEmpty()) return context;
        MessagingSession ms = sessions[0];
        context.currentPage = ms.Current_Page__c != null ? ms.Current_Page__c : '';
        context.currentVideoId = ms.Current_Video_Id__c != null ? ms.Current_Video_Id__c : '';
        context.currentContactId = ms.Current_Contact_Id__c != null ? ms.Current_Contact_Id__c : '';
        return context;
    }

    private static void publishAccessAction(String action, String videoId, String routableId) {
        // Stamp the action on the agent's own MessagingSession — the LWC reads it event-driven.
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
