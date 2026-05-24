global without sharing class GuitarDebugController {

    public class DebugRequest {
        @InvocableVariable(label='Current Page')
        public String currentPage;
        @InvocableVariable(label='Current Video Id')
        public String currentVideoId;
        @InvocableVariable(label='Contact Id')
        public String contactId;
        @InvocableVariable(label='Routable Id')
        public String routableId;
    }

    public class DebugResult {
        @InvocableVariable(label='Debug Output')
        public String message;
    }

    @InvocableMethod(label='Debug Agent Context' description='Returns current agent variable values for debugging.')
    public static List<DebugResult> debugContext(List<DebugRequest> requests) {
        List<DebugResult> results = new List<DebugResult>();
        for (DebugRequest req : requests) {
            DebugResult res = new DebugResult();
            res.message = '[DEBUG] page=' + val(req.currentPage)
                        + ' | videoId=' + val(req.currentVideoId)
                        + ' | contactId=' + val(req.contactId)
                        + ' | routableId=' + val(req.routableId);
            results.add(res);
        }
        return results;
    }

    private static String val(String s) {
        return String.isNotBlank(s) ? s : 'NULL';
    }
}
