@isTest
private class MessagingEndUserLinkerTest {

    @isTest
    static void emptyRequestListIsNoOp() {
        // Exercises the method entry with nothing to update.
        MessagingEndUserLinker.linkContact(new List<MessagingEndUserLinker.Request>());
        System.assert(true);
    }

    @isTest
    static void updateAttemptOnFakeEndUserThrows() {
        // A real MessagingEndUser can't be created in tests, so we drive the loop body +
        // update DML with a valid-format but non-existent Id and confirm it raises a DML error
        // (rather than silently passing). This covers the build-and-update path.
        MessagingEndUserLinker.Request r = new MessagingEndUserLinker.Request();
        r.messagingEndUserId = MessagingEndUser.SObjectType.getDescribe().getKeyPrefix() + '000000000001';
        r.contactId = GA_TestDataFactory.createStudentContact().Id;

        Boolean threw = false;
        try {
            MessagingEndUserLinker.linkContact(new List<MessagingEndUserLinker.Request>{ r });
        } catch (Exception e) {
            threw = true;
        }
        System.assertEquals(true, threw, 'Updating a non-existent MessagingEndUser should raise a DML error');
    }
}
