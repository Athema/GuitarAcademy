Map<String, Schema.SObjectField> fieldMap = Schema.SObjectType.Guitar_Video__c.fields.getMap();
for(String fname : fieldMap.keySet()) {
    Schema.DescribeFieldResult dfr = fieldMap.get(fname).getDescribe();
    System.debug(fname + ' | accessible=' + dfr.isAccessible() + ' | updateable=' + dfr.isUpdateable());
}
