# Agentforce Preparation — Apex Inventory & Required Changes

## Current Apex Classes

### GuitarVideoController
`force-app/main/default/classes/GuitarVideoController.cls`

All methods are `@AuraEnabled` on a `public without sharing` class. Agentforce Apex Actions require the class and invocable methods to be `global`.

---

## Method Inventory

### 1. `getVideos(String level, String category)`
- **Returns:** `List<Guitar_Video__c>` — Id, Name, YouTube_ID__c, Thumbnail_URL__c, Level__c, Category__c, Price__c, Duration_Minutes__c, Description__c
- **Current:** `@AuraEnabled(cacheable=true)`, `public static`
- **Agent use:** Let the agent browse or filter the catalog by level (Beginner / Intermediate / Advanced) or category (Technique / Theory / Song Lesson / Gear & Tone). Pass empty strings for no filter.
- **Changes needed:**
  - Change to `global static`
  - Add `@InvocableMethod` annotation (or expose via Apex Action in Agent Builder)
  - Consider splitting into two separate invocable methods (`getVideosByLevel`, `getVideosByCategory`) since Agentforce Apex Actions support only one input class

---

### 2. `getFeaturedVideos()`
- **Returns:** `List<Guitar_Video__c>` — same fields minus Description__c
- **Current:** `@AuraEnabled(cacheable=true)`, `public static`
- **Agent use:** Optional — agent can mention featured lessons when greeting a new user or when they ask "what do you recommend?"
- **Changes needed:** Same as above (`global static`, invocable wrapper)

---

### 3. `getMyAccess()`
- **Returns:** `AccessInfo` wrapper — `isSubscribed (Boolean)`, `purchasedVideoIds (List<Id>)`, `subscriptionEndDate (Date)`
- **Current:** `@AuraEnabled(cacheable=false)`, `public static`
- **Agent use:** Agent checks whether the user already has access before recommending a purchase or subscription. Also lets the agent confirm subscription status when asked.
- **Changes needed:**
  - Change to `global static`
  - `AccessInfo` inner class must also be `global`
  - Wrap output in an `@InvocableVariable`-annotated class (Agentforce can't return custom inner classes directly — needs a flat output class)

---

### 4. `hasVideoAccess(Id videoId)`
- **Returns:** `Boolean`
- **Current:** `@AuraEnabled(cacheable=false)`, `public static`
- **Agent use:** Narrower version of `getMyAccess` — useful if agent only needs to check one specific video. May be redundant once `getMyAccess` is available.
- **Changes needed:** Same pattern — `global static`, invocable wrapper. Input class needs a field for `videoId`.

---

### 5. `purchaseVideo(Id videoId)`
- **Returns:** `void`
- **Current:** `@AuraEnabled(cacheable=false)`, `public static`
- **Agent use:** Core transaction action — agent completes a one-time purchase after the user confirms. Should fire LMS to unlock the player (currently that happens client-side; agent path may need a confirmation message instead).
- **Changes needed:**
  - Change to `global static`
  - Return a result string (e.g., `'Success'` or error message) instead of `void` — Agentforce needs output to confirm what happened
  - Input class needs `videoId` field

---

### 6. `createSubscription(String plan)`
- **Returns:** `void`
- **Current:** `@AuraEnabled(cacheable=false)`, `public static`
- **Agent use:** Core transaction action — agent subscribes the user. Valid values for `plan`: `'Monthly'` (→ $9.99/mo, +1 month end date) or `'Annual'` (→ $79.99/yr, +1 year end date).
- **Changes needed:**
  - Change to `global static`
  - Return a result string confirming plan and end date
  - Input class needs `plan` field

---

### 7. `resetDemo()`
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

## Summary of Code Changes Required

### 1. Change class visibility
```apex
// Before
public without sharing class GuitarVideoController {

// After
global without sharing class GuitarVideoController {
```

### 2. Change method visibility
All agent-facing methods: `public static` → `global static`

Methods to change: `getVideos`, `getFeaturedVideos`, `getMyAccess`, `hasVideoAccess`, `purchaseVideo`, `createSubscription`

Leave `resetDemo` as `public` — do not expose to agent.

### 3. Make AccessInfo global
```apex
// Before
public class AccessInfo {

// After
global class AccessInfo {
```

### 4. Return meaningful values from void methods
`purchaseVideo` and `createSubscription` currently return `void`. Agent Actions work better with a return value so the agent can confirm what happened:
```apex
// Example
global static String purchaseVideo(Id videoId) {
    // ... existing logic ...
    return 'Success: purchased ' + video.Name;
}
```

No need to split into separate classes — all methods stay in `GuitarVideoController`.

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
   - *Browse Catalog* → `getVideos`, `getFeaturedVideos`
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
