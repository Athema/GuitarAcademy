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
                // Resolve contactId from the passed variable (agent user ≠ student)
                Id contactId = String.isNotBlank(req.contactId) ? (Id)req.contactId : null;
                if (contactId == null) {
                    res.message = 'Could not identify your account. Please try again.';
                    results.add(res);
                    continue;
                }
                // Resolve videoId — prefer explicit param, fall back to reading session record
                String videoIdStr = req.videoId;
                if (String.isBlank(videoIdStr) && String.isNotBlank(req.routableId)) {
                    List<MessagingSession> sessions = [
                        SELECT Current_Video_Id__c FROM MessagingSession
                        WHERE Id = :req.routableId LIMIT 1
                    ];
                    if (!sessions.isEmpty()) videoIdStr = sessions[0].Current_Video_Id__c;
                }
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
                res.message = 'Purchase successful! "' + video.Name + '" is now unlocked. Refresh the page to watch the full lesson.';
            } catch (Exception e) {
                res.message = 'Something went wrong: ' + e.getMessage().left(100);
            }
            results.add(res);
        }
        return results;
    }
}
