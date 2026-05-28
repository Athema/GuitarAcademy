@isTest
private class GuitarDebugControllerTest {

    @isTest
    static void debugContextFormatsPopulatedAndBlankFields() {
        GuitarDebugController.DebugRequest full = new GuitarDebugController.DebugRequest();
        full.currentPage = 'video';
        full.currentVideoId = 'a01000000000001';
        full.contactId = '003000000000001';
        full.routableId = '0Mw000000000001';

        GuitarDebugController.DebugRequest empty = new GuitarDebugController.DebugRequest();

        List<GuitarDebugController.DebugResult> results = GuitarDebugController.debugContext(
            new List<GuitarDebugController.DebugRequest>{ full, empty }
        );

        System.assert(results[0].message.contains('page=video'), results[0].message);
        System.assert(results[0].message.contains('contactId=003000000000001'), results[0].message);
        System.assert(results[1].message.contains('page=NULL'), 'Blank fields should render as NULL: ' + results[1].message);
    }
}
