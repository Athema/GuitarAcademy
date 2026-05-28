@isTest
private class GuitarPageContextControllerTest {

    private static String run(String routableId) {
        GuitarPageContextController.PageContextRequest r = new GuitarPageContextController.PageContextRequest();
        r.routableId = routableId;
        return GuitarPageContextController.getPageContext(
            new List<GuitarPageContextController.PageContextRequest>{ r }
        )[0].message;
    }

    @isTest
    static void blankRoutableIdReportsBlank() {
        String msg = run('');
        System.assert(msg.contains('blank'), 'Expected blank-session message, got: ' + msg);
    }

    @isTest
    static void unknownSessionReportsNotFound() {
        // Valid-format but non-existent MessagingSession Id -> query returns no rows.
        String fakeId = MessagingSession.SObjectType.getDescribe().getKeyPrefix() + '000000000001';
        String msg = run(fakeId);
        System.assert(msg.contains('no MessagingSession found'), 'Expected not-found message, got: ' + msg);
    }
    // Note: the session-found branch (ownership computation) requires a real MessagingSession,
    // which cannot be created in Apex tests (no insertable MessagingChannel), so it is not covered.
}
