global class GuitarAcademyRegistration {

    private static final String BUCKET_ACCOUNT_NAME = 'Guitar Academy Students';
    private static final String COMMUNITY_PROFILE_NAME = 'Customer Community User';

    global static String selfRegister(String firstName, String lastName, String email,
                                      String password, String confirmPassword,
                                      String accountId, Boolean sendEmailConfirmation) {
        if (String.isBlank(firstName) || String.isBlank(lastName) || String.isBlank(email)) {
            return 'First name, last name, and email are required.';
        }
        if (!isValidPassword(password, confirmPassword)) {
            return 'Passwords do not match.';
        }

        Id bucketAccountId = getBucketAccountId();
        Profile p = [SELECT Id FROM Profile WHERE Name = :COMMUNITY_PROFILE_NAME LIMIT 1];

        Contact c = new Contact(
            FirstName = firstName,
            LastName = lastName,
            Email = email,
            AccountId = bucketAccountId
        );
        insert c;

        String baseNickname = (firstName.substring(0, 1) + lastName)
            .toLowerCase()
            .replaceAll('[^a-z0-9]', '');
        if (baseNickname.length() > 36) baseNickname = baseNickname.substring(0, 36);
        String nickname = baseNickname + String.valueOf(Math.abs(Math.mod(Crypto.getRandomInteger(), 9999)));

        String alias = baseNickname.length() > 8 ? baseNickname.substring(0, 8) : baseNickname;

        User u = new User(
            Username = email,
            Email = email,
            FirstName = firstName,
            LastName = lastName,
            Alias = alias,
            ContactId = c.Id,
            ProfileId = p.Id,
            CommunityNickname = nickname,
            LocaleSidKey = 'en_US',
            TimeZoneSidKey = 'America/Los_Angeles',
            LanguageLocaleKey = 'en_US',
            EmailEncodingKey = 'UTF-8'
        );

        String userId;
        try {
            userId = Site.createPortalUser(u, bucketAccountId, password, sendEmailConfirmation);
        } catch (Exception e) {
            return e.getMessage();
        }

        if (userId != null) {
            assignPermissionSet(userId);
        }

        return null; // null = success
    }

    global static Boolean isValidPassword(String password, String confirmPassword) {
        return String.isNotBlank(password) && password == confirmPassword;
    }

    global static Boolean forgotPassword(String username) {
        return Site.forgotPassword(username);
    }

    @future
    private static void assignPermissionSet(String userId) {
        PermissionSet ps = [SELECT Id FROM PermissionSet WHERE Name = 'Guitar_Academy_Student' LIMIT 1];
        insert new PermissionSetAssignment(AssigneeId = userId, PermissionSetId = ps.Id);
    }

    private static Id getBucketAccountId() {
        List<Account> accounts = [SELECT Id FROM Account WHERE Name = :BUCKET_ACCOUNT_NAME LIMIT 1];
        if (!accounts.isEmpty()) return accounts[0].Id;
        Account a = new Account(Name = BUCKET_ACCOUNT_NAME);
        insert a;
        return a.Id;
    }
}
