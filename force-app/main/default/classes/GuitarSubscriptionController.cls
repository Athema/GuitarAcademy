global without sharing class GuitarSubscriptionController {

    public class SubscriptionRequest {
        @InvocableVariable(label='Plan' description='Subscription plan: Monthly or Annual')
        public String plan;
        @InvocableVariable(label='Contact Id' description='The student Contact Id')
        public String contactId;
        @InvocableVariable(label='Routable Id' description='The active MessagingSession Id')
        public String routableId;
    }

    public class SubscriptionResult {
        @InvocableVariable(label='Result Message')
        public String message;
    }

    @InvocableMethod(label='Create Subscription' description='Creates a Monthly or Annual subscription for the student from a lesson video page.')
    public static List<SubscriptionResult> createSubscription(List<SubscriptionRequest> requests) {
        List<SubscriptionResult> results = new List<SubscriptionResult>();
        for (SubscriptionRequest req : requests) {
            SubscriptionResult res = new SubscriptionResult();
            try {
                if (getSessionPage(req.routableId) != 'video') {
                    res.message = 'Please navigate to a lesson video page first, then I can set up full lesson access for you.';
                    results.add(res);
                    continue;
                }

                Id contactId = String.isNotBlank(req.contactId) ? (Id)req.contactId : null;
                if (contactId == null) {
                    res.message = 'Could not identify your account. Please try again.';
                    results.add(res);
                    continue;
                }

                String plan = normalizePlan(req.plan);
                if (String.isBlank(plan)) {
                    res.message = 'Please choose either Monthly or Annual.';
                    results.add(res);
                    continue;
                }

                List<Subscription__c> existing = [
                    SELECT Id, Status__c
                    FROM Subscription__c
                    WHERE Contact__c = :contactId AND Status__c = 'Active'
                ];
                for (Subscription__c subscription : existing) {
                    subscription.Status__c = 'Cancelled';
                }
                if (!existing.isEmpty()) update existing;

                Date endDate = plan == 'Annual' ? Date.today().addYears(1) : Date.today().addMonths(1);
                insert new Subscription__c(
                    Contact__c = contactId,
                    Plan__c = plan,
                    Status__c = 'Active',
                    End_Date__c = endDate
                );

                String price = plan == 'Annual' ? '$79.99/yr' : '$9.99/mo';
                res.message = 'Subscribed! Your ' + plan + ' plan (' + price + ') is active until ' + endDate.format() + '. All lessons are now unlocked. Refresh the page to start watching.';
            } catch (Exception e) {
                res.message = 'Something went wrong: ' + e.getMessage().left(100);
            }
            results.add(res);
        }
        return results;
    }

    private static String normalizePlan(String plan) {
        if (String.isBlank(plan)) return '';
        String trimmed = plan.trim();
        if (trimmed.equalsIgnoreCase('Monthly')) return 'Monthly';
        if (trimmed.equalsIgnoreCase('Annual')) return 'Annual';
        return '';
    }

    private static String getSessionPage(String routableId) {
        FilterState__c state = FilterState__c.getOrgDefaults();
        return state.Current_Page__c != null ? state.Current_Page__c : '';
    }
}
