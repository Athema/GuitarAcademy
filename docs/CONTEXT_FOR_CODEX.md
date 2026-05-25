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
- `updateContactPage` writes to `MessagingSession.Current_Page__c` and `Current_Video_Id__c` via direct SOQL + update (with `@future` retry)
- The debug bar (`guitarSessionDebug` LWC) reads `MessagingSession.Current_Page__c` and shows the correct page in real time — **this is confirmed working**
- The Agentforce agent's `available when @variables.currentPage == "catalog"` guard **does clear** when the student is on the catalog page — the agent transitions from saying "use filter options manually" to saying "the catalog is now filtered to beginner" — so variable propagation IS working
- `filterCatalogInvocable` (Apex `@InvocableMethod`) writes to `FilterState__c` hierarchy custom setting AND to `MessagingSession.Action__c`/`ActionJSON__c`
- `guitarVideoCatalog` polls `getFilterSettings()` every 2 seconds and also listens to `onEmbeddedMessageSent` for agent messages

## What Is Broken
**The catalog does not visually update when the agent calls `filter_catalog`.**

The agent correctly calls the action (confirmed by its response text changing to "The catalog is now filtered to show only beginner-level songs"). But the LWC catalog component does not re-render with the filtered results.

---

## Architecture: How Page Context Flows

### To Agentforce (LWC → Apex → MessagingSession → Agent)
1. `guitarPageTracker` listens to `CurrentPageReference` wire and `onEmbeddedMessagingConversationOpened` event
2. On navigation, calls `updateContactPage(pageName, conversationId, videoId)`
3. Apex queries `MessagingSession WHERE Conversation.ConversationIdentifier = :conversationId` and updates `Current_Page__c` and `Current_Video_Id__c`
4. Agent Router (`start_agent`) runs `run @actions.get_session` on every message, which calls `flow://Get_Messaging_Session`
5. Flow queries MessagingSession by Id (using `@variables.RoutableId`) and returns the full SObject record
6. AgentScript sets: `set @variables.MyMS = @outputs.MessagingSession.data`, `set @variables.currentPage = @outputs.MessagingSession.data.Current_Page__c`, `set @variables.currentVideoId = @outputs.MessagingSession.data.Current_Video_Id__c`
7. Ecommerce subagent has `available when @variables.currentPage == "catalog"` on `filter_catalog` and `available when @variables.currentPage == "video"` on `purchase_video`

### From Agentforce (Agent → Apex → MessagingSession → LWC)
1. Agent calls `filter_catalog` action → `filterCatalogInvocable` Apex runs
2. Apex writes `FilterState__c.Level__c` (org-level hierarchy custom setting)
3. Apex also writes `MessagingSession.Action__c = 'FILTER'` and `MessagingSession.ActionJSON__c = JSON.serialize({level, category})`
4. `guitarVideoCatalog` should pick this up via:
   - **Event-driven**: `onEmbeddedMessageSent` listener → calls `getAgentAction()` → reads `MessagingSession.Action__c` → updates `selectedLevel`/`selectedCategory`
   - **Polling fallback**: `setInterval` every 2s → calls `getFilterSettings()` → reads `FilterState__c` → updates `selectedLevel`/`selectedCategory`
5. When `selectedLevel` changes, `@wire(getVideos, { level: '$selectedLevel' })` re-executes and re-renders

---

## The Core Mystery (Current Blocker)
The agent calls `filter_catalog` (confirmed by response text). `filterCatalogInvocable` presumably runs. But the catalog LWC does not update.

**Possible causes — not yet confirmed:**

**Hypothesis A**: `filterCatalogInvocable` is not actually being called — the agent LLM is generating a "success" response without invoking the action. The action message would then come from LLM hallucination, not the Apex `is_displayable` output.

**Hypothesis B**: `filterCatalogInvocable` runs but `FilterState__c.upsert` fails silently because the agent user (`guitar_academy_assistant@...`) lacks permission to write to the custom setting. The class is `without sharing` but the agent user's profile might still block DML on custom settings.

**Hypothesis C**: `FilterState__c` IS written correctly, but `getFilterSettings()` called from a Customer Community user context returns empty because community users can't read Hierarchy Custom Settings at the org level.

**Hypothesis D**: `FilterState__c` is read correctly, but `selectedLevel` is being set to the right value yet `@wire(getVideos, { level: '$selectedLevel', cacheable=true })` serves a cached response. Since `getVideos` is `cacheable=true`, if the same parameters were requested before, the wire returns cached data without re-querying.

**Hypothesis E**: The `getAgentAction` event path never fires because `_conversationId` is lost on LWR navigation (components are recreated). We added localStorage persistence for this but it hasn't helped.

---

## Key Files

### AgentScript (source of truth for agent config)
`docs/agentscript/Guitar_Academy_Assistant.yaml`
- Paste this into Agentforce Builder (Setup → Agent Studio → Guitar Academy Assistant → Agent Script tab)
- Variables: `MyMS` (mutable object), `currentPage` (mutable string), `currentVideoId` (mutable string), `RoutableId` (linked string), `ContactId` (linked string)
- Agent Router: runs `get_session` flow on every message, sets MyMS + currentPage + currentVideoId from `@outputs.MessagingSession.data.*`
- Ecommerce subagent: guards `available when @variables.currentPage == "catalog"` / `"video"`

### Flow
`force-app/main/default/flows/Get_Messaging_Session.flow-meta.xml`
- AutoLaunchedFlow, SystemModeWithoutSharing
- Input: `inRoutableId` (String)
- Output: `MessagingSession` (SObject record, type `MessagingSession`) — the FULL record, not individual string fields
- In AgentScript, accessed as `@outputs.MessagingSession.data.Current_Page__c` etc.
- AgentScript action output declared as: `object` with `complex_data_type_name: "lightning__recordInfoType"`

### Apex Classes
- `GuitarVideoController.cls` — `getVideos` (cacheable=true), `filterCatalogInvocable` (@InvocableMethod), `getFilterSettings` (cacheable=false), `updateContactPage`, `getAgentAction`
- `GuitarPurchaseController.cls` — `purchaseVideoInvocable` (@InvocableMethod), accepts `videoId`, `contactId`, `routableId` (all on PurchaseVideoRequest class)
- `GuitarDebugController.cls` — `debugContext` (@InvocableMethod), echoes variable values — useful for agent debugging but agent doesn't call it reliably in subagents

### LWCs
- `guitarPageTracker/` — tracks page navigation, calls `updateContactPage`. Uses localStorage to persist `_conversationId` across LWR navigation
- `guitarVideoCatalog/` — catalog with event-driven + polling filter. Uses localStorage for `_conversationId`. Calls both `getAgentAction` (reads MessagingSession.Action__c) and `getFilterSettings` (reads FilterState__c) on each agent message and poll tick
- `guitarSessionDebug/` — debug bar showing current page + "Agent sees:" polled from MessagingSession

### MessagingSession Custom Fields (all deployed)
- `Current_Page__c` — Text 50, set by updateContactPage
- `Current_Video_Id__c` — Text 18, set by updateContactPage when on a video record page
- `Action__c` — Text 50, set by filterCatalogInvocable ('FILTER') and purchaseVideoInvocable (implicitly)
- `ActionJSON__c` — LongTextArea 2000, set by filterCatalogInvocable with level/category JSON

---

## Things That Were Tried and Failed

### currentPage variable approaches (all failed to populate the variable)
1. **Linked string** sourced from `@MessagingSession.Current_Page__c` — appears to only read at session start, never refreshes
2. **Mutable string** set from flow string output (`set @variables.currentPage = @outputs.CurrentPage`) — assignment silently does nothing
3. **Mutable object** (`MyMS`) set from full SObject record (`set @variables.MyMS = @outputs.MessagingSession.data`) + string extracted from it (`set @variables.currentPage = @outputs.MessagingSession.data.Current_Page__c`) — **THIS NOW WORKS** for clearing guards, but the catalog still doesn't update

### AgentScript syntax issues resolved
- `record` type → use `object`
- `complex_data_type_name: lightning__recordInfoType` needs quotes: `"lightning__recordInfoType"`
- `run @actions.xxx` forced execution only works in `start_agent`, NOT in subagents
- HyperClassifier (`model://sfdc_ai__DefaultEinsteinHyperClassifier`) in `model_config` blocks all non-transition actions — must be removed

### Catalog update approaches tried
- FilterState__c polling — wired up, running every 2s, but catalog doesn't update
- MessagingSession.Action__c event-driven — wired up, fires on agent messages, but catalog doesn't update
- localStorage for conversationId in guitarVideoCatalog — added, but catalog still doesn't update

---

## What Needs to Work for the Demo
1. Student on Catalog page → asks agent "show me beginner lessons" → catalog filters on screen
2. Student on Video page → asks agent "buy this" → purchase record created
3. Student on Home page → asks agent "filter by beginner" → agent says "go to catalog first"

Scenario 3 works. Scenario 2 is untested. Scenario 1 — the agent calls the action but the catalog does not visually update.

## Next Debug Step
Verify whether `filterCatalogInvocable` is actually writing to `FilterState__c` by querying the org after a filter attempt:
```
sf data query --query "SELECT Level__c, Category__c FROM FilterState__c" --target-org GuitarAcademy --use-tooling-api
```
If this returns blank after the agent "filters", the write is failing silently (Hypothesis B/C).
If it returns "Beginner", the problem is in the LWC reading/reacting to it (Hypothesis C/D).
