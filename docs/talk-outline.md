# Guitar Academy — Talk Outline

A Next-Gen Agentforce Assistant That Lives in the Page.
Audience: non-developer-heavy. Focus: NGA vs. legacy Agentforce + the page⇄agent intercommunication.
Copy-paste each slide into your base layout. Code blocks are real, condensed Guitar Academy code.
Adapted from Andrés Pérez's (@ELTOROit) Agentforce Next Gen / ETMS deck.

---

## SLIDE 1 — Title
Guitar Academy
A Next-Gen Agentforce Assistant That Lives in the Page
[Your name] — Senior Coach & Consultant · [date]
[photo of you playing guitar, beside the byline — caption: "aspiring guitar player"]
Built on the pattern shared by Andrés Pérez (@ELTOROit), ETMS

---

## SLIDE 2 — Agenda
- What is Agentforce Next Gen?
- How a next-gen agent is organized
- The magic: the assistant ⇄ the page
- Guitar Academy: demo + under the hood

---

## SLIDE 3 — What is Agentforce Next Gen?
- The new way to build Agentforce agents
- Authoring: Agent Script + Agentforce Builder (Beta)
- Runtime: Atlas Reasoning Engine + Agent Graph (GA)

Speaker note: You describe the agent as a structured recipe; Salesforce runs it reliably — instead of hoping one big prompt behaves.

---

## SLIDE 4 — Why a New Agentforce?
"Legacy" Agentforce
- ✕ Unpredictable
- ✕ Hard to maintain
- ✕ No enforceable rules
- ✕ No guaranteed flow

Agentforce Next Gen
- ✓ Predictable flow
- ✓ Guardrails & safety
- ✓ Controls the actions
- ✓ Enterprise-grade behavior

Bottom line: predictable, context-aware agents that don't rely only on the LLM's interpretation.

---

## SLIDE 5 — How a Next-Gen Agent Is Organized
- Think of the agent as a team of specialists, not one big brain
- A router greets you and sends you to the right specialist: browse · buy · subscribe · talk to a human
- Each specialist has one job and clear rules

Speaker note: This is the "topics + topic selector" idea, in plain language.

---

## SLIDE 6 — The Rule That Makes It Safe
- Every action carries a condition — e.g. the assistant can buy a lesson only when you're on that lesson's page
- If the moment isn't right, it tells you what to do
- It never fakes a confirmation
- These checks run as before- and after-reasoning steps — the agent gathers your context *before* it thinks, and confirms the result *after* it acts, so the rule is enforced by the framework, not left to the LLM

Speaker note: This is the difference between a demo that impresses and one that embarrasses you live.

---

## SLIDE 7 — The Big Idea: The Assistant Lives Inside the Experience
- It knows what you're looking at
- It can act on the page for you
- The page updates live in response

"Most chatbots talk. This one does."

---

## SLIDE 8 — Two-Way Communication
```
   YOU (the page)   ⇄   THE ASSISTANT
   "I'm on the Blues lesson"  →  it knows your context
   "filter to beginner"       →  catalog re-filters, live
   "buy this" / "subscribe"   →  it acts; the lesson unlocks
```
- Inbound: the page tells the agent where you are
- Outbound: the agent tells the page what it did

---

## SLIDE 9 — TO the Agent (the page → agent)
The page captures the conversation and tells the agent your context:
```javascript
// guitarPageTracker.js
window.addEventListener('onEmbeddedMessagingConversationOpened',
  e => this._conversationId = e.detail?.conversationId);

@wire(CurrentPageReference)
handlePageChange(ref) {
  updateContactPage({ pageName, sessionKey: this._conversationId, videoId });
}
```
Apex writes it onto the Messaging Session:
```apex
// GuitarVideoController.updateContactPage
MessagingSession ms = [SELECT Id FROM MessagingSession
  WHERE Conversation.ConversationIdentifier = :sessionKey LIMIT 1];
ms.Current_Page__c       = pageName;          // 'catalog' or 'video'
ms.Current_Video_Id__c   = videoId;
ms.Current_Contact_Id__c = getContactId();    // the logged-in student
update ms;
```
The agent reads it live, every message:
```
before_reasoning → get_page_context(routableId = @variables.RoutableId)
   currentPage = "video"  ⇒  "buy this lesson" becomes available
```

---

## SLIDE 10 — FROM the Agent (agent → page)
When the agent acts, it stamps the result on the Messaging Session:
```apex
// GuitarPurchaseController — after a successful purchase
MessagingSession ms = new MessagingSession(Id = routableId);
ms.Action__c     = 'PURCHASE';
ms.ActionJSON__c = JSON.serialize(new Map<String,Object>{ 'videoId' => videoId });
update ms;
```
The page reacts on the agent's reply — no polling:
```javascript
// guitarVideoPlayer.js
window.addEventListener('onEmbeddedMessageSent', () => {
  getAgentAction({ conversationId }).then(res => {
    if (res.action === 'PURCHASE' && res.actionVideoId === this.recordId) {
      this.hasAccess = true;   // unlock the full lesson, live on screen
    }
  });
});
```

---

## SLIDE 11 — Continuity: Handing Off to a Human
- Need a person? The assistant transfers to a live agent (Omnichannel)
- The conversation arrives already tied to the right customer — full history
- No "please repeat everything you told the bot"

Speaker note: We link the messaging session to the Contact on the first message, so the human sees who they're helping.

---

## SLIDE 12 — Guitar Academy: What It Does
- Browse guitar lesson videos — the assistant knows which one you're viewing
- Buy a lesson, or subscribe (monthly / annual)
- After buying: the preview unlocks to the full lesson, live on screen
- Filter the catalog by skill level or category, by chat

---

## SLIDE 13 — Architecture (Guitar Academy)
One Salesforce org. Everything on-platform.
```
        EXPERIENCE CLOUD COMMUNITY  (single Salesforce org)
   ┌──────────────────────────────────────────────────────┐
   │  Browser                                               │
   │   • Lesson pages + LWCs (catalog · player · featured)  │
   │   • Embedded Messaging (MIAW) chat widget              │
   │                    │  ▲                                │
   │         @AuraEnabled│  │                               │
   │                    ▼  │                                │
   │   • Apex controllers (videos · purchase · subscribe)   │
   │                    │  ▲                                │
   │           read/write│  │                               │
   │                    ▼  │                                │
   │   • MessagingSession  ──  the shared context           │
   │       page · video · contact · action                  │
   │                    ▲  │                                │
   │      each message  │  ▼                                │
   │   • Guitar Academy Assistant  (Agentforce Next Gen)    │
   │                                                        │
   │   • Data: Guitar_Video__c · Subscription__c ·          │
   │           Video_Purchase__c · Contact                  │
   └───────────────┬──────────────────────────┬────────────┘
                   │                          │
                   ▼                          ▼
          YouTube (lesson video)     Omnichannel → live human agent
```
- Front end: Experience Cloud LWR community — catalog, player, and embedded chat, all native
- Brain: the Guitar Academy Assistant (Agentforce Next Gen), in the same org
- Shared context: the Messaging Session is the single place the page and the agent meet — page, video, contact, actions
- Apex does the work (browse, buy, subscribe) and keeps the session in sync
- Hand-off: Omnichannel routes to a live human, conversation already tied to the Contact
- External: YouTube for the lesson videos

Speaker note: "No external web server, no second org — the storefront, the AI, and the data all live in one Salesforce org."

---

## SLIDE 14 — (Optional) Under the Hood: Built for Many Customers at Once
- Each conversation keeps its own context — two customers chatting at the same time never cross wires
- State lives per-conversation on the Messaging Session, not in one shared global

Speaker note: Cut for a pure-business room; keep as backup for technical Q&A.

---

## SLIDE 15 — Why It Matters
- Trust — acts only in the right context
- Speed — actions happen live, in the page
- Maintainable — behavior is explicit, reviewable, versioned
- Seamless — AI and humans share one identified conversation

---

## SLIDE 16 — Demo
(black slide)

---

## SLIDE 17 — Thank You
[Your name / handles]
Thanks to Andrés Pérez (@ELTOROit) for the ETMS pattern that inspired this build
