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

    List<MessagingSession> toUpdate = new List<MessagingSession>();
    for (MessagingSession s : sessions) {
        toUpdate.add(new MessagingSession(Id = s.Id, Current_Page__c = pageByConversationId.values()[0]));
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
