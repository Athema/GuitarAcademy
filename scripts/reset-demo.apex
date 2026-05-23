// Deletes all purchases and subscriptions so the demo user can start fresh
List<Video_Purchase__c> purchases = [SELECT Id FROM Video_Purchase__c];
List<Subscription__c> subs = [SELECT Id FROM Subscription__c];

delete purchases;
delete subs;

System.debug('Demo reset: removed ' + purchases.size() + ' purchase(s) and ' + subs.size() + ' subscription(s).');
