# Agentforce Preparation — Apex Inventory & Required Changes

## Current Apex Classes

### GuitarVideoController
`force-app/main/default/classes/GuitarVideoController.cls`

All methods are `@AuraEnabled` on a `global without sharing` class. The class and all agent-facing methods are already `global` — no further visibility changes needed.

---

## Method Inventory

### 1. `getVideos(String level, String category)`
- **Returns:** `List<Guitar_Video__c>` — Id, Name, YouTube_ID__c, Thumbnail_URL__c, Level__c, Category__c, Price__c, Duration_Minutes__c, Description__c
- **Current:** `@AuraEnabled(cacheable=true)`, `global static` ✓
- **Agent use:** Let the agent browse or filter the catalog by level (Beginner / Intermediate / Advanced) or category (Technique / Theory / Song Lesson / Gear & Tone). Pass empty strings for no filter.
- **Changes needed:** None — register as Apex Action in Agent Builder.

---

### 2. `getFeaturedVideos()`
- **Returns:** `List<Guitar_Video__c>` — same fields minus Description__c
- **Current:** `@AuraEnabled(cacheable=true)`, `global static` ✓
- **Agent use:** Optional — agent can mention featured lessons when greeting a new user or when they ask "what do you recommend?"
- **Changes needed:** None — register as Apex Action in Agent Builder.

---

### 3. `getMyAccess()`
- **Returns:** `AccessInfo` wrapper — `isSubscribed (Boolean)`, `purchasedVideoIds (List<Id>)`, `subscriptionEndDate (Date)`
- **Current:** `@AuraEnabled(cacheable=false)`, `global static` ✓; `AccessInfo` inner class is `global` ✓
- **Agent use:** Agent checks whether the user already has access before recommending a purchase or subscription. Also lets the agent confirm subscription status when asked.
- **Changes needed:** None — register as Apex Action in Agent Builder.

---

### 4. `hasVideoAccess(Id videoId)`
- **Returns:** `Boolean`
- **Current:** `@AuraEnabled(cacheable=false)`, `global static` ✓
- **Agent use:** Narrower version of `getMyAccess` — useful if agent only needs to check one specific video. May be redundant once `getMyAccess` is available.
- **Changes needed:** None — register as Apex Action in Agent Builder if needed.

---

### 5. `purchaseVideo(Id videoId)`
- **Returns:** `String` — success or already-owned message ✓
- **Current:** `@AuraEnabled(cacheable=false)`, `global static` ✓
- **Agent use:** Core transaction action — agent completes a one-time purchase after the user confirms. Returns a human-readable confirmation the agent can relay to the student.
- **Changes needed:** None — register as Apex Action in Agent Builder.

---

### 6. `createSubscription(String plan)`
- **Returns:** `String` — confirmation with plan name, price, and end date ✓
- **Current:** `@AuraEnabled(cacheable=false)`, `global static` ✓
- **Agent use:** Core transaction action — agent subscribes the user. Valid values for `plan`: `'Monthly'` (→ $9.99/mo, +1 month end date) or `'Annual'` (→ $79.99/yr, +1 year end date). Returns a human-readable confirmation.
- **Changes needed:** None — register as Apex Action in Agent Builder.

---

### 7. `filterCatalog(String level, String category)`
- **Returns:** `String` — e.g., `'Done! The catalog is now showing Beginner Technique lessons.'` ✓
- **Current:** `@AuraEnabled(cacheable=false)`, `global static` ✓
- **Agent use:** Lets the agent operate the catalog filters on behalf of the user. Publishes a `CatalogFilter__e` Platform Event that the `guitarVideoCatalog` LWC receives via `lightning/empApi` and applies immediately. Pass empty strings to reset filters.
- **Changes needed:** None — register as Apex Action in Agent Builder.

---

### 8. `resetDemo()`
- **Returns:** `void`
- **Current:** `@AuraEnabled(cacheable=false)`, `public static`
- **Agent use:** None — demo utility only. **Do not expose to agent.**

---

## How to Expose Apex to Agentforce

There are two paths — **use path 2** for this project:

### Path 1: `@InvocableMethod` (NOT recommended here)
Traditional Flow/automation path. Requires:
- One `@InvocableMethod` per class
- Awkward `List<InputClass>` / `List<OutputClass>` wrappers with `@InvocableVariable` fields
- Splitting `GuitarVideoController` into multiple classes

Use this only if the same actions also need to run in Flows.

### Path 2: Apex Action in Agent Builder (recommended)
Agentforce-native path. You register any `global static` method directly as an **Agent Action** in Setup → Agents → Actions. No `@InvocableMethod` annotation needed — the platform reads the method signature and maps inputs/outputs automatically.

**This is simpler and the right approach for agent-only use.**

---

## Summary of Code Changes — Status

All required Apex changes are **done and deployed**:

| Change | Status |
|---|---|
| Class: `public` → `global without sharing` | ✓ Done |
| `AccessInfo` inner class: `public` → `global` | ✓ Done |
| All agent-facing methods: `public static` → `global static` | ✓ Done |
| `purchaseVideo` returns `String` (was `void`) | ✓ Done |
| `createSubscription` returns `String` (was `void`) | ✓ Done |
| `filterCatalog` new method added + `CatalogFilter__e` Platform Event | ✓ Done |
| `Guitar_Academy_Agent` permission set with class access | ✓ Done |

`resetDemo` intentionally left as `public` — not exposed to agent.

---

## Agentforce Setup Steps (After Code Changes)

1. **Deploy** updated `GuitarVideoController` (global class, global methods)
2. **Setup → Agents → Actions** — register each method as an Apex Action:
   - `getVideos` — "Browse lesson catalog by level and category"
   - `getMyAccess` — "Check what the current user has purchased or subscribed to"
   - `purchaseVideo` — "Purchase a specific lesson for the current user"
   - `createSubscription` — "Subscribe the current user to Monthly or Annual plan"
3. **Agent Builder** → New Agent → type: "Customer-Facing"
4. **Topics** — create topics and assign the registered actions:
   - *Browse Catalog* → `getVideos`, `getFeaturedVideos`, `filterCatalog`
   - *Check My Access* → `getMyAccess`
   - *Purchase a Lesson* → `purchaseVideo`
   - *Subscribe* → `createSubscription`
5. **Instructions** — system prompt: agent is a guitar teacher assistant, knows the lesson content, helps students find and buy the right lessons
6. **Knowledge** — add lesson descriptions as a knowledge source (Salesforce Knowledge article or uploaded file with all 12 lesson summaries)
7. **Channel** — wire agent into the Experience Cloud site via Messaging for In-App & Web
8. **Test & Publish**

---

## Picklist Reference (for agent prompts)

**Level__c:** `Beginner`, `Intermediate`, `Advanced`

**Category__c:** `Technique`, `Theory`, `Song Lesson`, `Gear & Tone`

**Subscription Plan__c:** `Monthly` ($9.99/mo), `Annual` ($79.99/yr)
