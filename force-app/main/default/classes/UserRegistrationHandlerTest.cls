@isTest
private class UserRegistrationHandlerTest {

    @isTest
    static void assignsStudentPermissionSet() {
        // Standard (non-portal) user does not auto-receive the student set, so the handler's
        // assignment is observable. No non-setup DML here -> no MIXED_DML with the @future insert.
        User u = GA_TestDataFactory.createStandardUser();

        Test.startTest();
        UserRegistrationHandler.assignStudentPermissionSet(new List<Id>{ u.Id });
        Test.stopTest(); // @future runs here

        System.assertEquals(1, [SELECT COUNT() FROM PermissionSetAssignment
                                WHERE AssigneeId = :u.Id
                                AND PermissionSet.Name = 'Guitar_Academy_Student']);
    }
}
