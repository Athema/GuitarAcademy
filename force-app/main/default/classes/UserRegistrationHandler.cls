public class UserRegistrationHandler {

    @future
    public static void assignStudentPermissionSet(List<Id> userIds) {
        PermissionSet ps = [SELECT Id FROM PermissionSet WHERE Name = 'Guitar_Academy_Student' LIMIT 1];
        List<PermissionSetAssignment> assignments = new List<PermissionSetAssignment>();
        for (Id userId : userIds) {
            assignments.add(new PermissionSetAssignment(
                AssigneeId = userId,
                PermissionSetId = ps.Id
            ));
        }
        insert assignments;
    }
}
