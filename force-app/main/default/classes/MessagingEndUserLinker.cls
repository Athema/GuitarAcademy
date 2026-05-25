public class MessagingEndUserLinker {

    @InvocableMethod(label='Link Contact to Messaging End User'
                     description='Updates MessagingEndUser.ContactId to link a contact to a messaging session')
    public static void linkContact(List<Request> requests) {
        List<MessagingEndUser> toUpdate = new List<MessagingEndUser>();
        for (Request r : requests) {
            toUpdate.add(new MessagingEndUser(
                Id = r.messagingEndUserId,
                ContactId = r.contactId
            ));
        }
        update toUpdate;
    }

    public class Request {
        @InvocableVariable(label='Messaging End User Id' required=true)
        public Id messagingEndUserId;

        @InvocableVariable(label='Contact Id' required=true)
        public Id contactId;
    }
}
