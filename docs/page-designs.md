# Guitar Academy — Page Designs

## Home Page

```
┌─────────────────────────────────────────────────────────┐
│ [Site nav — Guitar Academy | Catalog | avatar]          │  ← site-level
├─────────────────────────────────────────────────────────┤
│                                                         │
│  🎸 GUITAR ACADEMY                                      │  ← guitarAcademyHeader ✅
│  Learn Guitar. At Your Own Pace.                        │
│  Stream lessons from beginner to advanced...            │
│                                                         │
├─────────────────────────────────────────────────────────┤
│  Featured Lessons                     [Browse All →]    │  ← guitarFeaturedLessons (TODO)
│  ┌──────────┐  ┌──────────┐  ┌──────────┐             │
│  │ [thumb]  │  │ [thumb]  │  │ [thumb]  │             │
│  │ Beginner │  │ Beginner │  │ Beginner │             │
│  │  Title   │  │  Title   │  │  Title   │             │
│  │ $4.99    │  │ $4.99    │  │ $4.99    │             │
│  └──────────┘  └──────────┘  └──────────┘             │
└─────────────────────────────────────────────────────────┘
```

**Components:**
- `guitarAcademyHeader` — hero with tagline (built ✅)
- `guitarFeaturedLessons` — 3 cards from `Is_Featured__c = true` videos + "Browse All →" link (TODO)

---

## Catalog Page

```
┌─────────────────────────────────────────────────────────┐
│ [Site nav]                                              │
├─────────────────────────────────────────────────────────┤
│  Guitar Lessons              Level ▾     Category ▾     │  ← guitarVideoCatalog ✅
│                                                         │
│  ┌──────┐ ┌──────┐ ┌──────┐ ┌──────┐ ┌──────┐        │
│  │thumb │ │thumb │ │thumb │ │thumb │ │thumb │        │
│  │[Beg] │ │[Int] │ │[Adv] │ │[Beg] │ │[Int] │        │
│  │Title │ │Title │ │Title │ │Title │ │Title │        │
│  │$4.99 │ │$9.99 │ │$9.99 │ │$4.99 │ │$9.99 │        │
│  └──────┘ └──────┘ └──────┘ └──────┘ └──────┘        │
│  ... 12 total                                           │
└─────────────────────────────────────────────────────────┘
```

**Components:**
- `guitarVideoCatalog` — filterable grid (built ✅)

---

## Video / Class Page (Guitar_Video__c record detail)

```
┌─────────────────────────────────────────────────────────┐
│ [Site nav]                                              │
├─────────────────────────────────────────────────────────┤
│  [Beginner]  Power Chords for Beginners                 │  ← guitarVideoPlayer ✅
│  Technique  •  8 min  •  $4.99                         │    (button rework TODO)
│                                                         │
│  ┌─────────────────────────────────────────────────┐   │
│  │                                                 │   │
│  │          [YouTube thumbnail / iframe]           │   │
│  │                                                 │   │
│  │   ── after 20s, no access ──                   │   │
│  │  ┌───────────────────────────────────────────┐ │   │
│  │  │  That's the preview!                      │ │   │
│  │  │  Talk to our assistant to purchase ($4.99)│ │   │
│  │  │           [▶ Replay Preview]              │ │   │
│  │  └───────────────────────────────────────────┘ │   │
│  └─────────────────────────────────────────────────┘   │
│                                                         │
│  [▶ Preview]   ← shown when user has no access         │
│  [▶ Play Full Lesson]  ← shown after purchase/sub      │
│                                                         │
│  About this lesson...                                   │
└─────────────────────────────────────────────────────────┘
```

**Components:**
- `guitarVideoPlayer` — wire getRecord, hasVideoAccess, LMS subscribe (built ✅)

**Player UX rules:**
- Page loads with iframe static (no autoplay on page open)
- User clicks **▶ Preview** → iframe loads with `?end=20`, 22s timer starts, overlay appears after
- After purchase/subscription via Agentforce (LMS message received) → button changes to **▶ Play Full Lesson**, full video plays, overlay dismissed
- **▶ Replay Preview** in overlay resets the iframe and restarts the timer

---

## TODO — What Still Needs Building

| Task | Details |
|---|---|
| `Is_Featured__c` checkbox | Add to Guitar_Video__c, mark 3 records in org |
| `guitarFeaturedLessons` LWC | 3-card grid querying `Is_Featured__c = true`, "Browse All →" navigates to /catalog |
| `guitarVideoPlayer` button rework | Add Preview/Play button below player; don't autoload iframe on connectedCallback |
| Agentforce agent | Knowledge source + Embedded Service chat on all pages |
| Experience Builder wiring | guitarFeaturedLessons on Home page; nav menu pointing to Catalog |
