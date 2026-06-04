# E2E Testing Framework for GitHub Copilot — Windows Installer
# Copies agents, instructions, and prompts into %USERPROFILE%\.copilot\
# Then prints next-step instructions for MCP config and environment variables.

$ErrorActionPreference = 'Stop'

$CopilotDir = Join-Path $env:USERPROFILE '.copilot'
$ScriptDir = $PSScriptRoot

Write-Host ""
Write-Host "===================================================================" -ForegroundColor Cyan
Write-Host " E2E Testing Framework for GitHub Copilot — Installer (Windows)" -ForegroundColor Cyan
Write-Host "===================================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Target directory: $CopilotDir"
Write-Host ""

# 1) Verify source folders exist
foreach ($sub in @('agents', 'instructions', 'prompts')) {
    $source = Join-Path $ScriptDir $sub
    if (-not (Test-Path $source)) {
        Write-Host "ERROR: Expected source folder not found: $source" -ForegroundColor Red
        Write-Host "Run this installer from the framework repo root."
        exit 1
    }
}

# 2) Create target directories
Write-Host "[1/5] Creating target directories..."
foreach ($sub in @('agents', 'instructions', 'prompts')) {
    $path = Join-Path $CopilotDir $sub
    if (-not (Test-Path $path)) {
        New-Item -ItemType Directory -Path $path -Force | Out-Null
        Write-Host "  created: $path"
    } else {
        Write-Host "  exists:  $path"
    }
}

# 3) Copy agent files
Write-Host ""
Write-Host "[2/5] Copying agent definitions..."
$agentFiles = Get-ChildItem -Path (Join-Path $ScriptDir 'agents') -Filter '*.agent.md'
foreach ($f in $agentFiles) {
    $dest = Join-Path $CopilotDir 'agents' $f.Name
    Copy-Item -Path $f.FullName -Destination $dest -Force
    Write-Host "  $($f.Name) -> $dest"
}

# 4) Copy instruction files
Write-Host ""
Write-Host "[3/5] Copying instruction files..."
$instrFiles = Get-ChildItem -Path (Join-Path $ScriptDir 'instructions') -Filter '*.instructions.md'
foreach ($f in $instrFiles) {
    $dest = Join-Path $CopilotDir 'instructions' $f.Name
    Copy-Item -Path $f.FullName -Destination $dest -Force
    Write-Host "  $($f.Name) -> $dest"
}

# 5) Copy prompt files
Write-Host ""
Write-Host "[4/5] Copying prompt files..."
$promptFiles = Get-ChildItem -Path (Join-Path $ScriptDir 'prompts') -Filter '*.prompt.md'
foreach ($f in $promptFiles) {
    $dest = Join-Path $CopilotDir 'prompts' $f.Name
    Copy-Item -Path $f.FullName -Destination $dest -Force
    Write-Host "  $($f.Name) -> $dest"
}

Write-Host ""
Write-Host "[5/5] Installation complete." -ForegroundColor Green
Write-Host ""

# 6) Next-step guidance
Write-Host "===================================================================" -ForegroundColor Cyan
Write-Host " Next steps" -ForegroundColor Cyan
Write-Host "===================================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "STEP A — Set environment variables (one-time per machine)" -ForegroundColor Yellow
Write-Host ""
Write-Host "Run these in PowerShell (replace the placeholder values):"
Write-Host ""
Write-Host '  [Environment]::SetEnvironmentVariable("JIRA_URL", "https://yourcompany.atlassian.net", "User")' -ForegroundColor Gray
Write-Host '  [Environment]::SetEnvironmentVariable("JIRA_PAT", "your-jira-personal-access-token", "User")' -ForegroundColor Gray
Write-Host '  [Environment]::SetEnvironmentVariable("ADO_ORG", "your-ado-org-name",                "User")' -ForegroundColor Gray
Write-Host '  [Environment]::SetEnvironmentVariable("ADO_PAT", "your-azure-devops-pat",            "User")' -ForegroundColor Gray
Write-Host ""
Write-Host "  Then RESTART your terminal so the new env vars are visible." -ForegroundColor DarkGray
Write-Host ""

Write-Host "STEP B — Install Playwright MCP prerequisites" -ForegroundColor Yellow
Write-Host ""
Write-Host "  Node.js + npm must be installed (https://nodejs.org/)."
Write-Host "  Optional: install uv for the Jira MCP server (https://docs.astral.sh/uv/)"
Write-Host ""

Write-Host "STEP C — Register MCP servers in VS Code (one-time per machine)" -ForegroundColor Yellow
Write-Host ""
Write-Host "  1. Open VS Code"
Write-Host "  2. Ctrl+Shift+P -> 'MCP: Open User Configuration'"
Write-Host "  3. Paste the contents of:" -NoNewline
Write-Host "  $ScriptDir\mcp.user.json" -ForegroundColor White
Write-Host "     (Omit the '_comment' line. Merge into your existing 'servers' if any.)"
Write-Host "  4. Save and restart VS Code."
Write-Host ""

Write-Host "STEP D — Per-project setup (in each Playwright project you want to test)" -ForegroundColor Yellow
Write-Host ""
Write-Host "  Install dependencies + browser binaries (the Script Writer also does this for you):"
Write-Host ""
Write-Host "    npm install --save-dev @playwright/test dotenv" -ForegroundColor Gray
Write-Host "    npx playwright install chromium"                 -ForegroundColor Gray
Write-Host ""
Write-Host "  Add a .env at the project root:"
Write-Host ""
Write-Host "    APP_URL=https://your-staging-app.example.com" -ForegroundColor Gray
Write-Host "    TEST_USERNAME=qa-automation@example.com"     -ForegroundColor Gray
Write-Host "    TEST_PASSWORD=********"                       -ForegroundColor Gray
Write-Host ""
Write-Host "  Make sure your playwright.config.ts loads dotenv and runs headless:"
Write-Host "    import 'dotenv/config';" -ForegroundColor Gray
Write-Host "    use: { baseURL: process.env.APP_URL, headless: true }" -ForegroundColor Gray
Write-Host ""
Write-Host "  (Script Writer authors live in a headed MCP browser; Reviewer runs specs headless.)" -ForegroundColor DarkGray
Write-Host ""

Write-Host "STEP E — Use the framework" -ForegroundColor Yellow
Write-Host ""
Write-Host "  Open any Playwright project in VS Code, then in Copilot Chat:"
Write-Host ""
Write-Host "    /e2e-testing https://yourcompany.atlassian.net/browse/PROJ-123" -ForegroundColor White
Write-Host ""
Write-Host "  or with extra context:"
Write-Host ""
Write-Host '    /e2e-testing https://dev.azure.com/org/proj/_workitems/edit/4567 --additionalComments "test mobile too"' -ForegroundColor White
Write-Host ""
Write-Host "===================================================================" -ForegroundColor Cyan
Write-Host " See README.md for the full setup guide and troubleshooting."
Write-Host "===================================================================" -ForegroundColor Cyan
Write-Host ""
