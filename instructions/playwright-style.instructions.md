---
applyTo: 'tests/**/*.spec.ts'
description: Style and structure guide for generated Playwright spec files
---

# Playwright Spec Style Guide

This file applies whenever an agent is generating or editing `.spec.ts` files under `tests/`.

## Canonical file template

```typescript
import { test, expect } from '@playwright/test';

test.describe('<STORY-ID>: <feature name>', () => {
  test.beforeEach(async ({ page }) => {
    // Setup: navigate to baseURL, optionally log in
    await page.goto('/');
  });

  test('AC#<N>: <scenario title>', async ({ page }) => {
    // Arrange
    // Act
    await page.getByRole('button', { name: 'Submit' }).click();

    // Assert
    await expect(page.getByRole('heading', { name: /success/i })).toBeVisible();
  });
});
```

## Imports

- **Always:** `import { test, expect } from '@playwright/test';`
- **Never** import individual matchers from elsewhere.
- Do not import `dotenv` inside test files — the project's `playwright.config.ts` handles env loading globally.

## Test names

- Format: `'AC#<N>: <readable scenario title>'`
- Use the exact AC number from the story for traceability into the report.
- Multiple ACs in one test (rare): `'AC#2, AC#3: <title>'`.

## Locators

- Priority: `getByRole` → `getByLabel` → `getByTestId` → `getByText` → CSS/XPath.
- One locator per element. Reuse via variables when used 2+ times in the same test:
  ```typescript
  const submitButton = page.getByRole('button', { name: 'Submit' });
  await submitButton.click();
  await expect(submitButton).toBeDisabled();
  ```

## Assertions

- **Always `await expect(...)`** — never bare `expect(...)`.
- Prefer specific matchers over generic ones:
  - ✅ `toBeVisible`, `toHaveText`, `toHaveValue`, `toHaveURL`, `toBeDisabled`, `toHaveCount`
  - ❌ `toBeTruthy`, `toBeDefined` (too vague for E2E)
- Custom timeout only when justified by a known slow flow:
  ```typescript
  await expect(page.getByText(/processing complete/i)).toBeVisible({ timeout: 15_000 });
  ```

## Environment

- All app-level config from `process.env`:
  - `process.env.APP_URL` — but prefer `await page.goto('/')` with `baseURL` from config
  - `process.env.TEST_USERNAME`, `process.env.TEST_PASSWORD` — never inline these
- Use non-null assertion `!` for required env vars when type-safety is needed:
  ```typescript
  await page.getByLabel('Username').fill(process.env.TEST_USERNAME!);
  ```

## Page Objects

Create a Page Object **only** when 3+ scenarios share the same flow.

- Path: `tests/pages/<PageName>.ts`
- Structure:
  ```typescript
  import type { Page, Locator } from '@playwright/test';

  export class LoginPage {
    readonly page: Page;
    readonly usernameField: Locator;
    readonly passwordField: Locator;
    readonly submitButton: Locator;

    constructor(page: Page) {
      this.page = page;
      this.usernameField = page.getByLabel('Username');
      this.passwordField = page.getByLabel('Password');
      this.submitButton = page.getByRole('button', { name: 'Sign in' });
    }

    async login(username: string, password: string) {
      await this.usernameField.fill(username);
      await this.passwordField.fill(password);
      await this.submitButton.click();
    }
  }
  ```
- Page Object methods perform actions, not assertions. Assertions stay in the spec.

## Expected `playwright.config.ts`

The user's workspace should have:

```typescript
import { defineConfig, devices } from '@playwright/test';
import 'dotenv/config';

export default defineConfig({
  testDir: './tests',
  fullyParallel: true,
  retries: 0,                                  // Reviewer agent handles iteration explicitly
  use: {
    baseURL: process.env.APP_URL,
    headless: true,                            // Reviewer runs specs headless (CI-parity); Script Writer authors via a SEPARATE headed MCP browser
    trace: 'on-first-retry',
    screenshot: 'only-on-failure',
    video: 'retain-on-failure',
  },
  projects: [
    { name: 'chromium', use: { ...devices['Desktop Chrome'] } },
  ],
});
```

If any of these are missing in the user's config, patch them before generating specs.

## Banned patterns (never emit these)

| Banned | Replacement |
|---|---|
| `page.waitForTimeout(1000)` | `await expect(locator).toBeVisible()` or `page.waitForResponse(predicate)` |
| `await page.click('button.submit')` (CSS) | `await page.getByRole('button', { name: 'Submit' }).click()` |
| `if (await locator.isVisible()) { ... }` | `await expect(locator).toBeVisible()` |
| `await page.goto('https://hardcoded.example.com')` | `await page.goto('/')` with `baseURL` from config |
| `console.log(process.env.TEST_PASSWORD)` | Just remove. Never log secrets. |
| `test.skip()` to hide a failure | `test.fixme()` with comment, or fix the test |
| `expect(value)` (no `await`) | `await expect(value)` |
| A `test()` body with **no** `await expect(` | Add a real assertion on the AC's expected outcome — a test that asserts nothing is fake-green |
| `expect(true)`, `expect(1).toBe(1)` (tautology) | Assert the actual observable outcome the AC describes |
| `expect(page.locator('body')).toBeVisible()` (vacuous) | Assert the specific element/text the AC names |
| `expect.soft(...)` as the only assertion | Add at least one hard `await expect(...)` for the primary outcome |
| `// await expect(...)` (commented-out assertion) | Re-enable it and fix the underlying issue |

## Comments

Default to no comments. Add a one-line comment only when the **why** is non-obvious:
- Documenting a known intermittent (with the iteration number that triaged it)
- Explaining why a fallback locator (CSS) was needed
- Why a custom timeout differs from the default

Never add comments that just restate the code.
