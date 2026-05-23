Guitar_Video__c v = new Guitar_Video__c();
v.Name = 'Test';
v.YouTube_ID__c = 'testtest12345';
v.Level__c = 'Beginner';
insert v;
System.debug('Created: ' + v.Id);
