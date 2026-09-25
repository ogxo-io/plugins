# Common Test Patterns

## Element Discovery

```javascript
const { chromium } = require('playwright');
const TARGET_URL = 'http://localhost:3000';

(async () => {
  const browser = await chromium.launch({ headless: false });
  const page = await browser.newPage();

  try {
    console.log('Discovering page elements...');

    // One-off reconnaissance of an unknown page: networkidle is acceptable here (never in tests)
    await page.goto(TARGET_URL, { waitUntil: 'networkidle' });

    // Discover buttons
    const buttons = await page.$$eval('button', btns =>
      btns.map((b, i) => ({
        index: i,
        text: b.textContent.trim(),
        visible: b.offsetParent !== null
      }))
    );
    console.log(`\nFound ${buttons.length} buttons:`);
    buttons.forEach(b => console.log(`  [${b.index}] ${b.text} ${b.visible ? '' : '(hidden)'}`));

    // Discover links
    const links = await page.$$eval('a[href]', anchors =>
      anchors.map(a => ({ text: a.textContent.trim(), href: a.href }))
    );
    console.log(`\nFound ${links.length} links (showing first 5):`);
    links.slice(0, 5).forEach(l => console.log(`  - ${l.text} -> ${l.href}`));

    // Discover inputs
    const inputs = await page.$$eval('input, textarea, select', elements =>
      elements.map(el => ({
        name: el.name || el.id || 'unnamed',
        type: el.type || 'text'
      }))
    );
    console.log(`\nFound ${inputs.length} input fields:`);
    inputs.forEach(i => console.log(`  - ${i.name} (${i.type})`));

    // Screenshot for reference
    await page.screenshot({ path: '/tmp/page_discovery.png', fullPage: true });
    console.log('\nScreenshot saved to /tmp/page_discovery.png');

  } catch (error) {
    console.error('Discovery failed:', error.message);
    throw error;
  } finally {
    await browser.close();
  }
})();
```

## Static HTML Testing

```javascript
const { chromium } = require('playwright');
const path = require('path');

const HTML_FILE = path.resolve('path/to/file.html');
const TARGET_URL = `file://${HTML_FILE}`;

(async () => {
  const browser = await chromium.launch({ headless: false });
  const page = await browser.newPage();

  try {
    console.log('Testing static HTML file...');

    await page.goto(TARGET_URL);

    // Take initial screenshot
    await page.screenshot({ path: '/tmp/static_before.png', fullPage: true });

    // Interact with elements
    await page.click('text=Click Me');
    await page.fill('#name', 'John Doe');
    await page.fill('#email', 'john@example.com');
    await page.click('button[type="submit"]');

    await page.waitForTimeout(500);

    // Take final screenshot
    await page.screenshot({ path: '/tmp/static_after.png', fullPage: true });

    console.log('Static HTML test completed');
  } catch (error) {
    console.error('Test failed:', error.message);
    throw error;
  } finally {
    await browser.close();
  }
})();
```

## Console Log Capture

```javascript
const { chromium } = require('playwright');
const TARGET_URL = 'http://localhost:3000';

(async () => {
  const consoleLogs = [];
  const browser = await chromium.launch({ headless: false });
  const page = await browser.newPage();

  try {
    console.log('Capturing console logs...');

    // Set up console log capture
    page.on('console', msg => {
      const logEntry = `[${msg.type()}] ${msg.text()}`;
      consoleLogs.push(logEntry);
      console.log(`Browser console: ${logEntry}`);
    });

    await page.goto(TARGET_URL);
    await page.getByRole('main').waitFor(); // wait for rendered content, not network idle

    // Interact with page (triggers console logs)
    await page.click('text=Dashboard');
    await page.waitForTimeout(1000);

    // Save logs to file
    const fs = require('fs');
    fs.writeFileSync('/tmp/console.log', consoleLogs.join('\n'));

    console.log(`\nCaptured ${consoleLogs.length} console messages`);
    console.log('Logs saved to /tmp/console.log');

  } catch (error) {
    console.error('Console capture failed:', error.message);
    throw error;
  } finally {
    await browser.close();
  }
})();
```

## E2E Test with Navigation

```javascript
const { chromium } = require('playwright');
const TARGET_URL = 'http://localhost:3000';

(async () => {
  const browser = await chromium.launch({ headless: false, slowMo: 100 });
  const page = await browser.newPage();

  try {
    await page.goto(TARGET_URL);
    await page.click('a[href="/about"]');
    await page.waitForURL('**/about');

    const heading = await page.textContent('h1');
    if (!heading.includes('About')) throw new Error('About heading not found');

    console.log('Navigation test passed');
  } catch (error) {
    console.error('Test failed:', error.message);
    throw error;
  } finally {
    await browser.close();
  }
})();
```

## Form Testing

```javascript
const { chromium } = require('playwright');
const TARGET_URL = 'http://localhost:3000';

(async () => {
  const browser = await chromium.launch({ headless: false, slowMo: 50 });
  const page = await browser.newPage();

  try {
    await page.goto(`${TARGET_URL}/contact`);

    await page.fill('input[name="name"]', 'John Doe');
    await page.fill('input[name="email"]', 'john@example.com');
    await page.fill('textarea[name="message"]', 'Test message');
    await page.click('button[type="submit"]');

    await page.waitForSelector('.success-message', { timeout: 5000 });
    console.log('Form submitted successfully');
  } catch (error) {
    console.error('Form test failed:', error.message);
    throw error;
  } finally {
    await browser.close();
  }
})();
```

## Responsive Design Testing

```javascript
const { chromium } = require('playwright');
const TARGET_URL = 'http://localhost:3000';

(async () => {
  const browser = await chromium.launch({ headless: false });
  const page = await browser.newPage();

  const viewports = [
    { name: 'Desktop', width: 1920, height: 1080 },
    { name: 'Tablet', width: 768, height: 1024 },
    { name: 'Mobile', width: 375, height: 667 }
  ];

  try {
    for (const viewport of viewports) {
      console.log(`Testing ${viewport.name}`);

      await page.setViewportSize({ width: viewport.width, height: viewport.height });
      await page.goto(TARGET_URL);
      await page.waitForTimeout(1000);

      await page.screenshot({
        path: `/tmp/${viewport.name.toLowerCase()}.png`,
        fullPage: true
      });
    }

    console.log('All viewports tested');
  } catch (error) {
    console.error('Responsive test failed:', error.message);
    throw error;
  } finally {
    await browser.close();
  }
})();
```

## Accessibility Testing

```javascript
const { chromium } = require('playwright');
const { AxeBuilder } = require('@axe-core/playwright');
const TARGET_URL = 'http://localhost:3000';

(async () => {
  const browser = await chromium.launch({ headless: false });
  const page = await browser.newPage();

  try {
    await page.goto(TARGET_URL);
    await page.getByRole('main').waitFor(); // wait for rendered content, not network idle

    const results = await new AxeBuilder({ page }).analyze();
    const violations = results.violations;

    if (violations && violations.length > 0) {
      console.log(`Found ${violations.length} accessibility violations:`);
      violations.forEach((v, i) => {
        console.log(`\n${i + 1}. ${v.id}: ${v.description}`);
        console.log(`   Impact: ${v.impact}`);
      });
    } else {
      console.log('No accessibility violations found');
    }
  } catch (error) {
    console.error('Accessibility test failed:', error.message);
    throw error;
  } finally {
    await browser.close();
  }
})();
```

## Login Flow Testing

```javascript
const { chromium } = require('playwright');
const TARGET_URL = 'http://localhost:3000';

(async () => {
  const browser = await chromium.launch({ headless: false });
  const page = await browser.newPage();

  try {
    await page.goto(`${TARGET_URL}/login`);

    await page.fill('input[name="email"]', 'test@example.com');
    await page.fill('input[name="password"]', 'password123');
    await page.click('button[type="submit"]');

    await page.waitForURL('**/dashboard', { timeout: 5000 });
    console.log('Login successful, redirected to dashboard');
  } catch (error) {
    console.error('Login test failed:', error.message);
    throw error;
  } finally {
    await browser.close();
  }
})();
```

## Link Checking

```javascript
const { chromium } = require('playwright');
const TARGET_URL = 'http://localhost:3000';

(async () => {
  const browser = await chromium.launch({ headless: true });
  const page = await browser.newPage();

  try {
    await page.goto(TARGET_URL);

    const links = await page.$$eval('a[href]', anchors =>
      anchors.map(a => ({ url: a.href, text: a.textContent?.trim() }))
    );

    console.log(`Found ${links.length} links to check`);

    const results = { working: 0, broken: [] };

    for (const link of links) {
      try {
        const response = await page.request.get(link.url);
        if (response.ok()) {
          results.working++;
        } else {
          results.broken.push({ ...link, status: response.status() });
        }
      } catch (e) {
        results.broken.push({ ...link, error: e.message });
      }
    }

    console.log(`Working links: ${results.working}`);
    if (results.broken.length > 0) {
      console.log(`Broken links (${results.broken.length}):`);
      results.broken.forEach(l => console.log(`  - ${l.url}`));
    }
  } catch (error) {
    console.error('Link check failed:', error.message);
    throw error;
  } finally {
    await browser.close();
  }
})();
```
