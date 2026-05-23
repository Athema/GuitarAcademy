public without sharing class GuitarVideoController {

    public class AccessInfo {
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
    public static List<Guitar_Video__c> getVideos(String level, String category) {
        String q = 'SELECT Id, Name, YouTube_ID__c, Thumbnail_URL__c, Level__c, Category__c, Price__c, Duration_Minutes__c, Description__c FROM Guitar_Video__c';
        List<String> conditions = new List<String>();
        if (String.isNotBlank(level))    conditions.add('Level__c = \'' + String.escapeSingleQuotes(level) + '\'');
        if (String.isNotBlank(category)) conditions.add('Category__c = \'' + String.escapeSingleQuotes(category) + '\'');
        if (!conditions.isEmpty()) q += ' WHERE ' + String.join(conditions, ' AND ');
        q += ' ORDER BY Level__c, Name LIMIT 200';
        return Database.query(q);
    }

    @AuraEnabled(cacheable=true)
    public static List<Guitar_Video__c> getFeaturedVideos() {
        return [SELECT Id, Name, YouTube_ID__c, Thumbnail_URL__c, Level__c, Category__c, Price__c, Duration_Minutes__c
                FROM Guitar_Video__c
                WHERE Is_Featured__c = true
                ORDER BY Level__c, Name
                LIMIT 3];
    }

    @AuraEnabled(cacheable=false)
    public static Boolean hasVideoAccess(Id videoId) {
        Id contactId = getContactId();
        if (contactId == null) return false;
        if ([SELECT COUNT() FROM Video_Purchase__c WHERE Contact__c = :contactId AND Video__c = :videoId] > 0) return true;
        return [SELECT COUNT() FROM Subscription__c WHERE Contact__c = :contactId AND Status__c = 'Active'] > 0;
    }

    @AuraEnabled(cacheable=false)
    public static AccessInfo getMyAccess() {
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
    public static void purchaseVideo(Id videoId) {
        Id contactId = getContactId();
        if (contactId == null) throw new AuraHandledException('Not a community user.');
        if ([SELECT COUNT() FROM Video_Purchase__c WHERE Contact__c = :contactId AND Video__c = :videoId] > 0) return;
        Guitar_Video__c video = [SELECT Price__c FROM Guitar_Video__c WHERE Id = :videoId LIMIT 1];
        insert new Video_Purchase__c(Contact__c = contactId, Video__c = videoId, Amount_Paid__c = video.Price__c);
    }

    @AuraEnabled(cacheable=false)
    public static void createSubscription(String plan) {
        Id contactId = getContactId();
        if (contactId == null) throw new AuraHandledException('Not a community user.');
        List<Subscription__c> existing = [SELECT Id FROM Subscription__c WHERE Contact__c = :contactId AND Status__c = 'Active'];
        for (Subscription__c s : existing) s.Status__c = 'Cancelled';
        if (!existing.isEmpty()) update existing;
        Date endDate = plan == 'Annual' ? Date.today().addYears(1) : Date.today().addMonths(1);
        insert new Subscription__c(Contact__c = contactId, Plan__c = plan, Status__c = 'Active', End_Date__c = endDate);
    }

    @AuraEnabled(cacheable=false)
    public static void resetDemo() {
        delete [SELECT Id FROM Video_Purchase__c];
        delete [SELECT Id FROM Subscription__c];
    }

    private static Id getContactId() {
        List<User> users = [SELECT ContactId FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];
        return (users.isEmpty() || users[0].ContactId == null) ? null : users[0].ContactId;
    }
}
