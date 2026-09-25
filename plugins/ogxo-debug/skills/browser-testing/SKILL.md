---
name: browser-testing
description: Browser and web app testing with Playwright. Auto-detects dev servers; writes and runs E2E, accessibility, responsive-layout, form/login, and link-check scripts. Use when the user wants to test a website or web app or script a browser task; for diagnosing a live runtime bug use ogxo-debug:live-debug.
---

# Browser Testing Skill

## Read This First

**Before starting browser testing:**

1. For a localhost target without a user-provided URL, run server auto-detection first (skip it for static HTML or an external URL)
2. Write test scripts to /tmp/playwright-test-*.js, not the plugin directory — files written there pollute the installed plugin and are lost on update
3. After `goto`, wait for the element/state you need (`await expect(locator).toBeVisible()`) before inspecting or asserting -- never rely on `networkidle` in tests (Playwright marks it DISCOURAGED)


## Overview

Comprehensive browser testing using Playwright. Auto-detects running dev servers, writes clean test scripts to /tmp, performs E2E tests, accessibility checks, responsive design validation, and more.

## Setup (First Time Only)

```bash
BT="${CLAUDE_PLUGIN_DATA}/browser-testing"
mkdir -p "$BT" && cp "${CLAUDE_PLUGIN_ROOT}/skills/browser-testing/package.json" "${CLAUDE_PLUGIN_ROOT}/skills/browser-testing/package-lock.json" "$BT/" \
  && (cd "$BT" && npm ci && npx playwright install chromium)
```

Installs Playwright and Chromium into the plugin's data directory (not the plugin copy, which updates replace). It downloads packages and a browser build, so tell the user before running it. Only needed once per plugin install; the runner installs nothing itself and exits with a pointer to this block when Playwright is missing.

## Decision Tree: Choosing Your Approach

```
User task → Is it static HTML file?
    ├─ Yes → Use file:// URL directly (file:///path/to/file.html)
    │         ├─ Read HTML to identify selectors first
    │         └─ Write Playwright script
    │
    └─ No (dynamic web app) → Is the server running?
        ├─ No → Detect common dev commands in package.json
        │        Ask user to start server or offer to start it
        │
        └─ Yes → Use Reconnaissance-Then-Action Pattern:
            1. Navigate with goto(url)
            2. WAIT for a key element (expect(locator).toBeVisible())
            3. Take screenshot or inspect DOM
            4. Identify selectors from rendered state
            5. Execute actions with discovered selectors
```

## Workflow

Follow these steps in order:

### Step 1: Auto-Detect Dev Servers

For localhost targets where the user hasn't given a URL, run server detection first, because the user may not know which port their server is on or may have several running. Use a URL the user provides directly.

```bash
NODE_PATH="${CLAUDE_PLUGIN_DATA}/browser-testing/node_modules" node -e "require('${CLAUDE_PLUGIN_ROOT}/skills/browser-testing/lib/helpers').detectDevServers().then(s => console.log(JSON.stringify(s)))"
```

**Decision logic:**
- **1 server found**: Use automatically, inform user
- **Multiple servers found**: Ask user which to test
- **No servers found**: Ask for URL or offer to help start server
- **Static HTML**: Use `file:///` URL directly, no server needed

### Step 2: Write Test Script to /tmp

**Rules:**
- Write to `/tmp/playwright-test-*.js` (not the skill directory)
- Parameterize URL in `TARGET_URL` constant at top
- Use `headless: false` by default (visible browser for debugging)
- Use `headless: true` for CI/production or when user requests it
- Include error handling (try-catch-finally)
- Add progress logging (console.log statements)

**⚠️ COMMON PITFALL:**
- ❌ **Don't** inspect DOM right after `goto`, or gate tests on `waitUntil: 'networkidle'` (flaky: analytics, polling, and websockets keep the network busy)
- ✅ **Do** wait for the element or state the test needs: `await expect(page.getByRole('heading', { name: 'Dashboard' })).toBeVisible()`

**Template structure:**

```javascript
// /tmp/playwright-test-example.js
const { chromium } = require('playwright');
const { expect } = require('playwright/test'); // web-first assertions (auto-retry)

const TARGET_URL = 'http://localhost:3000'; // From Step 1

(async () => {
  const browser = await chromium.launch({ headless: false, slowMo: 100 });
  const page = await browser.newPage();

  try {
    console.log('🧪 Starting test...');
    
    await page.goto(TARGET_URL);
    // Wait for the element the test depends on, not for the network to go idle
    await expect(page.getByRole('main')).toBeVisible({ timeout: 10000 });
    
    console.log('✅ Page loaded:', await page.title());
    
    // Test logic here
    
    await page.screenshot({ path: '/tmp/screenshot.png', fullPage: true });
    console.log('📸 Screenshot saved');
    
    console.log('✅ Test completed');
    
  } catch (error) {
    console.error('❌ Test failed:', error.message);
    await page.screenshot({ path: '/tmp/error-screenshot.png' });
    throw error;
  } finally {
    await browser.close();
  }
})();
```

### Step 3: Execute from Skill Directory

```bash
BROWSER_TESTING_HOME="${CLAUDE_PLUGIN_DATA}/browser-testing" node "${CLAUDE_PLUGIN_ROOT}/skills/browser-testing/scripts/run-playwright.js" /tmp/playwright-test-<name>.js
```

The runner executes one script per call; run each test file separately.

## Reconnaissance-Then-Action Pattern

For dynamic web apps, follow this pattern:

### 1. Navigate and Wait
```javascript
await page.goto(TARGET_URL);
// Wait for a landmark you know will render (heading, main, a specific test id)
await expect(page.getByRole('main')).toBeVisible();

// One-off reconnaissance screenshot of an unknown page only (never in a test):
// await page.waitForLoadState('networkidle');
```

### 2. Inspect Rendered State
```javascript
// Take screenshot for visual reference
await page.screenshot({ path: '/tmp/inspection.png', fullPage: true });

// Get all buttons
const buttons = await page.$$eval('button', btns =>
  btns.map(b => ({ text: b.textContent.trim(), visible: b.offsetParent !== null }))
);
console.log('Found buttons:', buttons);

// Get all links
const links = await page.$$eval('a[href]', anchors =>
  anchors.map(a => ({ text: a.textContent.trim(), href: a.href }))
);

// Get all inputs
const inputs = await page.$$eval('input, textarea, select', elements =>
  elements.map(el => ({
    name: el.name || el.id || 'unnamed',
    type: el.type || 'text'
  }))
);
```

### 3. Execute Actions
```javascript
// Use discovered selectors
await page.click('button:has-text("Submit")');
await page.fill('input[name="email"]', 'test@example.com');
```

## Common Test Patterns

For detailed test pattern examples (element discovery, static HTML, console capture, E2E navigation, forms, responsive design, accessibility, login flows, link checking), see:

- **[test-patterns.md](references/test-patterns.md)** - Complete code examples for all common testing scenarios

## Helper Library

Use `lib/helpers.js` for common operations:

```javascript
const helpers = require('${CLAUDE_PLUGIN_ROOT}/skills/browser-testing/lib/helpers');

// Detect dev servers (use first!)
const servers = await helpers.detectDevServers();

// Safe click with retry
await helpers.safeClick(page, 'button.submit', { retries: 3 });

// Safe type with clear
await helpers.safeType(page, '#username', 'testuser');

// Take timestamped screenshot
await helpers.takeScreenshot(page, 'test-result');

// Handle cookie banners
await helpers.handleCookieBanner(page);

// Extract table data
const data = await helpers.extractTableData(page, 'table.results');

// Authenticate
await helpers.authenticate(page, {
  username: 'user@example.com',
  password: 'password'
});
```

## Inline Execution (Quick Tasks)

For simple one-off tasks:

```bash
BROWSER_TESTING_HOME="${CLAUDE_PLUGIN_DATA}/browser-testing" node "${CLAUDE_PLUGIN_ROOT}/skills/browser-testing/scripts/run-playwright.js" "
const browser = await chromium.launch({ headless: false });
const page = await browser.newPage();
await page.goto('http://localhost:3000');
await page.screenshot({ path: '/tmp/quick.png', fullPage: true });
console.log('Screenshot saved');
await browser.close();
"
```

**When to use:**
- **Inline**: Quick screenshots, element checks, page title
- **Files**: Complex tests, multi-step workflows, reusable tests

## Best Practices

1. **Reconnaissance-then-action** - For dynamic apps: navigate → wait for a key element → inspect → act
2. **Web-first assertions, not networkidle** - Use `await expect(locator).toBeVisible()` (auto-retries); `networkidle` is DISCOURAGED by Playwright and acceptable only for one-off reconnaissance screenshots
3. **Detect servers first** - Run `detectDevServers()` for localhost testing
4. **Write to /tmp** - Use `/tmp/playwright-test-*.js` for all tests (not the skill directory)
5. **Parameterize URLs** - Put URL in `TARGET_URL` constant at top
6. **Visible for debugging** - Use `headless: false` by default, `headless: true` for CI
7. **Slow down for visibility** - Use `slowMo: 100` when headless: false
8. **Wait strategies over timeouts** - Prefer `waitForSelector`, `waitForURL` over fixed timeouts
9. **Always error handle** - Wrap in try-catch-finally, close browser in finally
10. **Progress logging** - console.log throughout so user sees what's happening
11. **Screenshots on error** - Capture in catch block for debugging
12. **Static HTML support** - Use `file:///` URLs for local HTML files
13. **Console log capture** - Use `page.on('console')` for debugging JS issues
14. **Element discovery first** - For unknown pages, discover elements before acting

## Troubleshooting

**Playwright not installed:**
```bash
Run the setup block above (it installs into the plugin data directory).
```

**Module not found:**
Run scripts through run-playwright.js with `BROWSER_TESTING_HOME` set (as in the commands above), after the setup step

**Browser doesn't open:**
Check `headless: false` and display available

**Element not found:**
Add wait: `await page.waitForSelector('.element', { timeout: 10000 })`

## Example Usage

```
User: "Test if the marketing page looks good"

Process:
1. Run detectDevServers() → Found http://localhost:3001
2. Write responsive test to /tmp/playwright-test-marketing.js
3. Test desktop, tablet, mobile viewports
4. Execute: BROWSER_TESTING_HOME="${CLAUDE_PLUGIN_DATA}/browser-testing" node "${CLAUDE_PLUGIN_ROOT}/skills/browser-testing/scripts/run-playwright.js" /tmp/playwright-test-marketing.js
5. Report: "✅ Tested across 3 viewports. Screenshots in /tmp/"
```

```
User: "Check if my site is accessible"

Process:
1. Run detectDevServers() → Found http://localhost:3000
2. Write accessibility test to /tmp/playwright-test-a11y.js  
3. Inject axe-core, run checks
4. Execute test
5. Report violations: "Found 3 issues: missing alt text, low contrast, missing ARIA labels"
```

## Resources

- Helper library: `lib/helpers.js`
- Test templates: `assets/test-templates/` — e2e/accessibility/performance scaffolds to copy as starting points instead of writing specs from scratch
- Execution: Via `scripts/run-playwright.js`
- Documentation: See Playwright docs for advanced features

## ❌ Common Mistakes to Avoid

### Mistake 1: Not Waiting for the Right State Before Assertions

**Wrong:**
```
User: "Check if the dashboard loads correctly"
Assistant: *navigates to page and immediately checks for elements without waiting*
```

**Correct:**
```
User: "Check if the dashboard loads correctly"
Assistant: *navigates with page.goto(url), then awaits expect(page.getByRole('heading', { name: 'Dashboard' })).toBeVisible() before inspecting DOM*
```

**Why it matters:** Dynamic apps load content asynchronously. Checking the DOM too early produces false failures. Waiting for `networkidle` instead is its own trap: apps with analytics, polling, or websockets may never go idle (timeouts) or go idle before rendering. Web-first assertions retry until the exact state you need appears.

### Mistake 2: Writing Test Files to the Skill Directory

**Wrong:**
```
User: "Write a test for my login page"
Assistant: *creates skills/browser-testing/test-login.js*
```

**Correct:**
```
User: "Write a test for my login page"
Assistant: *creates /tmp/playwright-test-login.js*
```

**Why it matters:** The plugin directory is the installed plugin itself. Writing test files there pollutes it with user-specific artifacts, and a plugin update replaces them. Always write to /tmp/playwright-test-*.js.

### Mistake 3: Not Auto-Detecting the Dev Server

**Wrong:**
```
User: "Test my app"
Assistant: *immediately asks "What URL should I test?" without checking running servers*
```

**Correct:**
```
User: "Test my app"
Assistant: *runs detectDevServers() first, finds http://localhost:3000, then proceeds with testing*
```

**Why it matters:** The user may not know exactly which port their server is running on, or may have multiple servers. Auto-detection finds running servers automatically and avoids testing the wrong endpoint.

## Quick Reference Checklist

When a user wants to test a web page, complete these steps IN ORDER:

- [ ] **Step 1:** Run `detectDevServers()` for localhost targets without a user-provided URL
- [ ] **Step 2:** Write test script to `/tmp/playwright-test-*.js`
- [ ] **Step 3:** After `goto`, wait for the needed element with `await expect(locator).toBeVisible()` (no `networkidle` in tests)
- [ ] **Step 4:** Execute: `BROWSER_TESTING_HOME="${CLAUDE_PLUGIN_DATA}/browser-testing" node "${CLAUDE_PLUGIN_ROOT}/skills/browser-testing/scripts/run-playwright.js" /tmp/file.js`
