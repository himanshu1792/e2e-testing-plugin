---
applyTo: 'tests/**/*.spec.ts'
description: Concrete Playwright code-pattern library with copyable examples for the Script Writer and Reviewer.
---

# Playwright Pattern Library

A reference of concrete, copy-adaptable Playwright patterns. Loaded automatically when an agent works on files under `tests/`.

> **Alignment:** Every snippet here follows this framework's rules in `playwright-style.instructions.md`: **role-first locators** (`getByRole`/`getByLabel`/`getByTestId`, not raw CSS) and **condition-based waits** (no `waitForTimeout`, no `networkidle`). If a snippet here ever conflicts with `playwright-style.instructions.md`, the style file wins.

## Test file organization

```
tests/
├── <story-id>-<scenario-slug>.spec.ts     # one spec per scenario
├── pages/                                  # Page Objects (only if 3+ specs share a flow)
│   ├── LoginPage.ts
│   └── ItemsPage.ts
└── fixtures/                               # shared test data / auth setup (optional)
    ├── auth.ts
    └── data.ts
```

## Page Object Model

Create a Page Object only when 3+ specs share the same flow. Actions live in the Page Object; **assertions stay in the spec**.

```typescript
import type { Page, Locator } from '@playwright/test';

export class ItemsPage {
  readonly page: Page;
  readonly searchInput: Locator;
  readonly itemCards: Locator;
  readonly createButton: Locator;

  constructor(page: Page) {
    this.page = page;
    // Role-first locators (prefer roles over data-testid CSS)
    this.searchInput = page.getByRole('searchbox', { name: /search/i });
    this.itemCards = page.getByRole('listitem');
    this.createButton = page.getByRole('button', { name: /create/i });
  }

  async goto() {
    await this.page.goto('/items');                       // baseURL from config
  }

  async search(query: string) {
    await this.searchInput.fill(query);
    // Wait on the real response, NOT networkidle
    await this.page.waitForResponse(
      resp => resp.url().includes('/api/search') && resp.ok()
    );
  }

  async getItemCount() {
    return this.itemCards.count();
  }
}
```

## Test structure

```typescript
import { test, expect } from '@playwright/test';
import { ItemsPage } from './pages/ItemsPage';

test.describe('PROJ-123: Item Search', () => {
  let itemsPage: ItemsPage;

  test.beforeEach(async ({ page }) => {
    itemsPage = new ItemsPage(page);
    await itemsPage.goto();
  });

  test('AC#2: search by keyword returns matching items', async ({ page }) => {
    await itemsPage.search('widget');

    await expect(itemsPage.itemCards.first()).toContainText(/widget/i);
    expect(await itemsPage.getItemCount()).toBeGreaterThan(0);
  });

  test('AC#3: no results shows empty state', async ({ page }) => {
    await itemsPage.search('xyznonexistent123');

    await expect(page.getByText(/no results/i)).toBeVisible();
    expect(await itemsPage.getItemCount()).toBe(0);
  });
});
```

## Flaky-test identification

Run a spec many times to surface intermittent failures (the Reviewer uses this):

```bash
# Repeat a single spec to expose flakiness
npx playwright test tests/proj-123-search.spec.ts --repeat-each=10

# Or temporarily allow retries to measure flake rate
npx playwright test tests/proj-123-search.spec.ts --retries=3
```

## Common flake causes & fixes

**Race conditions** — don't assume an element is ready:

```typescript
// ❌ Bad
await page.locator('button').click();           // may fire before hydration

// ✅ Good — locators auto-wait for actionability
await page.getByRole('button', { name: 'Submit' }).click();
```

**Network timing** — wait on the response, not the clock:

```typescript
// ❌ Bad
await page.waitForTimeout(5000);

// ✅ Good
await page.waitForResponse(r => r.url().includes('/api/data') && r.ok());
```

**Async UI / animation** — wait for the post-condition you actually care about:

```typescript
// ❌ Bad — networkidle is discouraged by Playwright
// await page.waitForLoadState('networkidle');

// ✅ Good — assert the thing that proves the UI settled
await expect(page.getByRole('heading', { name: /dashboard/i })).toBeVisible();
```

## Quarantine (after 3 failed Reviewer iterations)

```typescript
test.fixme('AC#3: search by category', async ({ page }) => {
  // QUARANTINED after 3 iterations (Reviewer).
  // Symptom: result-card locator drifts on slow staging.
  // Unblock: ask frontend to add data-testid="result-card".
});
```

Never use `test.skip()` to hide a failure, and never lower an assertion to make a test pass.

## Artifact capture

```typescript
// Screenshot (also automatic on failure via config: screenshot: 'only-on-failure')
await page.screenshot({ path: 'test-results/after-login.png' });
await page.screenshot({ path: 'test-results/full.png', fullPage: true });

// Element screenshot
await page.getByRole('img', { name: 'chart' }).screenshot({ path: 'test-results/chart.png' });
```

Traces and video are configured globally (`trace: 'on-first-retry'`, `video: 'retain-on-failure'`). Inspect a trace with:

```bash
npx playwright show-trace test-results/<path>/trace.zip
```

## Auth reuse (skip re-login on every spec)

Capture storage state once and reuse it so reruns don't re-authenticate (helps MFA-gated apps):

```typescript
// global-setup.ts — run once, save authenticated state
import { chromium } from '@playwright/test';

export default async function globalSetup() {
  const browser = await chromium.launch();
  const page = await browser.newPage();
  await page.goto(process.env.APP_URL!);
  await page.getByLabel('Username').fill(process.env.TEST_USERNAME!);
  await page.getByLabel('Password').fill(process.env.TEST_PASSWORD!);
  await page.getByRole('button', { name: 'Sign in' }).click();
  await page.context().storageState({ path: 'tests/.auth/state.json' });
  await browser.close();
}
```

```typescript
// playwright.config.ts
export default defineConfig({
  globalSetup: './global-setup.ts',
  use: { storageState: 'tests/.auth/state.json' },
});
```

Add `tests/.auth/` to `.gitignore` — it contains session tokens.

---

## Optional appendix — specialized app types

These are **only relevant if the app under test uses them**. Skip otherwise.

### Web3 / wallet apps

```typescript
test('AC#N: wallet connection', async ({ page, context }) => {
  await context.addInitScript(() => {
    (window as any).ethereum = {
      isMetaMask: true,
      request: async ({ method }: { method: string }) => {
        if (method === 'eth_requestAccounts')
          return ['0x1234567890123456789012345678901234567890'];
        if (method === 'eth_chainId') return '0x1';
      },
    };
  });

  await page.goto('/');
  await page.getByRole('button', { name: /connect wallet/i }).click();
  await expect(page.getByText(/0x1234/)).toBeVisible();
});
```

### Financial / irreversible-action flows

Guard real-money or destructive actions so they never fire against production:

```typescript
test('AC#N: trade execution', async ({ page }) => {
  test.skip(process.env.NODE_ENV === 'production', 'No real-money trades on prod');

  await page.goto('/markets/test-market');
  await page.getByRole('button', { name: /buy/i }).click();
  await page.getByLabel('Amount').fill('1.0');
  await page.getByRole('button', { name: /confirm/i }).click();

  await page.waitForResponse(r => r.url().includes('/api/trade') && r.status() === 200);
  await expect(page.getByText(/success/i)).toBeVisible();
});
```

### Optional — CI integration

You chose VS Code-local as the primary surface, so this is reference only. If you later wire these specs into GitHub Actions, keep `retries: 0` locally (so the Reviewer sees raw flakes) but you may set `retries: 2` in CI:

```yaml
# .github/workflows/e2e.yml (optional)
name: E2E Tests
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: 20 }
      - run: npm ci
      - run: npx playwright install --with-deps
      - run: npx playwright test
        env:
          APP_URL: ${{ vars.STAGING_URL }}
          TEST_USERNAME: ${{ secrets.TEST_USERNAME }}
          TEST_PASSWORD: ${{ secrets.TEST_PASSWORD }}
      - uses: actions/upload-artifact@v4
        if: always()
        with: { name: playwright-report, path: playwright-report/, retention-days: 30 }
```
