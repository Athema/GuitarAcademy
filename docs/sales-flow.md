# Guitar Academy — Sales Flow Diagrams

Reference for Agentforce topic design, system prompt, and action wiring.

---

## 1. User Registration & Login

```mermaid
flowchart TD
    A([User visits site]) --> B{Has account?}

    B -- No --> C[Self-registration form\nname · email · password]
    C --> D[GuitarAcademyRegistration.selfRegister\nCreates Contact + Community User\nattached to Guitar Academy Students account]
    D --> E[UserRegistrationTrigger fires\nassigns Guitar_Academy_Student permission set]
    E --> F([Logged in — Home Page])

    B -- Yes --> G[Login page]
    G --> F
```

---

## 2. Browsing & Discovery

```mermaid
flowchart TD
    F([Home Page]) --> ACC[getMyAccess\nisSubscribed · purchasedVideoIds · subscriptionEndDate]

    ACC --> H[Featured Lessons section\n3 highlighted videos]
    ACC --> BADGE{Has active subscription?}
    BADGE -- Yes --> SB[Subscribed until date\nbadge shown next to section title\nall cards show ✓ Owned]
    BADGE -- No --> OB[Per-video: ✓ Owned badge\nif Id in purchasedVideoIds]

    H --> J[Click video card]

    F --> I[Catalog page\nall videos with Level + Category filters]
    I --> ACC2[getMyAccess\nsame check on catalog load]
    ACC2 --> I2[Cards render with isOwned flag\nsubscription badge in header if subscribed]
    I2 --> J

    J --> K([Video Player Page])
```

---

## 3. Video Access & Purchase Flow

```mermaid
flowchart TD
    K([Video Player Page]) --> L{User has access?}

    L -- Yes\npurchased or subscribed --> M([Full video plays\nno restrictions])

    L -- No --> N[Preview plays — 20 seconds\nend=20 YouTube param]
    N --> O{Timer fires\nor user seeks past 20s}
    O --> P[Overlay appears\niframe blanked — audio stops]

    P --> Q{User action?}
    Q -- Replay Preview --> N
    Q -- Get Access ▾ --> R[Access panel unfolds\nDirect_Purchase_Enabled = true]

    R --> S{Purchase choice}

    S -- Buy once --> T[purchaseVideo Apex\ncreates Video_Purchase__c\nAmount_Paid = Price__c]
    S -- Monthly $9.99 --> U[createSubscription Monthly\ncreates Subscription__c\nEnd_Date = today + 1 month]
    S -- Annual $79.99 --> V[createSubscription Annual\ncreates Subscription__c\nEnd_Date = today + 1 year]

    T --> W[LMS publishes GuitarAcademyAccess\nplayer unlocks immediately]
    U --> W
    V --> W

    W --> M
```

---

## 4. Access State Summary

```mermaid
flowchart LR
    subgraph States
        A[No access] -->|purchaseVideo| B[Video purchased\nVideo_Purchase__c]
        A -->|createSubscription| C[Subscribed\nSubscription__c Active]
        B -->|hasVideoAccess = true| D([Full playback])
        C -->|hasVideoAccess = true\nfor ALL videos| D
    end

    subgraph Catalog indicators
        B --> E[✓ Owned badge\non that card]
        C --> F[✓ Owned badge\non ALL cards\n+ Subscribed until date\nin section header]
    end
```

---

## 5. Agentforce Conversation Flow

```mermaid
flowchart TD
    AG([User opens chat]) --> GR[Agent greets user\nchecks getMyAccess]

    GR --> INT{User intent}

    INT -- Browse lessons --> BR[getVideos\nfilter by level or category]
    BR --> REC[Agent describes matching lessons\nwith price and level]
    REC --> INT

    INT -- What do I have access to? --> ACC[getMyAccess\nreturns isSubscribed\npurchasedVideoIds\nsubscriptionEndDate]
    ACC --> AREP[Agent reports:\nsubscription status + expiry\nlist of owned videos]
    AREP --> INT

    INT -- Buy a specific lesson --> CHK[getMyAccess\nor hasVideoAccess]
    CHK --> OWNS{Already owns it?}
    OWNS -- Yes --> CONF[Agent confirms access\nno charge needed]
    OWNS -- No --> PROP[Agent proposes purchase\nstates price]
    PROP --> UCONF{User confirms?}
    UCONF -- Yes --> PUR[purchaseVideo\nreturns confirmation string]
    PUR --> PCONF[Agent confirms purchase\ntells user to refresh player]
    UCONF -- No --> ALT[Agent offers subscription\nas better value]
    ALT --> INT

    INT -- Subscribe --> PLAN[Agent explains plans:\nMonthly $9.99 · Annual $79.99\nhighlights annual saving]
    PLAN --> PSEL{User picks plan?}
    PSEL -- Monthly --> SM[createSubscription Monthly\nEnd_Date = today + 1 month]
    PSEL -- Annual --> SA[createSubscription Annual\nEnd_Date = today + 1 year]
    SM --> SCONF[Agent confirms plan + expiry date\ntells user all lessons are now unlocked]
    SA --> SCONF
    SCONF --> INT

    INT -- Something else --> FB[Agent uses Knowledge\nto answer questions about\nlesson content technique theory etc]
    FB --> INT
```

---

## 6. Data Created Per Action

| User action | Apex method | Record created | Effect on UI |
|---|---|---|---|
| Buys a video | `purchaseVideo` | `Video_Purchase__c` | ✓ Owned on that card, player unlocks |
| Subscribes monthly | `createSubscription('Monthly')` | `Subscription__c` Active, End +1mo | ✓ Owned on all cards, header badge |
| Subscribes annually | `createSubscription('Annual')` | `Subscription__c` Active, End +1yr | same as above |
| Agent checks access | `getMyAccess` | — | informs agent response |
| Agent checks one video | `hasVideoAccess` | — | informs agent response |

---

## 7. Key Business Rules

- A user can only have **one active subscription** — `createSubscription` cancels any existing Active record before inserting the new one.
- A video purchase is **idempotent** — calling `purchaseVideo` twice for the same video does nothing the second time.
- Subscription grants access to **all videos** regardless of individual purchase history.
- The `Direct_Purchase_Enabled` custom label (`true`/`false`) gates the entire purchase UI — set to `false` to force all transactions through the agent.
- Preview is always **20 seconds** (`PREVIEW_SECONDS` constant in `guitarVideoPlayer.js`), enforced both by YouTube's `end=` param and by blanking the iframe when the JS timer fires.
