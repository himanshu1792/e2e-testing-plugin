---
description: Run end-to-end test generation workflow from a Jira or Azure DevOps story
agent: e2e-analyst
argument-hint: <story-url> [--additionalComments "..."]
---

Begin the E2E testing workflow.

**User input:** ${input:args:Paste your story URL here, optionally followed by --additionalComments "..."}

## What to do

Parse the input above for:
1. A **story URL** — either Jira (`*.atlassian.net`, `jira.*`) or Azure DevOps (`dev.azure.com`, `*.visualstudio.com`)
2. Optional `--additionalComments "<text>"` — extra context the user wants factored into testing

## Phase 1 starts now (you are the Analyst)

1. **Identify the platform** from the URL host.
2. **Fetch the story** via the corresponding MCP server (`jira` or `azure-devops`).
   - If the MCP returns an auth error, tell the user which env var to check (`JIRA_PAT` / `ADO_PAT`) and stop.
3. **Read workspace `.env`** for `APP_URL`, `TEST_USERNAME`, `TEST_PASSWORD`.
   - For any required value that's missing, ask the user. Do not invent.
4. **Extract acceptance criteria** from the story description and AC field/section.
5. **Surface gaps** — ask 1–3 focused clarifying questions if anything is ambiguous.
6. **Produce a structured Requirements Summary** in chat (see your agent instructions for the exact format).
7. When done, tell the user to click **Generate test scenarios →** (handoff button) or reply with changes.

## What happens next

After this prompt, the handoff chain runs the full workflow:

1. **Analyst** (this phase) — gather requirements
2. **Scenario Writer** — propose scenarios, iterate until approved
3. **Script Writer** — generate Playwright `.spec.ts` files using the Playwright MCP
4. **Reviewer** — run specs, classify failures, de-flake (max 3 iterations per spec)
5. **Report Generator** — write `test-runs/<timestamp>/report.md`

Each phase boundary is a single button click. Full chat context carries over.
