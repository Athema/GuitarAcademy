@isTest
public class GA_TestDataFactory {

    public static final String BUCKET_ACCOUNT_NAME = 'Guitar Academy Students';

    // Creates (or reuses) the bucket account and a student Contact attached to it.
    public static Contact createStudentContact() {
        Account acct;
        List<Account> existing = [SELECT Id FROM Account WHERE Name = :BUCKET_ACCOUNT_NAME LIMIT 1];
        if (!existing.isEmpty()) {
            acct = existing[0];
        } else {
            acct = new Account(Name = BUCKET_ACCOUNT_NAME);
            insert acct;
        }
        Contact c = new Contact(FirstName = 'Test', LastName = 'Student', AccountId = acct.Id);
        insert c;
        return c;
    }

    // Creates a Guitar_Video__c with a unique YouTube_ID__c (required + unique).
    public static Guitar_Video__c createVideo(String name, String level, String category, Decimal price, Boolean featured) {
        Guitar_Video__c v = new Guitar_Video__c(
            Name = name,
            YouTube_ID__c = uniqueYouTubeId(),
            Level__c = level,
            Category__c = category,
            Price__c = price,
            Is_Featured__c = featured
        );
        insert v;
        return v;
    }

    public static Guitar_Video__c createVideo() {
        return createVideo('Blues Shuffle 101', 'Beginner', 'Technique', 9.99, false);
    }

    private static Integer idCounter = 0;
    public static String uniqueYouTubeId() {
        idCounter++;
        // YouTube IDs are 11 chars; keep it short and unique within the test run.
        String suffix = String.valueOf(idCounter);
        return ('yt' + '0000000000'.substring(0, 9 - suffix.length()) + suffix);
    }

    // Inserts a Customer Community user wired to the given Contact. User DML is isolated in
    // runAs() to dodge MIXED_DML_OPERATION (User is a setup object; Contact/Account are not).
    // The Guitar_Academy_Student set is assigned automatically by UserRegistrationTrigger
    // (after insert -> @future), so we do NOT assign it here (that would DUPLICATE_VALUE).
    // Note: GuitarVideoController's DML runs in Apex system mode, so the access methods work
    // for this user regardless of when the async permission-set assignment lands.
    public static User createCommunityUser(Contact c) {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Customer Community User' LIMIT 1];
        String stamp = String.valueOf(DateTime.now().getTime()) + String.valueOf(Math.abs(Crypto.getRandomInteger()));
        User u = new User(
            Username = 'gastudent' + stamp + '@guitaracademy.test.invalid',
            Email = 'gastudent@example.com',
            FirstName = 'Test',
            LastName = 'Student',
            Alias = 'gstud',
            ContactId = c.Id,
            ProfileId = p.Id,
            CommunityNickname = ('gs' + stamp).left(40),
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            LanguageLocaleKey = 'en_US',
            EmailEncodingKey = 'UTF-8'
        );
        User thisUser = new User(Id = UserInfo.getUserId());
        System.runAs(thisUser) {
            insert u;
        }
        return u;
    }

    // A minimal standard (non-portal) user, isolated in runAs to avoid MIXED_DML.
    public static User createStandardUser() {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        String stamp = String.valueOf(DateTime.now().getTime()) + String.valueOf(Math.abs(Crypto.getRandomInteger()));
        User u = new User(
            Username = 'gastd' + stamp + '@guitaracademy.test.invalid',
            Email = 'gastd@example.com',
            FirstName = 'Test',
            LastName = 'Teacher',
            Alias = 'gtea',
            ProfileId = p.Id,
            CommunityNickname = ('gt' + stamp).left(40),
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            LanguageLocaleKey = 'en_US',
            EmailEncodingKey = 'UTF-8'
        );
        User thisUser = new User(Id = UserInfo.getUserId());
        System.runAs(thisUser) {
            insert u;
        }
        return u;
    }
}
