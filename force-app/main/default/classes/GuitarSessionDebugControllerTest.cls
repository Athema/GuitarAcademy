@isTest
private class GuitarSessionDebugControllerTest {

    @isTest
    static void isDebugEnabledReflectsOrgDefault() {
        // No org default yet -> disabled.
        System.assertEquals(false, GuitarSessionDebugController.isDebugEnabled());

        insert new Debug_Config__c(SetupOwnerId = UserInfo.getOrganizationId(), Enabled__c = true);
        System.assertEquals(true, GuitarSessionDebugController.isDebugEnabled());
    }

    @isTest
    static void debugSnapshotHandlesBlankAndUnknownConversation() {
        Map<String, String> blank = GuitarSessionDebugController.getDebugSnapshot('');
        System.assertEquals('false', blank.get('found'));
        System.assertEquals('no conversationId yet', blank.get('note'));

        Map<String, String> unknown = GuitarSessionDebugController.getDebugSnapshot('no-such-convo');
        System.assertEquals('false', unknown.get('found'));
        System.assert(unknown.get('note').contains('not queryable'), unknown.get('note'));
    }
    // Note: the session-found snapshot branch needs a real MessagingSession + Conversation,
    // which cannot be created in Apex tests, so it is not covered.
}
