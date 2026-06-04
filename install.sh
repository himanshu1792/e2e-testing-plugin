#!/usr/bin/env bash
# E2E Testing Framework for GitHub Copilot — Installer (macOS / Linux)
# Copies agents, instructions, and prompts into ~/.copilot/
# Then prints next-step instructions for MCP config and environment variables.

set -euo pipefail

COPILOT_DIR="$HOME/.copilot"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors (fall back to no-op if not a TTY)
if [ -t 1 ]; then
  CYAN='\033[0;36m'
  YELLOW='\033[1;33m'
  GREEN='\033[0;32m'
  GRAY='\033[0;90m'
  RED='\033[0;31m'
  RESET='\033[0m'
else
  CYAN=''; YELLOW=''; GREEN=''; GRAY=''; RED=''; RESET=''
fi

echo ""
echo -e "${CYAN}===================================================================${RESET}"
echo -e "${CYAN} E2E Testing Framework for GitHub Copilot — Installer (Unix)${RESET}"
echo -e "${CYAN}===================================================================${RESET}"
echo ""
echo "Target directory: $COPILOT_DIR"
echo ""

# 1) Verify source folders exist
for sub in agents instructions prompts; do
  if [ ! -d "$SCRIPT_DIR/$sub" ]; then
    echo -e "${RED}ERROR: Expected source folder not found: $SCRIPT_DIR/$sub${RESET}"
    echo "Run this installer from the framework repo root."
    exit 1
  fi
done

# 2) Create target directories
echo "[1/5] Creating target directories..."
for sub in agents instructions prompts; do
  path="$COPILOT_DIR/$sub"
  if [ ! -d "$path" ]; then
    mkdir -p "$path"
    echo "  created: $path"
  else
    echo "  exists:  $path"
  fi
done

# 3) Copy agent files
echo ""
echo "[2/5] Copying agent definitions..."
for f in "$SCRIPT_DIR/agents/"*.agent.md; do
  [ -e "$f" ] || continue
  name="$(basename "$f")"
  cp -f "$f" "$COPILOT_DIR/agents/$name"
  echo "  $name -> $COPILOT_DIR/agents/$name"
done

# 4) Copy instruction files
echo ""
echo "[3/5] Copying instruction files..."
for f in "$SCRIPT_DIR/instructions/"*.instructions.md; do
  [ -e "$f" ] || continue
  name="$(basename "$f")"
  cp -f "$f" "$COPILOT_DIR/instructions/$name"
  echo "  $name -> $COPILOT_DIR/instructions/$name"
done

# 5) Copy prompt files
echo ""
echo "[4/5] Copying prompt files..."
for f in "$SCRIPT_DIR/prompts/"*.prompt.md; do
  [ -e "$f" ] || continue
  name="$(basename "$f")"
  cp -f "$f" "$COPILOT_DIR/prompts/$name"
  echo "  $name -> $COPILOT_DIR/prompts/$name"
done

echo ""
echo -e "${GREEN}[5/5] Installation complete.${RESET}"
echo ""

# 6) Next-step guidance
echo -e "${CYAN}===================================================================${RESET}"
echo -e "${CYAN} Next steps${RESET}"
echo -e "${CYAN}===================================================================${RESET}"
echo ""
echo -e "${YELLOW}STEP A — Set environment variables (one-time per machine)${RESET}"
echo ""
echo "Add these to your shell rc (~/.bashrc, ~/.zshrc, or equivalent):"
echo ""
echo -e "${GRAY}  export JIRA_URL=\"https://yourcompany.atlassian.net\"${RESET}"
echo -e "${GRAY}  export JIRA_PAT=\"your-jira-personal-access-token\"${RESET}"
echo -e "${GRAY}  export ADO_ORG=\"your-ado-org-name\"${RESET}"
echo -e "${GRAY}  export ADO_PAT=\"your-azure-devops-pat\"${RESET}"
echo ""
echo "  Then reload: source ~/.bashrc   (or ~/.zshrc)"
echo ""

echo -e "${YELLOW}STEP B — Install MCP prerequisites${RESET}"
echo ""
echo "  Node.js + npm must be installed (https://nodejs.org/)."
echo "  Optional: install uv for the Jira MCP server (https://docs.astral.sh/uv/)"
echo ""

echo -e "${YELLOW}STEP C — Register MCP servers in VS Code (one-time per machine)${RESET}"
echo ""
echo "  1. Open VS Code"
echo "  2. Cmd/Ctrl+Shift+P -> 'MCP: Open User Configuration'"
echo "  3. Paste the contents of:"
echo "       $SCRIPT_DIR/mcp.user.json"
echo "     (Omit the '_comment' line. Merge into your existing 'servers' if any.)"
echo "  4. Save and restart VS Code."
echo ""

echo -e "${YELLOW}STEP D — Per-project setup (in each Playwright project you want to test)${RESET}"
echo ""
echo "  Add a .env at the project root:"
echo ""
echo -e "${GRAY}    APP_URL=https://your-staging-app.example.com${RESET}"
echo -e "${GRAY}    TEST_USERNAME=qa-automation@example.com${RESET}"
echo -e "${GRAY}    TEST_PASSWORD=********${RESET}"
echo ""
echo "  Make sure your playwright.config.ts loads dotenv:"
echo -e "${GRAY}    import 'dotenv/config';${RESET}"
echo ""

echo -e "${YELLOW}STEP E — Use the framework${RESET}"
echo ""
echo "  Open any Playwright project in VS Code, then in Copilot Chat:"
echo ""
echo "    /e2e-testing https://yourcompany.atlassian.net/browse/PROJ-123"
echo ""
echo "  or with extra context:"
echo ""
echo '    /e2e-testing https://dev.azure.com/org/proj/_workitems/edit/4567 --additionalComments "test mobile too"'
echo ""
echo -e "${CYAN}===================================================================${RESET}"
echo " See README.md for the full setup guide and troubleshooting."
echo -e "${CYAN}===================================================================${RESET}"
echo ""
