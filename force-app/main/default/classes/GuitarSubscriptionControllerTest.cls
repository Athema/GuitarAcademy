@isTest
private class GuitarSubscriptionControllerTest {

    private static String run(String plan, String contactId, String routableId) {
        GuitarSubscriptionController.SubscriptionRequest r = new GuitarSubscriptionController.SubscriptionRequest();
        r.plan = plan;
        r.contactId = contactId;
        r.routableId = routableId;
        return GuitarSubscriptionController.createSubscription(
            new List<GuitarSubscriptionController.SubscriptionRequest>{ r }
        )[0].message;
    }

    @isTest
    static void monthlySubscriptionCreated() {
        Contact c = GA_TestDataFactory.createStudentContact();

        Test.startTest();
        String msg = run('Monthly', c.Id, '');
        Test.stopTest();

        System.assert(msg.contains('Monthly'), 'Expected Monthly confirmation, got: ' + msg);
        List<Subscription__c> subs = [SELECT Plan__c, Status__c, End_Date__c FROM Subscription__c WHERE Contact__c = :c.Id];
        System.assertEquals(1, subs.size());
        System.assertEquals('Active', subs[0].Status__c);
        System.assertEquals(Date.today().addMonths(1), subs[0].End_Date__c);
    }

    @isTest
    static void annualSubscriptionCreated() {
        Contact c = GA_TestDataFactory.createStudentContact();
        String msg = run('annual', c.Id, ''); // lower-case to exercise normalizePlan
        System.assert(msg.contains('Annual'), 'Expected Annual confirmation, got: ' + msg);
        System.assertEquals(Date.today().addYears(1),
            [SELECT End_Date__c FROM Subscription__c WHERE Contact__c = :c.Id LIMIT 1].End_Date__c);
    }

    @isTest
    static void newSubscriptionCancelsPriorActiveOne() {
        Contact c = GA_TestDataFactory.createStudentContact();
        insert new Subscription__c(Contact__c = c.Id, Plan__c = 'Monthly', Status__c = 'Active',
                                   End_Date__c = Date.today().addMonths(1));

        Test.startTest();
        run('Annual', c.Id, '');
        Test.stopTest();

        System.assertEquals(1, [SELECT COUNT() FROM Subscription__c WHERE Contact__c = :c.Id AND Status__c = 'Active']);
        System.assertEquals(1, [SELECT COUNT() FROM Subscription__c WHERE Contact__c = :c.Id AND Status__c = 'Cancelled']);
    }

    @isTest
    static void invalidPlanReturnsPrompt() {
        Contact c = GA_TestDataFactory.createStudentContact();
        String msg = run('Weekly', c.Id, '');
        System.assert(msg.contains('Monthly or Annual'), 'Expected plan prompt, got: ' + msg);
        System.assertEquals(0, [SELECT COUNT() FROM Subscription__c WHERE Contact__c = :c.Id]);
    }

    @isTest
    static void missingContactReturnsIdentifyMessage() {
        String msg = run('Monthly', '', '');
        System.assert(msg.contains('Could not identify'), 'Expected identify message, got: ' + msg);
    }

    @isTest
    static void malformedContactIdHitsCatchBlock() {
        // A non-Id string fails the (Id) cast, exercising the try/catch fallback.
        String msg = run('Monthly', 'not-an-id', '');
        System.assert(msg.contains('Something went wrong'), 'Expected catch-block message, got: ' + msg);
    }
}
