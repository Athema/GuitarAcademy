# Run this when the Salesforce MCP stops working (token expires ~2 hrs).
# Usage: Right-click in Explorer > Run with PowerShell  (or run in VS Code terminal)

Write-Host "Starting Salesforce MCP OAuth flow..." -ForegroundColor Cyan
Write-Host "(A browser will open - log in as guitar@academy.com and authorize)" -ForegroundColor Yellow
Write-Host ""

$env:NODE_TLS_REJECT_UNAUTHORIZED = "0"
node "$PSScriptRoot\Get-MCPToken.js"
