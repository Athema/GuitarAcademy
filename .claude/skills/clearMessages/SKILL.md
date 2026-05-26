---
name: clearMessages
description: "Wipe all MessagingSession and MessagingEndUser records from the Guitar Academy Salesforce org. TRIGGER when: user types clearMessages; wants to clear/wipe/reset messaging sessions, messaging end users, chat sessions, or conversation test data before a demo or test run. DO NOT TRIGGER for: deleting Video_Purchase__c/Subscription__c demo state (that is scripts/reset-demo.apex), or any non-messaging data cleanup."
metadata:
  version: "1.0"
  last_updated: "2026-05-26"
---

# clearMessages — Wipe Messaging Test Data

Deletes all `MessagingSession` and `MessagingEndUser` records from the org so chat
test data doesn't accumulate between demo runs.

## The non-obvious gotcha (read before "fixing" a failure)

A **single-record** delete of a `MessagingEndUser` — whether via
`sf data delete record`, the REST/SOAP API, or `Database.delete` in execute-anonymous —
fails with a useless, generic error:

```
UNKNOWN_EXCEPTION: An unexpected error occurred. Please include this ErrorId ...
```

Root cause: deleting a `MessagingEndUser` cascades into its `ConversationParticipant`
rows, and **both `Conversation` and `ConversationParticipant` are platform read-only**
(`describe` → `deletable=False`). Synchronous DML cannot delete those children, so the
whole cascade throws. You cannot delete the Conversation/Participant records to "clear the
way" — there is no API path for them at all.

**The fix: route deletes through the Bulk API.** The Bulk API uses a different deletion
path that handles the read-only-child cascade cleanly. `MessagingSession` deletes fine
either way, but we bulk-delete both for consistency.

Order matters: **delete `MessagingSession` first, then `MessagingEndUser`** (sessions
reference users).

## How to run

The whole procedure is scripted. From the project root (this machine has Windows
PowerShell 5.1, not `pwsh`):

```powershell
powershell -ExecutionPolicy Bypass -File scripts/clear-messages.ps1                 # org alias "GuitarAcademy"
powershell -ExecutionPolicy Bypass -File scripts/clear-messages.ps1 -TargetOrg X    # different org alias
```

The script is idempotent — re-running on an already-empty org reports "already empty"
and does nothing. It is pure ASCII (no em-dashes/emoji) so Windows PowerShell 5.1 parses
it without BOM/encoding issues.

The script sets the `NODE_TLS_REJECT_UNAUTHORIZED=0` SSL workaround, queries IDs into a
CSV, bulk-deletes each object, and reports the remaining count (should be 0).

## Doing it by hand (if the script is unavailable)

Always PowerShell + SSL workaround. For each object (`MessagingSession`, then
`MessagingEndUser`):

```powershell
$env:NODE_TLS_REJECT_UNAUTHORIZED=0
sf data query --query "SELECT Id FROM MessagingEndUser" --target-org GuitarAcademy `
    --result-format csv | Out-File -FilePath "$env:TEMP\meu.csv" -Encoding ascii
sf data delete bulk --sobject MessagingEndUser --file "$env:TEMP\meu.csv" `
    --target-org GuitarAcademy --wait 10 --json
```

Verify:

```powershell
sf data query --query "SELECT COUNT(Id) total FROM MessagingSession"  --target-org GuitarAcademy --json
sf data query --query "SELECT COUNT(Id) total FROM MessagingEndUser"  --target-org GuitarAcademy --json
```

Both should report `total: 0`.

## What NOT to waste time on

- ❌ `sf data delete record` per ID for MessagingEndUser → `UNKNOWN_EXCEPTION`.
- ❌ `Database.delete` in execute-anonymous → same `UNKNOWN_EXCEPTION`.
- ❌ Deleting `Conversation` / `ConversationParticipant` first → `INSUFFICIENT_ACCESS_OR_READONLY` (they're not deletable, period).
- ❌ `--hard-delete` → needs the "Bulk API Hard Delete" system permission (off by default). Plain bulk delete works without it.
