trigger UserRegistrationTrigger on User (after insert) {
    List<Id> newPortalUserIds = new List<Id>();
    for (User u : Trigger.new) {
        if (u.ContactId != null) {
            newPortalUserIds.add(u.Id);
        }
    }
    if (!newPortalUserIds.isEmpty()) {
        UserRegistrationHandler.assignStudentPermissionSet(newPortalUserIds);
    }
}
