# MessagingSession Migration — Status & Handoff

## Goal
Replace the org-wide **`FilterState__c`** custom setting (a single shared row →
no multi-user isolation) with **per-session state on the `MessagingSession`
record**, so concurrent students each have independent state. This is the
"correct" Salesforce architecture and removes the multi-user collision risk.

## Branch / restore points
- Working branch: **`messagingSession`** (forked from `main` @ FINAL WORKING DEMO), pushed to origin.
- `main` and `develop` untouched. Restore tag on `main`: **`final-working-demo`**.

## The key discovery — why the earlier attempt failed
- Embedded-messaging sessions in this Experience Cloud site run as **GUEST / UNAUTH** users.
  Confirmed by query: `MessagingEndUser.Name = "Guest"`, `ContactId = null`,
  `MessagingPlatformKey` contains `UNAUTH`. So the agent's `@MessagingEndUser.ContactId`
  (`@variables.ContactId`) is **null**.
- The bug was **not** MessagingSession itself. It was that `getPageContext` (the agent's
  guard input) read the wrong/stale source (`FilterState__c` / a stale linked variable), so
  the `available when` guards stayed **closed** → the agent **improvised fake confirmations**.
- **Fix:** `getPageContext` now does a **live system-mode read of the agent's own
  MessagingSession by `routableId`** every utterance. Guards open correctly; the agent acts.

## Validated facts (measured live)
- Session is queryable ~**14–829 ms** after `onEmbeddedMessagingConversationOpened`
  (sub-second; **no retry needed**; only affects the first write-on-open).
- **`onEmbeddedMessageSent` fires on BOTH** the agent (`role: Chatbot`) and user
  (`role: EndUser`) messages → reliable outbound trigger.
- `MessagingSession` / `MessagingEndUser` are platform-managed: **writable only via Apex in
  system / `without sharing` context** (Flow can read, not reliably write). All writes are Apex.

## Target architecture
- **Inbound (page/video → agent):** LWC resolves session by
  `Conversation.ConversationIdentifier = :conversationId` and writes
  `Current_Page__c`/`Current_Video_Id__c` (`updateContactPage`). Agent reads its own session
  by `routableId` via `getPageContext` (live) each utterance. ✅ DONE.
- **Outbound (agent action → UI):** agent stamps `Action__c`/`ActionJSON__c` on its session;
  LWC reads via `getAgentAction(conversationId)` on `onEmbeddedMessageSent`, **no polling**.
  Player ✅ DONE & VERIFIED; catalog + featured pending.
- **Identity:** session is guest. Bridge ContactId via (a) LWC passing it and/or
  (b) `MessagingEndUserLinker` stamping `MessagingEndUser.ContactId` (also hangs the transcript
  on the Contact). NOT yet wired for the new path — purchase/subscribe currently still get
  contactId from the request param / `FilterState__c.Current_Contact_Id__c` fallback.

## Progress
**DONE**
- `getPageContext` → live session read (the root-cause guard fix).
- `GuitarSessionDebugController` + `guitarSessionDebug` panel — **TEMPORARY debug scaffolding**,
  guest-gated, **to be DELETED at the end**.
- Half 1: `purchase` / `subscribe` stamp `Action__c`/`ActionJSON__c` on the session
  (dual-write; `FilterState__c` write kept so nothing breaks). `filterCatalogInvocable` already did.
- Half 2 step 1: `guitarVideoPlayer` reads `getAgentAction` on `onEmbeddedMessageSent`,
  dropped its 2s poll. **VERIFIED: purchase + subscribe unlock instantly.**

**REMAINING**
1. **Migrate `guitarVideoCatalog`** to `getAgentAction`. Filter via `action === 'FILTER'` +
   `level`/`category` from the flattened result; access via `PURCHASE`/`SUBSCRIBE`.
   ⚠️ **Only apply the filter when `action === 'FILTER'`** — otherwise a later PURCHASE/SUBSCRIBE
   read (empty level/category) would clear the filter. Drop its 2s poll.
2. **Migrate `guitarFeaturedLessons`** to `getAgentAction` — it currently **only polls** (no
   message listener). Add an `onEmbeddedMessageSent` listener + read `conversationId` from
   `localStorage.getItem('ga_conversationId')`. Drop poll.
3. **Identity:** stamp ContactId on the session + wire `MessagingEndUserLinker` (transcript on
   Contact). Then remove the `FilterState__c.Current_Contact_Id__c` fallback.
4. **Remove redundant `FilterState__c` writes** from `updateContactPage` / purchase / subscribe /
   filter; **retire `FilterState__c`** object + `getFilterSettings`.
5. **Agent hardening:** instruct the `ecommerce` subagent to NEVER claim success on blank
   `currentPage` — tell the student to navigate instead. (Guards are reliable now; this covers
   the residual cold-start window.)
6. **DELETE debug scaffolding:** `guitarSessionDebug` (component + page placement),
   `GuitarSessionDebugController` (+ its grant in `Guitar_Academy_Student` permission set).
7. Dedicated session fields (`Level__c`/`Category__c`/`Action_Video_Id__c`/`WS_URL__c`) are
   likely **unnecessary** — `ActionJSON__c` already carries `level`/`category`/`videoId`.

## getAgentAction return shape (session-sourced, mirrors getFilterSettings)
`{ action, level, category, actionVideoId }` — `action` from `Action__c`; the rest parsed from
`ActionJSON__c` (`{level,category}` for FILTER, `{videoId}` for PURCHASE).

## Key files
- `classes/GuitarPageContextController.cls` — live session read (guard input).
- `classes/GuitarVideoController.cls` — `getAgentAction` (session read), `updateContactPage`
  (inbound write), `getFilterSettings` (legacy, to retire).
- `classes/GuitarPurchaseController.cls`, `GuitarSubscriptionController.cls` — `stampSession()` dual-write.
- `classes/GuitarSessionDebugController.cls` — **TEMP debug** (delete at end).
- `lwc/guitarVideoPlayer` — migrated (event-driven session read).
- `lwc/guitarVideoCatalog`, `lwc/guitarFeaturedLessons` — **NOT yet migrated** (still FilterState poll).
- `lwc/guitarSessionDebug` — **TEMP debug panel** (delete at end).
- `objects/MessagingSession/fields` — `Action__c`, `ActionJSON__c`, `Current_Page__c`, `Current_Video_Id__c`.
- `flows/Get_Messaging_Session.flow-meta.xml` — router read-refresh (read-only).
- `classes/MessagingEndUserLinker` (user's proven pattern; may not yet be in repo) — updates
  `MessagingEndUser.ContactId` to link the guest session to a real Contact for transcript history.

## How to test
Use the `guitarSessionDebug` panel (logged-in only). Rows: LWC page, **AGENT SEES**
(`getPageContext` view), **GUARDS** (filter/purchase OPEN/closed), session `action`, resolve
latency, event log. Navigate → guard opens; ask agent to filter/buy/subscribe → action stamps
session → UI reacts instantly.

## Deploy (always PowerShell + SSL workaround)
```powershell
$env:NODE_TLS_REJECT_UNAUTHORIZED=0; sf project deploy start --source-dir force-app --target-org GuitarAcademy
```

## Commits on branch (latest last)
- `657a0d0` Fix guard read via live MessagingSession context; add guest-gated debug panel
- `f95d963` Outbound migration Half 1: stamp MessagingSession on purchase/subscribe
- Half 2 step 1: player event-driven session read (this commit)
