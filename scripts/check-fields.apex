List<Schema.SObjectField> fields = Schema.SObjectType.Guitar_Video__c.fields.getMap().values();
List<String> names = new List<String>();
for(Schema.SObjectField f : fields) { names.add(f.getDescribe().getName()); }
System.debug(JSON.serialize(names));
