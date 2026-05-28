@isTest
private class GuitarPurchaseControllerTest {

    private static GuitarPurchaseController.PurchaseVideoRequest req(String videoId, String contactId, String routableId) {
        GuitarPurchaseController.PurchaseVideoRequest r = new GuitarPurchaseController.PurchaseVideoRequest();
        r.videoId = videoId;
        r.contactId = contactId;
        r.routableId = routableId;
        return r;
    }

    private static String runOne(GuitarPurchaseController.PurchaseVideoRequest r) {
        return GuitarPurchaseController.purchaseVideoInvocable(
            new List<GuitarPurchaseController.PurchaseVideoRequest>{ r }
        )[0].message;
    }

    @isTest
    static void purchaseSucceedsAndCreatesRecord() {
        Contact c = GA_TestDataFactory.createStudentContact();
        Guitar_Video__c v = GA_TestDataFactory.createVideo();

        Test.startTest();
        String msg = runOne(req(v.Id, c.Id, ''));
        Test.stopTest();

        System.assert(msg.contains('Purchase successful'), 'Expected success message, got: ' + msg);
        System.assertEquals(1, [SELECT COUNT() FROM Video_Purchase__c WHERE Contact__c = :c.Id AND Video__c = :v.Id]);
    }

    @isTest
    static void alreadyOwnedReturnsOwnMessageNoDuplicate() {
        Contact c = GA_TestDataFactory.createStudentContact();
        Guitar_Video__c v = GA_TestDataFactory.createVideo();
        insert new Video_Purchase__c(Contact__c = c.Id, Video__c = v.Id, Amount_Paid__c = 9.99);

        Test.startTest();
        String msg = runOne(req(v.Id, c.Id, ''));
        Test.stopTest();

        System.assert(msg.contains('already own'), 'Expected already-own message, got: ' + msg);
        System.assertEquals(1, [SELECT COUNT() FROM Video_Purchase__c WHERE Contact__c = :c.Id AND Video__c = :v.Id],
            'Should not create a duplicate purchase');
    }

    @isTest
    static void activeSubscriptionBlocksPurchase() {
        Contact c = GA_TestDataFactory.createStudentContact();
        Guitar_Video__c v = GA_TestDataFactory.createVideo();
        insert new Subscription__c(Contact__c = c.Id, Plan__c = 'Monthly', Status__c = 'Active',
                                   End_Date__c = Date.today().addMonths(1));

        Test.startTest();
        String msg = runOne(req(v.Id, c.Id, ''));
        Test.stopTest();

        System.assert(msg.contains('active subscription'), 'Expected subscription backstop message, got: ' + msg);
        System.assertEquals(0, [SELECT COUNT() FROM Video_Purchase__c WHERE Contact__c = :c.Id],
            'Subscriber should not get an individual purchase record');
    }

    @isTest
    static void missingContactReturnsIdentifyMessage() {
        Guitar_Video__c v = GA_TestDataFactory.createVideo();
        String msg = runOne(req(v.Id, '', ''));
        System.assert(msg.contains('Could not identify'), 'Expected identify message, got: ' + msg);
    }

    @isTest
    static void missingVideoReturnsNoVideoMessage() {
        Contact c = GA_TestDataFactory.createStudentContact();
        String msg = runOne(req('', c.Id, ''));
        System.assert(msg.contains('No video detected'), 'Expected no-video message, got: ' + msg);
    }

    @isTest
    static void malformedIdHitsCatchBlock() {
        // A non-Id string fails the (Id) cast, exercising the try/catch fallback.
        String msg = runOne(req('not-an-id', 'also-bad', ''));
        System.assert(msg.contains('Something went wrong'), 'Expected catch-block message, got: ' + msg);
    }
}
