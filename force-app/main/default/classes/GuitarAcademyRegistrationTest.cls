@isTest
private class GuitarAcademyRegistrationTest {

    @isTest
    static void requiredFieldsValidation() {
        String msg = GuitarAcademyRegistration.selfRegister('', 'Doe', 'a@b.com', 'pw', 'pw', null, false);
        System.assert(msg.contains('required'), 'Expected required-fields message, got: ' + msg);
    }

    @isTest
    static void passwordMismatchValidation() {
        String msg = GuitarAcademyRegistration.selfRegister('Jane', 'Doe', 'jane@b.com', 'pw1', 'pw2', null, false);
        System.assert(msg.contains('Passwords do not match'), 'Expected mismatch message, got: ' + msg);
    }

    @isTest
    static void isValidPasswordChecks() {
        System.assertEquals(true, GuitarAcademyRegistration.isValidPassword('abc', 'abc'));
        System.assertEquals(false, GuitarAcademyRegistration.isValidPassword('abc', 'xyz'));
        System.assertEquals(false, GuitarAcademyRegistration.isValidPassword('', ''));
    }

    @isTest
    static void selfRegisterRunsThroughPortalCreation() {
        // In test context Site.createPortalUser does not create a real user (returns null and
        // does no DML), so this exercises the validation, bucket-account creation, Contact insert,
        // profile lookup, and user-build path without a live community.
        Test.startTest();
        String result = GuitarAcademyRegistration.selfRegister(
            'Jimi', 'Hendrix', 'jimi+' + Crypto.getRandomInteger() + '@guitaracademy.test.invalid',
            'rockOn123', 'rockOn123', null, false);
        Test.stopTest();

        // Either null (success) or a Site message — both mean the code path executed without an
        // uncaught exception. Assert the bucket account + contact were created along the way.
        System.assertEquals(1, [SELECT COUNT() FROM Account WHERE Name = :GA_TestDataFactory.BUCKET_ACCOUNT_NAME]);
        System.assert([SELECT COUNT() FROM Contact WHERE LastName = 'Hendrix'] >= 1);
    }

    @isTest
    static void forgotPasswordExecutes() {
        // Site.forgotPassword returns false in test context (no live site) but should not throw.
        Boolean result = GuitarAcademyRegistration.forgotPassword('nobody@guitaracademy.test.invalid');
        System.assertEquals(false, result);
    }
}
