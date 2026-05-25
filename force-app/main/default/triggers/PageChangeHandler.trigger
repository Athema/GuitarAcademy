trigger PageChangeHandler on PageChange__e (after insert) {
    Map<String, String> pageByConversationId = new Map<String, String>();

    for (PageChange__e e : Trigger.new) {
        if (String.isBlank(e.Page_Name__c)) continue;
        if (String.isNotBlank(e.Session_Key__c)) {
            pageByConversationId.put(e.Session_Key__c, e.Page_Name__c);
        }
    }

    if (pageByConversationId.isEmpty()) return;

    List<MessagingSession> sessions = [
        SELECT Id FROM MessagingSession
        WHERE Conversation.ConversationIdentifier IN :pageByConversationId.keySet()
    ];

    System.debug('PageChangeHandler: found ' + sessions.size() + ' session(s) by ConversationIdentifier');

    List<SObject> toUpdate = new List<SObject>();
    for (MessagingSession s : sessions) {
        SObject updateSession = new MessagingSession(Id = s.Id);
        updateSession.put('Current_Page__c', pageByConversationId.values()[0]);
        toUpdate.add(updateSession);
    }
    if (!toUpdate.isEmpty()) {
        try {
            update toUpdate;
            System.debug('PageChangeHandler: updated Current_Page__c successfully');
        } catch (Exception ex) {
            System.debug('PageChangeHandler: update failed: ' + ex.getMessage());
        }
    }
}
