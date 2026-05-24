# Guitar Academy — Context for Code Review

## What This Is
Salesforce B2C demo: Experience Cloud (LWR) site where students browse guitar lesson videos, purchase them, and chat with an Agentforce AI agent. The agent is supposed to be page-aware and able to filter the catalog or trigger a purchase based on what page the student is on.

## Org Credentials
- Alias: `GuitarAcademy`
- Username: `guitar@academy.com`
- Deploy command: `$env:NODE_TLS_REJECT_UNAUTHORIZED=0; sf project deploy start --source-dir force-app --target-org GuitarAcademy`

---

## What Works
- Experience Cloud site loads, students can register/log in
- Video catalog displays correctly, manual filter dropdowns work
- `guitarPageTracker` LWC detects page navigation and calls `updateContactPage` Apex
- `updateContactPage` writes to `MessagingSession.Current_Page__c` via direct SOQL + update
- The debug bar (`guitarSessionDebug` LWC) reads `MessagingSession.Current_Page__c` and shows the correct page in real time — this is confirmed working
- `filterCatalogInvocable` (Apex `@InvocableMethod`) writes to `FilterState__c` hierarchy custom setting
- `guitarVideoCatalog` polls `getFilterSettings()` every 2 seconds and updates `selectedLevel`/`selectedCategory`, which re-runs the `@wire(getVideos)` query

## What Is Broken
**The Agentforce agent does not see the correct `currentPage` variable value.**

The agent (configured via AgentScript in Agentforce Builder) has a `currentPage` variable. The page tracking chain writes to `MessagingSession.Current_Page__c` correctly (confirmed via debug bar). But the agent behaves as if `currentPage` is always blank/null:
- When asked to filter, it says "please use the filter options on the page manually" instead of calling `filter_catalog`
- The `available when @variables.currentPage == "catalog"` guard never clears
- Debug action (`GuitarDebugController`) was added but its output never appears in chat — the agent doesn't call it even when `run @actions.debug_context` is in the subagent instructions (NOTE: `run` forced-execution syntax may only work in `start_agent`, not subagents)

## Approaches Tried (All Failed)

### 1. Flow-based refresh (mutable string)
- `currentPage` as `mutable string`, refreshed via an AutoLaunched Flow (`Get_Messaging_Session`) called from agent_router instructions with `run @actions.get_session`
- Flow queries MessagingSession by Id, returns `CurrentPage` as a String output variable
- AgentScript: `set @variables.currentPage = @outputs.CurrentPage`
- **Result**: `currentPage` appears to always be blank. Flow runs (no errors) but the variable is never set.

### 2. Linked string
- `currentPage` as `linked string` sourced from `@MessagingSession.Current_Page__c`
- **Result**: Agent still doesn't see the correct page. Unknown whether linked strings refresh per-turn or only at session start.

### 3. Debug action
- `GuitarDebugController` Apex class with `@InvocableMethod` that echoes back variable values
- Added to ecommerce subagent with instructions to call it
- `run @actions.debug_context` in subagent instructions (attempted forced execution)
- **Result**: Debug output never appears in chat. Agent doesn't call the action.

---

## Key Files

### AgentScript (source of truth for agent config)
`docs/agentscript/Guitar_Academy_Assistant.yaml`
- This is the YAML you paste into Agentforce Builder (Setup → Agent Studio → Guitar Academy Assistant → Agent Script tab)
- Current version uses `linked string` for `currentPage` and `currentVideoId`

### Apex Classes
- `force-app/main/default/classes/GuitarVideoController.cls` — main controller: getVideos, filterCatalog, filterCatalogInvocable, updateContactPage, getFilterSettings, getAgentPageContext
- `force-app/main/default/classes/GuitarPurchaseController.cls` — separate class for purchase @InvocableMethod (Salesforce only allows one @InvocableMethod per class)
- `force-app/main/default/classes/GuitarDebugController.cls` — debug @InvocableMethod that echoes variable values

### LWCs
- `force-app/main/default/lwc/guitarPageTracker/` — tracks page navigation, calls updateContactPage. Uses `localStorage` to persist `_conversationId` across component lifecycle (LWR recreates components on navigation)
- `force-app/main/default/lwc/guitarSessionDebug/` — debug bar showing current page + "Agent sees:" polled from MessagingSession
- `force-app/main/default/lwc/guitarVideoCatalog/` — catalog with polling filter (works)

### MessagingSession Custom Fields (all deployed)
- `Current_Page__c` — Text 50, set by updateContactPage
- `Current_Video_Id__c` — Text 18, set by updateContactPage when on a video record page
- `Action__c` — Text 50, set by filterCatalogInvocable
- `ActionJSON__c` — LongTextArea 2000, set by filterCatalogInvocable

### Flow
`force-app/main/default/flows/Get_Messaging_Session.flow-meta.xml`
- AutoLaunchedFlow, SystemModeWithoutSharing
- Input: `inRoutableId` (String) — the MessagingSession Id
- Queries MessagingSession WHERE Id = inRoutableId
- Outputs: `CurrentPage` (String from Current_Page__c), `CurrentVideoId` (String from Current_Video_Id__c)

---

## The Core Mystery
`MessagingSession.Current_Page__c` is definitely being updated (debug bar confirms).
The flow reads from that field and returns it.
But `currentPage` in the agent is always blank.

**Hypothesis A**: `linked string` variables in Agentforce only read at session start, never refresh. Even though the underlying record changes, the agent sees the value from when the session was created (null).

**Hypothesis B**: The flow output `CurrentPage` is not mapping correctly to `@outputs.CurrentPage` in the AgentScript. The path syntax may be wrong.

**Hypothesis C**: Mutable variables set in `start_agent` are not visible to subagents.

**Hypothesis D**: The `available when` condition is evaluated once at subagent load, not on every turn.

---

## What Needs to Work for the Demo
1. Student on Catalog page → asks agent "show me beginner lessons" → catalog filters on screen
2. Student on Video page → asks agent "buy this" → purchase record created
3. Student on Home page → asks agent "filter by beginner" → agent says "go to catalog first"

The filter mechanism itself (FilterState__c polling) works fine. The only blocker is the agent not knowing what page the student is on.
