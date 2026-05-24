global without sharing class GuitarPageContextController {

    public class PageContextRequest {
        @InvocableVariable(label='Routable Id' description='The active MessagingSession Id')
        public String routableId;
    }

    public class PageContextResult {
        @InvocableVariable(label='Current Page')
        public String currentPage;
        @InvocableVariable(label='Current Video Id')
        public String currentVideoId;
        @InvocableVariable(label='Message')
        public String message;
    }

    @InvocableMethod(label='Get Page Context' description='Returns the current Experience Cloud page and video for the active MessagingSession.')
    public static List<PageContextResult> getPageContext(List<PageContextRequest> requests) {
        List<PageContextResult> results = new List<PageContextResult>();
        for (PageContextRequest req : requests) {
            PageContextResult res = new PageContextResult();
            FilterState__c state = FilterState__c.getOrgDefaults();
            res.currentPage = state.Current_Page__c != null ? state.Current_Page__c : '';
            res.currentVideoId = state.Current_Video_Id__c != null ? state.Current_Video_Id__c : '';
            res.message = 'Page context loaded.';
            results.add(res);
        }
        return results;
    }
}
