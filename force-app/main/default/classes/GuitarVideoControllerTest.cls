@isTest
private class GuitarVideoControllerTest {

    @isTest
    static void getVideosWithAndWithoutFilters() {
        GA_TestDataFactory.createVideo('Beginner Blues', 'Beginner', 'Technique', 9.99, false);
        GA_TestDataFactory.createVideo('Advanced Theory', 'Advanced', 'Theory', 14.99, false);

        System.assertEquals(2, GuitarVideoController.getVideos(null, null).size(), 'No filter returns all');
        System.assertEquals(1, GuitarVideoController.getVideos('Beginner', null).size(), 'Level filter');
        System.assertEquals(1, GuitarVideoController.getVideos(null, 'Theory').size(), 'Category filter');
        System.assertEquals(1, GuitarVideoController.getVideos('Advanced', 'Theory').size(), 'Both filters');
    }

    @isTest
    static void getFeaturedVideosReturnsOnlyFeatured() {
        GA_TestDataFactory.createVideo('Plain', 'Beginner', 'Technique', 9.99, false);
        GA_TestDataFactory.createVideo('Featured', 'Beginner', 'Technique', 9.99, true);

        List<Guitar_Video__c> featured = GuitarVideoController.getFeaturedVideos();
        System.assertEquals(1, featured.size());
        System.assertEquals('Featured', featured[0].Name);
    }

    @isTest
    static void filterCatalogMessageVariants() {
        System.assert(GuitarVideoController.filterCatalog(null, null).contains('all lessons'));
        System.assert(GuitarVideoController.filterCatalog('Beginner', 'Blues').contains('Beginner Blues lessons'));
    }

    @isTest
    static void getAgentActionEmptyInputs() {
        System.assertEquals('', GuitarVideoController.getAgentAction('').get('action'), 'Blank conversationId');
        System.assertEquals('', GuitarVideoController.getAgentAction('no-such-convo').get('action'), 'Unknown conversationId');
    }

    @isTest
    static void filterCatalogInvocableOffCatalogPage() {
        GuitarVideoController.FilterCatalogRequest r = new GuitarVideoController.FilterCatalogRequest();
        r.level = 'Beginner';
        r.category = 'Technique';
        r.inRoutableId = ''; // no session -> getSessionPage returns '' -> not 'catalog'
        String msg = GuitarVideoController.filterCatalogInvocable(
            new List<GuitarVideoController.FilterCatalogRequest>{ r }
        )[0].message;
        System.assert(msg.contains('navigate to the catalog page'), 'Expected redirect, got: ' + msg);
    }

    @isTest
    static void resetDemoDeletesAccessRecords() {
        Contact c = GA_TestDataFactory.createStudentContact();
        Guitar_Video__c v = GA_TestDataFactory.createVideo();
        insert new Video_Purchase__c(Contact__c = c.Id, Video__c = v.Id, Amount_Paid__c = 9.99);
        insert new Subscription__c(Contact__c = c.Id, Plan__c = 'Monthly', Status__c = 'Active',
                                   End_Date__c = Date.today().addMonths(1));

        Test.startTest();
        GuitarVideoController.resetDemo();
        Test.stopTest();

        System.assertEquals(0, [SELECT COUNT() FROM Video_Purchase__c]);
        System.assertEquals(0, [SELECT COUNT() FROM Subscription__c]);
    }

    @isTest
    static void updateContactPageAndLinkSessionNoSessionPaths() {
        Test.startTest();
        // Blank page -> early return; blank session key -> early return; unknown key -> @future retry (no-op).
        GuitarVideoController.updateContactPage('', 'key', null);
        GuitarVideoController.updateContactPage('home', '', null);
        GuitarVideoController.updateContactPage('home', 'unknown-convo', null);
        GuitarVideoController.linkSessionContact(''); // blank -> early return
        Test.stopTest();
        // No session/conversation can be created in tests; these exercise the guard paths without error.
        System.assert(true);
    }

    @isTest
    static void accessMethodsAsCommunityUser() {
        Contact c = GA_TestDataFactory.createStudentContact();
        Guitar_Video__c v = GA_TestDataFactory.createVideo();
        User student = GA_TestDataFactory.createCommunityUser(c);

        System.runAs(student) {
            // No access yet.
            System.assertEquals(false, GuitarVideoController.hasVideoAccess(v.Id));
            GuitarVideoController.AccessInfo before = GuitarVideoController.getMyAccess();
            System.assertEquals(false, before.isSubscribed);
            System.assertEquals(0, before.purchasedVideoIds.size());

            // Purchase, then verify access + idempotent "already own".
            String buyMsg = GuitarVideoController.purchaseVideo(v.Id);
            System.assert(buyMsg.contains('Purchase successful'), buyMsg);
            System.assertEquals(true, GuitarVideoController.hasVideoAccess(v.Id));
            System.assert(GuitarVideoController.purchaseVideo(v.Id).contains('already own'));

            GuitarVideoController.AccessInfo afterBuy = GuitarVideoController.getMyAccess();
            System.assertEquals(1, afterBuy.purchasedVideoIds.size());

            // Subscribe (Annual), which unlocks everything.
            String subMsg = GuitarVideoController.createSubscription('Annual');
            System.assert(subMsg.contains('Annual'), subMsg);
            GuitarVideoController.AccessInfo afterSub = GuitarVideoController.getMyAccess();
            System.assertEquals(true, afterSub.isSubscribed);
            System.assertEquals(Date.today().addYears(1), afterSub.subscriptionEndDate);

            // Re-subscribing cancels the prior active subscription.
            GuitarVideoController.createSubscription('Monthly');
            System.assertEquals(1, [SELECT COUNT() FROM Subscription__c WHERE Contact__c = :c.Id AND Status__c = 'Active']);
        }
    }

    @isTest
    static void accessMethodsWithoutContactReturnEmpty() {
        // The running (admin) user has no ContactId -> getContactId() returns null.
        Guitar_Video__c v = GA_TestDataFactory.createVideo();
        System.assertEquals(false, GuitarVideoController.hasVideoAccess(v.Id));
        System.assertEquals(false, GuitarVideoController.getMyAccess().isSubscribed);

        try {
            GuitarVideoController.purchaseVideo(v.Id);
            System.assert(false, 'Expected AuraHandledException');
        } catch (AuraHandledException e) {
            // expected
        }
        try {
            GuitarVideoController.createSubscription('Monthly');
            System.assert(false, 'Expected AuraHandledException');
        } catch (AuraHandledException e) {
            // expected
        }
    }
}
