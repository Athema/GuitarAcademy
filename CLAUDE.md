# Guitar Academy — Claude Code Context

## What We're Building
A Salesforce B2C demo called **Guitar Academy**: an Experience Cloud (LWR) community where students browse guitar lesson videos, purchase individual videos or subscribe for full access, and chat with an **Agentforce** AI agent that knows the lesson content.

Inspired by: https://www.youtube.com/watch?v=UlM8pilzqig

---

## Salesforce Org

| Field | Value |
|---|---|
| Alias | `GuitarAcademy` |
| Username | `guitar@academy.com` |
| Type | Developer org (treated as sandbox for MCP URLs) |

### Deploying to the org
Always use **PowerShell** (not Bash) and set the SSL workaround:
```powershell
$env:NODE_TLS_REJECT_UNAUTHORIZED=0; sf project deploy start --source-dir force-app --target-org GuitarAcademy
```

### Querying the org
```powershell
$env:NODE_TLS_REJECT_UNAUTHORIZED=0; sf data query --query "SELECT ..." --target-org GuitarAcademy
```

---

## Data Model (deployed)

### Guitar_Video__c
Represents a guitar lesson video in the catalog.
- `YouTube_ID__c` (Text 20, required, unique) — used to build thumbnail URL automatically
- `Thumbnail_URL__c` (Formula) — auto-built from YouTube_ID__c
- `Price__c` (Currency), `Level__c` (Picklist: Beginner/Intermediate/Advanced)
- `Category__c` (Picklist), `Is_Free_Preview__c` (Checkbox), `Duration_Minutes__c`, `Description__c`
- sharingModel: ReadWrite

### Subscription__c
Tracks a student's subscription (monthly or annual).
- `Contact__c` (Master-Detail → Contact, required) — sharingModel: ControlledByParent
- `Plan__c` (Picklist: Monthly $9.99 / Annual $79.99, required)
- `Status__c` (Picklist: Active/Expired/Cancelled, required)
- `Start_Date__c` (default: TODAY()), `End_Date__c`

### Video_Purchase__c
Records an individual video purchase.
- `Contact__c` (Master-Detail → Contact, required) — sharingModel: ControlledByParent
- `Video__c` (Lookup → Guitar_Video__c, required, deleteConstraint: Restrict)
- `Amount_Paid__c` (Currency), `Purchase_Date__c` (default: TODAY())

---

## User Registration Architecture

**Pattern: Bucket Account (B2C)**
- One Account record: `"Guitar Academy Students"` — all self-registered Contacts attach to it
- No Person Accounts (can't be disabled once enabled — too risky for a demo org)
- License: **Customer Community** (5 available, 0 used)

**Self-registration flow:**
1. Student fills out registration form on the Experience Cloud site
2. `GuitarAcademyRegistration.selfRegister()` runs:
   - Creates Contact attached to bucket account
   - Creates Customer Community User
3. `assignPermissionSet()` runs async (`@future`):
   - Assigns `Guitar_Academy_Student` permission set

**Permission set — Guitar_Academy_Student:**
- Read: Contact, Guitar_Video__c
- Create/Read: Video_Purchase__c
- Create/Read/Edit: Subscription__c

---

## Experience Cloud Site
- Template: **LWR (Build Your Own)**
- Name: `Guitar Academy`
- URL: `guitaracademy`
- Self-registration handler: `GuitarAcademyRegistration` (must be set in Site Administration → Registration)

---

## Salesforce MCP Server
Connected app: **Guitar Academy MCP** (Consumer Key in `.env`)
- Server URL: `https://api.salesforce.com/platform/mcp/v1/sandbox/sobject-all`
- Config: `.mcp.json` in project root
- Auth: OAuth 2.0 with PKCE (no client secret needed)
- On first use: Claude Code triggers browser OAuth flow to authenticate

---

## What's Been Built

| Component | Status |
|---|---|
| Custom objects (Guitar_Video__c, Subscription__c, Video_Purchase__c) | Deployed |
| Self-registration Apex class (GuitarAcademyRegistration) | Deployed |
| Guitar_Academy_Student permission set | Deployed |
| Experience Cloud LWR site | Created in org (not yet configured) |
| Salesforce MCP server | Configured in .mcp.json |

---

## What's Next

1. **Connect self-registration handler** to the Experience Cloud site in Setup → Digital Experiences → Guitar Academy → Administration → Registration → set Self-Registration class to `GuitarAcademyRegistration`
2. **Build LWCs:**
   - `guitarVideoCard` — thumbnail, title, level, price, buy button
   - `guitarVideoCatalog` — grid of video cards, filterable by level/category
   - `guitarVideoPlayer` — embedded YouTube player + purchase/subscribe gate
3. **Agentforce agent** — knowledge source from guitar lesson scripts, wired into the community
4. **Test data** — load sample Guitar_Video__c records

---

## Git Workflow
- `main` — stable, demo-ready
- `develop` — active development, merge to main when ready to demo
- Always work on `develop` or feature branches, never commit directly to `main`

---

## Key Files

| File | Purpose |
|---|---|
| `force-app/main/default/classes/GuitarAcademyRegistration.cls` | Self-registration handler |
| `force-app/main/default/permissionsets/Guitar_Academy_Student.permissionset-meta.xml` | Student permissions |
| `force-app/main/default/objects/` | All custom object definitions |
| `.mcp.json` | Salesforce MCP server config |
| `.env` | Consumer Key + Secret (gitignored) |
