const { chromium } = require('playwright');
const { AxeBuilder } = require('@axe-core/playwright');

// Configuration
const TARGET_URL = 'http://localhost:3000'; // Auto-detected or user-provided

(async () => {
  const browser = await chromium.launch({ headless: false });
  const page = await browser.newPage();

  try {
    console.log('♿ Starting accessibility test...');

    await page.goto(TARGET_URL, {
      waitUntil: 'load',
      timeout: 10000
    });
    // Wait for the page's main content rather than networkidle (DISCOURAGED by Playwright).
    // Adjust the selector to the content under test; a page with no main landmark or h1 is itself an a11y finding.
    await page.locator('main, [role="main"], h1').first().waitFor({ state: 'visible', timeout: 10000 });

    console.log('Running accessibility checks...');
    const results = await new AxeBuilder({ page }).analyze();
    const violations = results.violations;

    if (violations && violations.length > 0) {
      console.log(`\n❌ Found ${violations.length} accessibility violations:\n`);

      violations.forEach((violation, index) => {
        console.log(`${index + 1}. ${violation.id}`);
        console.log(`   Description: ${violation.description}`);
        console.log(`   Impact: ${violation.impact}`);
        console.log(`   Help: ${violation.helpUrl}`);
        console.log(`   Affected elements: ${violation.nodes.length}`);

        if (violation.nodes.length > 0) {
          console.log(`   Example: ${violation.nodes[0].html}`);
        }
        console.log('');
      });

      console.log('⚠️  Please fix these issues to improve accessibility');
    } else {
      console.log('✅ No violations found by axe-core. Automated checks cover only part of WCAG; manual review is still needed.');
    }

  } catch (error) {
    console.error('❌ Accessibility test failed:', error.message);
    await page.screenshot({ path: '/tmp/accessibility-error.png' });
    throw error;
  } finally {
    await browser.close();
  }
})();
