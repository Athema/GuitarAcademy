// Instantiate / update the org-default Debug_Config__c record.
// Toggle the value below (true = show debug panel, false = hide).
Debug_Config__c c = Debug_Config__c.getOrgDefaults();
if (c.Id == null) {
    c.SetupOwnerId = UserInfo.getOrganizationId();
}
c.Enabled__c = true;
upsert c;
System.debug('Debug_Config__c org default -> Enabled__c=' + c.Enabled__c + ' Id=' + c.Id);
