const { chromium } = require('playwright');

// Configuration
const TARGET_URL = 'http://localhost:3000'; // Auto-detected or user-provided
const HEADLESS = false; // Visible browser by default
// Unique per run, so parallel runs don't overwrite each other's screenshots
const RUN = process.env.PLAYWRIGHT_RUN || `${Date.now()}-${process.pid}`;

(async () => {
  const browser = await chromium.launch({
    headless: HEADLESS,
    slowMo: 100 // Slow down for visibility
  });

  const page = await browser.newPage();

  try {
    console.log('🧪 Starting E2E test...');

    // Navigate to page
    await page.goto(TARGET_URL, {
      waitUntil: 'domcontentloaded',
      timeout: 10000
    });
    // Element-based waits (below) replace networkidle, which Playwright marks DISCOURAGED

    console.log('✅ Page loaded:', await page.title());

    // Add your test steps here
    // Example: Check if element exists
    await page.waitForSelector('h1', { timeout: 5000 });
    const heading = await page.textContent('h1');
    console.log('Found heading:', heading);

    // Take screenshot
    await page.screenshot({
      path: `/tmp/playwright-${RUN}-page.png`,
      fullPage: true
    });
    console.log(`📸 Screenshot saved to /tmp/playwright-${RUN}-page.png`);

    console.log('✅ Test completed successfully');

  } catch (error) {
    console.error('❌ Test failed:', error.message);
    await page.screenshot({ path: `/tmp/playwright-${RUN}-error.png` });
    throw error;
  } finally {
    await browser.close();
  }
})();
