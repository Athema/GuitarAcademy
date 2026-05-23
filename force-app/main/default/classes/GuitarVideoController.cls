public without sharing class GuitarVideoController {

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
        Id userId = UserInfo.getUserId();
        List<User> users = [SELECT ContactId FROM User WHERE Id = :userId LIMIT 1];
        if (users.isEmpty() || users[0].ContactId == null) return false;
        Id contactId = users[0].ContactId;

        if ([SELECT COUNT() FROM Video_Purchase__c WHERE Contact__c = :contactId AND Video__c = :videoId] > 0) return true;
        return [SELECT COUNT() FROM Subscription__c WHERE Contact__c = :contactId AND Status__c = 'Active'] > 0;
    }
}
