const { chromium } = require('playwright');

// Configuration
const TARGET_URL = 'http://localhost:3000'; // Auto-detected or user-provided

(async () => {
  const browser = await chromium.launch({ headless: false });
  const page = await browser.newPage();

  try {
    console.log('⚡ Starting performance test...');

    // Start measuring
    const startTime = Date.now();

    await page.goto(TARGET_URL, {
      waitUntil: 'load', // loadEventEnd is needed below; avoid DISCOURAGED networkidle
      timeout: 30000
    });

    const loadTime = Date.now() - startTime;

    // Get performance metrics
    const metrics = await page.evaluate(() => {
      const timing = performance.timing;
      const navigation = performance.getEntriesByType('navigation')[0];

      return {
        // Core Web Vitals approximation
        loadTime: timing.loadEventEnd - timing.navigationStart,
        domContentLoaded: timing.domContentLoadedEventEnd - timing.navigationStart,
        firstPaint: performance.getEntriesByType('paint')[0]?.startTime || 0,
        timeToInteractive: timing.domInteractive - timing.navigationStart,

        // Additional metrics
        dnsLookup: timing.domainLookupEnd - timing.domainLookupStart,
        tcpConnection: timing.connectEnd - timing.connectStart,
        serverResponse: timing.responseStart - timing.requestStart,
        pageDownload: timing.responseEnd - timing.responseStart,

        // Resource counts
        resourceCount: performance.getEntriesByType('resource').length,

        // Navigation timing
        redirectTime: timing.redirectEnd - timing.redirectStart,
        cacheTime: timing.domainLookupStart - timing.fetchStart
      };
    });

    console.log('\n📊 Performance Metrics:\n');
    console.log(`Page Load Time: ${loadTime}ms`);
    console.log(`DOM Content Loaded: ${metrics.domContentLoaded}ms`);
    console.log(`Time to Interactive: ${metrics.timeToInteractive}ms`);
    console.log(`First Paint: ${metrics.firstPaint.toFixed(2)}ms`);
    console.log(`\nNetwork Timing:`);
    console.log(`  DNS Lookup: ${metrics.dnsLookup}ms`);
    console.log(`  TCP Connection: ${metrics.tcpConnection}ms`);
    console.log(`  Server Response: ${metrics.serverResponse}ms`);
    console.log(`  Page Download: ${metrics.pageDownload}ms`);
    console.log(`\nResources Loaded: ${metrics.resourceCount}`);

    // Performance assessment
    console.log('\n💡 Assessment:');
    if (loadTime < 1000) {
      console.log('✅ Excellent: Page loads very fast');
    } else if (loadTime < 3000) {
      console.log('✅ Good: Page load time is acceptable');
    } else if (loadTime < 5000) {
      console.log('⚠️  Fair: Consider optimizing page load time');
    } else {
      console.log('❌ Poor: Page load time needs improvement');
    }

    if (metrics.timeToInteractive < 2000) {
      console.log('✅ Page becomes interactive quickly');
    } else {
      console.log('⚠️  Time to interactive could be improved');
    }

  } catch (error) {
    console.error('❌ Performance test failed:', error.message);
    throw error;
  } finally {
    await browser.close();
  }
})();
