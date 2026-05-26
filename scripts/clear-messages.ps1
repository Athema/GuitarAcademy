# clear-messages.ps1 -- wipe all MessagingSession + MessagingEndUser records from the org.
#
# WHY THIS SCRIPT EXISTS (the non-obvious part):
#   Single-record REST/SOAP delete of a MessagingEndUser fails with a useless
#   "UNKNOWN_EXCEPTION: An unexpected error occurred" -- and so does Database.delete in
#   execute-anonymous. The reason: deleting a MessagingEndUser cascades into its
#   ConversationParticipant rows, and BOTH Conversation and ConversationParticipant are
#   platform read-only (describe: deletable=False). Synchronous DML chokes on that cascade.
#   The Bulk API delete uses a different deletion path that handles it cleanly -- so we route
#   ALL deletes through the Bulk API. (MessagingSession deletes fine either way, but we use
#   bulk for both for consistency.)
#
# ORDER MATTERS: delete MessagingSession first, then MessagingEndUser (sessions reference users).
#
# Usage:  powershell -File scripts/clear-messages.ps1                 # org alias "GuitarAcademy"
#         powershell -File scripts/clear-messages.ps1 -TargetOrg X    # different org alias
param(
    [string]$TargetOrg = "GuitarAcademy"
)

$env:NODE_TLS_REJECT_UNAUTHORIZED = 0   # org SSL workaround (see CLAUDE.md)
$tmp = $env:TEMP

function Clear-MessagingObject([string]$obj) {
    $csv = Join-Path $tmp ("{0}_ids.csv" -f $obj)
    sf data query --query "SELECT Id FROM $obj" --target-org $TargetOrg --result-format csv |
        Out-File -FilePath $csv -Encoding ascii

    $ids = Get-Content $csv | Where-Object { $_ -and $_.Trim() -ne 'Id' }
    if (-not $ids -or $ids.Count -eq 0) {
        Write-Output "$obj : already empty - nothing to delete."
        return
    }

    Write-Output "$obj : deleting $($ids.Count) record(s) via Bulk API..."
    sf data delete bulk --sobject $obj --file $csv --target-org $TargetOrg --wait 10 --json | Out-Null

    $remaining = (sf data query --query "SELECT COUNT(Id) total FROM $obj" --target-org $TargetOrg --json |
        ConvertFrom-Json).result.records[0].total
    if ($remaining -eq 0) {
        Write-Output "$obj : cleared (0 remaining)."
    } else {
        Write-Output "$obj : WARNING - $remaining record(s) still remain."
    }
}

Write-Output "Clearing messaging data from org '$TargetOrg'..."
Clear-MessagingObject "MessagingSession"
Clear-MessagingObject "MessagingEndUser"
Write-Output "Done."
