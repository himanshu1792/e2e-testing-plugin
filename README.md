# E2E Testing Framework for GitHub Copilot

A multi-agent E2E test generation framework for **VS Code GitHub Copilot**. Installs to your user profile (`~/.copilot/`) once, then works in any Playwright project on your machine.

Type `/e2e-testing <jira-or-ado-story-url>` in Copilot Chat. Five specialist agents take it from story → scenarios → Playwright scripts → de-flaked specs → markdown report. Each phase ends with a single-click handoff button so you stay in control.

---

## Table of contents

1. [What it does](#what-it-does)
2. [Architecture](#architecture)
3. [Prerequisites](#prerequisites)
4. [Install](#install)
5. [Configure environment variables](#configure-environment-variables)
6. [Register MCP servers in VS Code](#register-mcp-servers-in-vs-code)
7. [Per-project setup](#per-project-setup)
8. [Usage](#usage)
9. [The five-phase workflow](#the-five-phase-workflow)
10. [Customization](#customization)
11. [Troubleshooting](#troubleshooting)
12. [Uninstall](#uninstall)

---

## What it does

You give it a Jira or Azure DevOps story URL. It:

1. Reads the story, extracts acceptance criteria, asks you clarifying questions.
2. Drafts test scenarios in chat, iterates with you until you approve.
3. Generates Playwright `.spec.ts` files using the Playwright MCP for live locator discovery.
4. Runs the generated specs, classifies failures, patches flaky tests up to 3 times.
5. Writes a markdown report of the run to `test-runs/<timestamp>/report.md`.

You stay in chat the whole time. Approvals are single button clicks.

---

## Architecture

Five specialist agents chained via Copilot **handoff buttons**:

```
/e2e-testing <story-url>
        │
        ▼
┌──────────────────┐    ┌──────────────────┐    ┌──────────────────┐
│  E2E Analyst     │ ─► │ E2E Scenario     │ ─► │ E2E Script       │ ─►
│  Reads story.    │    │ Writer           │    │ Writer           │
│  Reads .env.     │    │ Drafts scenarios │    │ Generates .spec  │
│  Asks Qs.        │    │ in chat. Loops   │    │ files via the    │
│                  │    │ until approved.  │    │ Playwright MCP.  │
└──────────────────┘    └──────────────────┘    └──────────────────┘

   ┌──────────────────┐    ┌──────────────────┐
─► │  E2E Reviewer    │ ─► │ E2E Report       │
   │  Runs specs.     │    │ Generator        │
   │  Classifies      │    │ Writes markdown  │
   │  failures.       │    │ report.          │
   │  De-flakes (≤3). │    │                  │
   └──────────────────┘    └──────────────────┘
```

Three MCP servers do the heavy lifting:

- **Playwright MCP** — `browser_navigate`, `browser_snapshot`, `browser_generate_locator`, `browser_verify_*`, etc.
- **Jira MCP** (community `mcp-atlassian`) — fetch story, AC, comments
- **Azure DevOps MCP** (Microsoft `@azure-devops/mcp`) — fetch work item, AC, comments

All five agents and the entry slash command live globally at `~/.copilot/`. Your Playwright projects don't need any framework-specific files.

---

## Prerequisites

| Required | Notes |
|---|---|
| **VS Code** (recent) | With **GitHub Copilot** extension installed and signed in |
| **Node.js + npm** | For `@playwright/mcp` and `@azure-devops/mcp` (via `npx`) |
| **`uv`** (recommended) | For the Jira MCP server (`mcp-atlassian` via `uvx`). Install: <https://docs.astral.sh/uv/> |
| **A Jira or ADO account** | With a Personal Access Token for the platform you use |
| **A Playwright project** | The framework generates specs into your existing project. If you don't have one, the Script Writer agent can scaffold one for you. |
| **Playwright browser binaries** | Installed per-project via `npx playwright install chromium` (the Script Writer runs this for you on first use). See [Per-project setup](#per-project-setup). |

---

## Install

### Windows

```powershell
git clone <this-repo-url> e2e-copilot-framework
cd e2e-copilot-framework
.\install.ps1
```

The installer copies files to `%USERPROFILE%\.copilot\` (typically `C:\Users\<you>\.copilot\`).

### macOS / Linux

```bash
git clone <this-repo-url> e2e-copilot-framework
cd e2e-copilot-framework
chmod +x install.sh
./install.sh
```

The installer copies files to `~/.copilot/`.

### What gets installed where

```
~/.copilot/
├── agents/
│   ├── e2e-analyst.agent.md
│   ├── e2e-scenario-writer.agent.md
│   ├── e2e-script-writer.agent.md
│   ├── e2e-reviewer.agent.md
│   └── e2e-report-generator.agent.md
├── instructions/
│   ├── e2e-principles.instructions.md
│   ├── playwright-style.instructions.md
│   └── playwright-patterns.instructions.md   # Playwright code-pattern library
└── prompts/
    └── e2e-testing.prompt.md
```

> **Path note:** This framework targets the VS Code Copilot user-profile convention (`~/.copilot/`). If your VS Code installation expects a different location, you can override via the `chat.agentFilesLocations` and `chat.promptFilesLocations` settings to point at this directory.

---

## Configure environment variables

The framework reads four environment variables from your shell.

### Windows (PowerShell)

```powershell
[Environment]::SetEnvironmentVariable("JIRA_URL", "https://yourcompany.atlassian.net", "User")
[Environment]::SetEnvironmentVariable("JIRA_PAT", "your-jira-personal-access-token",   "User")
[Environment]::SetEnvironmentVariable("ADO_ORG", "your-ado-org-name",                   "User")
[Environment]::SetEnvironmentVariable("ADO_PAT", "your-azure-devops-pat",               "User")
```

**Restart your terminal** so VS Code picks up the new values when you launch it.

### macOS / Linux

Add to `~/.bashrc`, `~/.zshrc`, or your shell's startup file:

```bash
export JIRA_URL="https://yourcompany.atlassian.net"
export JIRA_PAT="your-jira-personal-access-token"
export ADO_ORG="your-ado-org-name"
export ADO_PAT="your-azure-devops-pat"
```

Reload:

```bash
source ~/.bashrc   # or ~/.zshrc
```

### Where to get the tokens

- **Jira PAT (Atlassian Cloud):** <https://id.atlassian.com/manage-profile/security/api-tokens>
- **Jira PAT (Server / Data Center):** *Account menu → Personal access tokens*
- **Azure DevOps PAT:** *User settings (top-right) → Personal access tokens → New token*. Scope: at minimum **Work Items: Read**.

### Notes

- You only need the platform(s) you actually use. If you're Jira-only, skip the `ADO_*` vars.
- The framework never logs or echoes these values back. The agents reference variable names only.

---

## Register MCP servers in VS Code

The three MCP servers are configured at the **VS Code user level** so they're available in every project.

1. Open VS Code.
2. **Ctrl+Shift+P** (Windows/Linux) or **Cmd+Shift+P** (macOS).
3. Run: `MCP: Open User Configuration`
4. A JSON file opens. Paste the contents of `mcp.user.json` from this repo:

   ```json
   {
     "servers": {
       "playwright": {
         "type": "stdio",
         "command": "npx",
         "args": ["@playwright/mcp@latest", "--isolated", "--save-trace", "--caps", "testing,devtools,storage"]
       },
       "jira": {
         "type": "stdio",
         "command": "uvx",
         "args": ["mcp-atlassian"],
         "env": {
           "JIRA_URL": "${env:JIRA_URL}",
           "JIRA_PERSONAL_TOKEN": "${env:JIRA_PAT}"
         }
       },
       "azure-devops": {
         "type": "stdio",
         "command": "npx",
         "args": ["-y", "@azure-devops/mcp"],
         "env": {
           "AZURE_DEVOPS_ORG": "${env:ADO_ORG}",
           "AZURE_DEVOPS_PAT": "${env:ADO_PAT}"
         }
       }
     }
   }
   ```

   *Do not paste the `_comment` field from the file — it's just guidance.*

5. If the file already has a `"servers"` block, **merge** these three servers into it rather than replacing the whole file.
6. Save the file.
7. Restart VS Code so the MCP servers come online.

### Verify the servers are running

After restart, in Copilot Chat:

- Open the **agent dropdown** (top of the chat panel). You should see **E2E Analyst** listed.
- Hover the chat input — the tools indicator should show `playwright`, `jira`, `azure-devops` as available servers.

If they're missing, see [Troubleshooting](#troubleshooting).

---

## Per-project setup

For each Playwright project you want to run E2E tests against:

### 1. Install dependencies & browser binaries

The Script Writer agent does this automatically on first run, but you can set it up ahead of time. You need two npm dev-dependencies **plus the Playwright browser binaries** — the binaries are a separate download (the step people most often forget):

```bash
# Test runner + env loader
npm install --save-dev @playwright/test dotenv

# Browser binaries (NOT an npm package — downloaded separately)
npx playwright install chromium
#   On Linux/CI, also pull system libraries:
#   npx playwright install --with-deps chromium
```

Add these scripts to `package.json` so runs are one command:

```json
{
  "scripts": {
    "test:e2e": "playwright test",
    "test:e2e:headed": "playwright test --headed",
    "test:report": "playwright show-report"
  },
  "devDependencies": {
    "@playwright/test": "^1.49.0",
    "dotenv": "^16.4.5"
  }
}
```

### 2. Create a `.env` at the project root

```bash
APP_URL=https://your-staging-app.example.com
TEST_USERNAME=qa-automation@example.com
TEST_PASSWORD=********
```

Add `.env` to your `.gitignore`. Commit a `.env.example` with empty values instead.

### 3. Confirm `playwright.config.ts` loads dotenv and runs headless

```typescript
import { defineConfig, devices } from '@playwright/test';
import 'dotenv/config';                              // <-- required

export default defineConfig({
  testDir: './tests',
  fullyParallel: true,
  retries: 0,                                        // Reviewer agent handles iteration
  use: {
    baseURL: process.env.APP_URL,                    // <-- required
    headless: true,                                  // <-- Reviewer runs headless (CI-parity)
    trace: 'on-first-retry',
    screenshot: 'only-on-failure',
    video: 'retain-on-failure',
  },
  projects: [
    { name: 'chromium', use: { ...devices['Desktop Chrome'] } },
  ],
});
```

> **Headed vs headless — the framework uses both, on purpose:**
> - The **Script Writer** authors scripts live in a **headed** browser (`headless: false`) through the Playwright **MCP server**, so you watch the script get built. That browser is the `playwright` entry in your VS Code MCP config — it has no `--headless` flag.
> - The **Reviewer** runs the finished specs **headless** (`headless: true`) via `npx playwright test`, governed by the `use.headless` setting above — fast and CI-equivalent.
> - They're two different browsers driven by two different mechanisms, so they never collide. To watch a Reviewer run while debugging: `npm run test:e2e:headed`.

### 4. (Optional) Pre-create directories

The agents will create these on demand, but you can pre-create:

```
tests/            # generated specs land here
test-runs/        # markdown reports land here
test-results/     # Playwright's default for traces/videos
```

---

## Usage

In any Playwright project in VS Code, open Copilot Chat and type:

```
/e2e-testing https://yourcompany.atlassian.net/browse/PROJ-123
```

Or with extra testing context:

```
/e2e-testing https://dev.azure.com/org/proj/_workitems/edit/4567 --additionalComments "test mobile breakpoint too"
```

What happens next:

1. The **E2E Analyst** activates, fetches the story, reads your `.env`, and asks any clarifying questions in chat.
2. When requirements are solid, click **Generate test scenarios →**.
3. The **Scenario Writer** drafts scenarios in chat. Reply with "approve" or change requests. Iterate.
4. When approved, click **Scenarios approved → generate Playwright scripts** (you can edit the prompt before submitting).
5. The **Script Writer** uses the Playwright MCP to inspect your app, mint stable locators, and write `.spec.ts` files into `tests/`. It may ask you 1–2 questions if locators are genuinely ambiguous.
6. Click **Review & de-flake →**.
7. The **Reviewer** runs the specs, classifies failures (app bug / flaky locator / flaky timing / test bug), and patches up to 3 iterations per spec. Anything still flaky after 3 attempts is quarantined with `test.fixme()`.
8. Click **Generate test report →**.
9. The **Report Generator** writes `test-runs/<timestamp>/report.md` and tells you where to find it.

Total: 4 button clicks across the whole workflow. Full chat context carries over every handoff.

---

## The five-phase workflow

### Phase 1 — Analyst
- **Source:** `~/.copilot/agents/e2e-analyst.agent.md`
- **Reads:** Jira/ADO MCP, workspace `.env`
- **Asks:** clarifying questions about ambiguous AC, missing test data, browser scope
- **Outputs in chat:** Requirements Summary (story, env, AC list, scope, assumptions)

### Phase 2 — Scenario Writer
- **Source:** `~/.copilot/agents/e2e-scenario-writer.agent.md`
- **Reads:** chat history (Analyst's summary)
- **Outputs in chat:** numbered scenario list, AC-traced
- **Approval:** explicit user "approve" or button click

### Phase 3 — Script Writer
- **Source:** `~/.copilot/agents/e2e-script-writer.agent.md`
- **Uses:** Playwright MCP (`browser_navigate`, `browser_snapshot`, `browser_generate_locator`, `browser_verify_*`)
- **Writes:** `tests/<story-id>-<scenario-slug>.spec.ts` files
- **Asks:** when locators are genuinely ambiguous

### Phase 4 — Reviewer
- **Source:** `~/.copilot/agents/e2e-reviewer.agent.md`
- **Runs:** `npx playwright test --reporter=list`, then per-spec `--repeat-each=3` stability check
- **Classifies:** app bug / flaky locator / flaky timing / test bug
- **Patches:** up to 3 iterations per spec, then `test.fixme()` with comment
- **Outputs in chat:** Review Summary table

### Phase 5 — Report Generator
- **Source:** `~/.copilot/agents/e2e-report-generator.agent.md`
- **Writes:** `test-runs/<timestamp>/report.md`
- **Contains:** scenario↔spec mapping, per-spec status, iteration count, trace paths, flake patterns, likely app bugs, next steps

---

## Customization

All five agent files are plain markdown. Edit them in place at `~/.copilot/agents/` to adjust behavior — no rebuild step.

Common tweaks:

- **Change the iteration cap.** Open `~/.copilot/agents/e2e-reviewer.agent.md` and change the "3 iterations" rule.
- **Add a step.** Add bullets to any agent's workflow section.
- **Change the report format.** Edit `~/.copilot/agents/e2e-report-generator.agent.md` — the report template is inline.
- **Change file paths.** Edit `~/.copilot/instructions/e2e-principles.instructions.md` (the "File layout" section).
- **Run only one phase ad-hoc.** Open `~/.copilot/agents/e2e-scenario-writer.agent.md` (or any other) and set `user-invocable: true`. It'll show in the agent dropdown.

After editing, no restart needed — Copilot picks up changes on the next chat request.

---

## Troubleshooting

### `/e2e-testing` does not appear in the slash-command list

1. Verify the prompt file is at `~/.copilot/prompts/e2e-testing.prompt.md`.
2. Open VS Code settings (`Ctrl/Cmd+,`), search `chat.promptFilesLocations`. Add `~/.copilot/prompts` if it's not there.
3. Restart VS Code.

### The agent dropdown does not show **E2E Analyst**

1. Verify `~/.copilot/agents/e2e-analyst.agent.md` exists.
2. Open VS Code settings, search `chat.agentFilesLocations`. Add `~/.copilot/agents` if missing.
3. Restart VS Code.

### Jira MCP returns auth error

1. Verify env vars are set: `echo $JIRA_URL && echo $JIRA_PAT` (Unix) or `$env:JIRA_URL; $env:JIRA_PAT` (PowerShell).
2. **Restart VS Code from a terminal where the env vars are visible.** GUI-launched VS Code may not see your shell vars on macOS/Linux — launching from terminal with `code .` fixes this.
3. Confirm your PAT has at least **Browse Projects** + **Read issues** scope.
4. For Atlassian Cloud, you may need to use an **API token** (email + token) rather than a PAT. If the MCP server requires Basic auth, add `JIRA_USERNAME` to the env block in `mcp.user.json` and your env vars.

### Azure DevOps MCP returns auth error

1. Verify env vars: `echo $ADO_ORG && echo $ADO_PAT`.
2. PAT scope must include **Work Items: Read**.
3. `ADO_ORG` is the organization slug, not the full URL — e.g., `mycompany`, not `https://dev.azure.com/mycompany`.

### Playwright MCP fails to launch

1. Verify `npx` works: `npx --version`.
2. Run manually to see errors: `npx @playwright/mcp@latest --help`.
3. First run downloads the package — give it 30 seconds on slow networks.

### Generated specs fail with `ECONNREFUSED` or 404

1. Confirm `APP_URL` in your project's `.env` is reachable from your machine.
2. Confirm `playwright.config.ts` includes `import 'dotenv/config'` at the top.
3. Confirm `use.baseURL: process.env.APP_URL` is set in the config.

### Reviewer keeps hitting the 3-iteration cap

This usually means the locator strategy has run out of options. Common fixes:

- Ask your dev team to add `data-testid` attributes to the elements involved (the Reviewer's summary will name them).
- For SPA timing issues: the Reviewer should be using `expect().toBeVisible()` and `waitForResponse(predicate)`. If you see `waitForTimeout` in a generated spec, that's a bug — file it.

### "I want to rerun just one phase"

Open the agent file you want to rerun (e.g. `e2e-scenario-writer.agent.md`) and set `user-invocable: true`. It'll then appear in the agent dropdown and you can `@e2e-scenario-writer` it directly with whatever context you supply.

---

## Uninstall

```bash
# Unix
rm -rf ~/.copilot/agents/e2e-*.agent.md \
       ~/.copilot/instructions/e2e-principles.instructions.md \
       ~/.copilot/instructions/playwright-style.instructions.md \
       ~/.copilot/prompts/e2e-testing.prompt.md
```

```powershell
# Windows PowerShell
Remove-Item -Path "$env:USERPROFILE\.copilot\agents\e2e-*.agent.md"            -Force
Remove-Item -Path "$env:USERPROFILE\.copilot\instructions\e2e-principles.instructions.md"  -Force
Remove-Item -Path "$env:USERPROFILE\.copilot\instructions\playwright-style.instructions.md" -Force
Remove-Item -Path "$env:USERPROFILE\.copilot\prompts\e2e-testing.prompt.md"    -Force
```

To also remove the MCP servers, open `MCP: Open User Configuration` and delete the `playwright`, `jira`, `azure-devops` entries (or the ones you no longer want).

---

## Repo layout (this framework's source)

```
e2e-copilot-framework/
├── README.md
├── install.ps1                                # Windows installer
├── install.sh                                 # Unix/Mac installer
├── mcp.user.json                              # paste into VS Code User MCP config
├── agents/
│   ├── e2e-analyst.agent.md
│   ├── e2e-scenario-writer.agent.md
│   ├── e2e-script-writer.agent.md
│   ├── e2e-reviewer.agent.md
│   └── e2e-report-generator.agent.md
├── instructions/
│   ├── e2e-principles.instructions.md
│   ├── playwright-style.instructions.md
│   └── playwright-patterns.instructions.md
└── prompts/
    └── e2e-testing.prompt.md
```

---

## Design notes

- **Why five separate agents instead of one?** Each phase has a clean, narrow responsibility. A single agent juggling all five phases tends to hallucinate (e.g., writing code during scenario planning, or skipping clarification questions). Separating them gives each phase a focused system prompt and a guaranteed clean handoff.
- **Why button clicks between phases?** GitHub Copilot has two multi-agent primitives: `handoffs:` (button click, full context preserved) and `runSubagent` (automatic but isolated context). A button click is the only way to preserve the full conversation across an agent switch — which is what you need for "user approved scenario 3, now generate the script".
- **Why global install, not per-project?** Once a QA engineer has set this up, they can drop into any Playwright project on their machine and immediately run `/e2e-testing <url>`. No per-repo boilerplate.
- **Why no scenario files?** Scenarios live in chat. The user can ask for changes naturally; the agent re-presents the updated list. Files would add an extra approval surface without buying anything.
- **Why a separate pattern library?** `playwright-patterns.instructions.md` holds copyable code examples (POM, flake identification, artifact capture, optional Web3/financial examples) kept distinct from the style *rules* in `playwright-style.instructions.md`. It auto-loads only when an agent touches `tests/**/*.spec.ts`, so the example library and the rules stay cleanly separated. All snippets follow current Playwright guidance — role-first locators and condition-based waits.

---

*Built on the GitHub Copilot custom agents + MCP primitives.*
