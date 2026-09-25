# Frontend Performance Optimization

Deep-dive reference for profiling and optimizing web frontend performance.

## Core Web Vitals

### Key Metrics

| Metric | Good | Needs Improvement | Poor |
|--------|------|-------------------|------|
| **LCP** (Largest Contentful Paint) | ≤ 2.5s | ≤ 4.0s | > 4.0s |
| **INP** (Interaction to Next Paint) | ≤ 200ms | ≤ 500ms | > 500ms |
| **CLS** (Cumulative Layout Shift) | ≤ 0.1 | ≤ 0.25 | > 0.25 |

### Measuring Core Web Vitals

```javascript
// Using web-vitals library
import { onCLS, onINP, onLCP, onFCP, onTTFB } from 'web-vitals';

function sendToAnalytics(metric) {
  console.log(metric.name, metric.value);
}

onCLS(sendToAnalytics);
onINP(sendToAnalytics);
onLCP(sendToAnalytics);
onFCP(sendToAnalytics);
onTTFB(sendToAnalytics);
```

```bash
# Lighthouse CLI
npm install -g lighthouse
lighthouse https://example.com --output=json --output-path=./report.json

# With specific categories
lighthouse https://example.com --only-categories=performance
```

## Bundle Optimization

### Analyzing Bundle Size

```bash
# webpack-bundle-analyzer
npm install --save-dev webpack-bundle-analyzer

# Next.js
npm install @next/bundle-analyzer

# Vite
npm install rollup-plugin-visualizer
```

```javascript
// next.config.js
const withBundleAnalyzer = require('@next/bundle-analyzer')({
  enabled: process.env.ANALYZE === 'true',
});
module.exports = withBundleAnalyzer({});

// Run: ANALYZE=true npm run build
```

### Code Splitting

```javascript
// React lazy loading
import { lazy, Suspense } from 'react';

const HeavyComponent = lazy(() => import('./HeavyComponent'));

function App() {
  return (
    <Suspense fallback={<Loading />}>
      <HeavyComponent />
    </Suspense>
  );
}

// Route-based splitting (Next.js automatic)
// pages/dashboard.js → separate chunk

// Named chunks for debugging
const Dashboard = lazy(() =>
  import(/* webpackChunkName: "dashboard" */ './Dashboard')
);
```

### Tree Shaking

```javascript
// Bad: Import entire library
import _ from 'lodash';
const result = _.map(data, fn);

// Good: Import only what you need
import map from 'lodash/map';
const result = map(data, fn);

// Or use lodash-es for better tree shaking
import { map } from 'lodash-es';
```

### Dynamic Imports

```javascript
// Load on demand
async function loadEditor() {
  const { Editor } = await import('./Editor');
  return Editor;
}

// Prefetch for likely navigation
<link rel="prefetch" href="/dashboard.js" />

// Preload for critical resources
<link rel="preload" href="/critical.js" as="script" />
```

## Image Optimization

### Modern Formats

```html
<!-- Use picture element for format fallbacks -->
<picture>
  <source srcset="image.avif" type="image/avif" />
  <source srcset="image.webp" type="image/webp" />
  <img src="image.jpg" alt="Description" />
</picture>
```

### Responsive Images

```html
<!-- srcset for different sizes -->
<img
  src="image-800.jpg"
  srcset="image-400.jpg 400w, image-800.jpg 800w, image-1200.jpg 1200w"
  sizes="(max-width: 600px) 400px, (max-width: 1000px) 800px, 1200px"
  alt="Description"
/>
```

### Lazy Loading

```html
<!-- Native lazy loading -->
<img src="image.jpg" loading="lazy" alt="Description" />

<!-- With dimensions to prevent CLS -->
<img
  src="image.jpg"
  loading="lazy"
  width="800"
  height="600"
  alt="Description"
/>
```

### Next.js Image Component

```javascript
import Image from 'next/image';

// Automatic optimization
<Image
  src="/hero.jpg"
  alt="Hero"
  width={1200}
  height={600}
  priority  // Preload for LCP images
/>

// Fill container
<div style={{ position: 'relative', width: '100%', height: '400px' }}>
  <Image
    src="/hero.jpg"
    alt="Hero"
    fill
    style={{ objectFit: 'cover' }}
  />
</div>
```

## CSS Optimization

### Critical CSS

```javascript
// Extract critical CSS with critters (Next.js built-in)
// next.config.js
module.exports = {
  experimental: {
    optimizeCss: true,
  },
};

// Manual critical CSS
<style dangerouslySetInnerHTML={{ __html: criticalCSS }} />
<link rel="preload" href="/styles.css" as="style" onLoad="this.rel='stylesheet'" />
```

### CSS-in-JS Performance

```javascript
// Avoid runtime CSS-in-JS for performance
// Prefer: Tailwind, CSS Modules, vanilla-extract

// If using styled-components, enable SSR
import { ServerStyleSheet } from 'styled-components';

// vanilla-extract (zero runtime)
import { style } from '@vanilla-extract/css';

export const button = style({
  backgroundColor: 'blue',
  color: 'white',
});
```

### Reduce CSS Specificity

```css
/* Bad: High specificity, hard to override */
#header .nav ul li a.active { color: blue; }

/* Good: Low specificity, composable */
.nav-link { color: gray; }
.nav-link--active { color: blue; }
```

### Contain Property

```css
/* Isolate layout/paint calculations */
.card {
  contain: layout style paint;
}

/* For content that doesn't affect outside layout */
.sidebar {
  contain: strict;
}
```

## JavaScript Performance

### Debounce & Throttle

```javascript
// Debounce - wait until user stops
function debounce(fn, delay) {
  let timeoutId;
  return (...args) => {
    clearTimeout(timeoutId);
    timeoutId = setTimeout(() => fn(...args), delay);
  };
}

const debouncedSearch = debounce((query) => {
  fetchResults(query);
}, 300);

// Throttle - limit execution rate
function throttle(fn, limit) {
  let inThrottle;
  return (...args) => {
    if (!inThrottle) {
      fn(...args);
      inThrottle = true;
      setTimeout(() => inThrottle = false, limit);
    }
  };
}

const throttledScroll = throttle(() => {
  updateScrollPosition();
}, 100);
```

### requestAnimationFrame

```javascript
// Bad: Updates on every scroll event
window.addEventListener('scroll', () => {
  element.style.transform = `translateY(${window.scrollY}px)`;
});

// Good: Batched with rAF
let ticking = false;

window.addEventListener('scroll', () => {
  if (!ticking) {
    requestAnimationFrame(() => {
      element.style.transform = `translateY(${window.scrollY}px)`;
      ticking = false;
    });
    ticking = true;
  }
});
```

### Web Workers

```javascript
// main.js
const worker = new Worker('/worker.js');

worker.postMessage({ data: largeArray });
worker.onmessage = (e) => {
  console.log('Result:', e.data);
};

// worker.js
self.onmessage = (e) => {
  const result = expensiveComputation(e.data);
  self.postMessage(result);
};
```

### requestIdleCallback

```javascript
// Run non-critical work when browser is idle
function processQueue(queue) {
  requestIdleCallback((deadline) => {
    while (deadline.timeRemaining() > 0 && queue.length > 0) {
      const item = queue.shift();
      processItem(item);
    }

    if (queue.length > 0) {
      processQueue(queue);
    }
  });
}
```

## React Performance

### useMemo & useCallback

```javascript
// useMemo for expensive computations
const expensiveValue = useMemo(() => {
  return items.filter(item => item.active).map(item => transform(item));
}, [items]);

// useCallback for stable function references
const handleClick = useCallback((id) => {
  setSelected(id);
}, []);

// Don't overuse - adds overhead
// Only use when:
// 1. Computation is actually expensive
// 2. Reference stability matters (deps, memo)
```

### React.memo

```javascript
// Memoize component to prevent unnecessary re-renders
const ExpensiveList = React.memo(function ExpensiveList({ items }) {
  return (
    <ul>
      {items.map(item => <li key={item.id}>{item.name}</li>)}
    </ul>
  );
});

// With custom comparison
const Item = React.memo(
  function Item({ item, onSelect }) {
    return <div onClick={() => onSelect(item.id)}>{item.name}</div>;
  },
  (prevProps, nextProps) => prevProps.item.id === nextProps.item.id
);
```

### Virtualization

```javascript
import { FixedSizeList } from 'react-window';

function VirtualList({ items }) {
  const Row = ({ index, style }) => (
    <div style={style}>{items[index].name}</div>
  );

  return (
    <FixedSizeList
      height={400}
      itemCount={items.length}
      itemSize={50}
      width="100%"
    >
      {Row}
    </FixedSizeList>
  );
}

// For variable heights
import { VariableSizeList } from 'react-window';

// For grids
import { FixedSizeGrid } from 'react-window';
```

### Suspense & Transitions

```javascript
import { Suspense, useTransition } from 'react';

function App() {
  const [isPending, startTransition] = useTransition();
  const [tab, setTab] = useState('home');

  function selectTab(nextTab) {
    startTransition(() => {
      setTab(nextTab);
    });
  }

  return (
    <>
      <TabButton onClick={() => selectTab('home')}>Home</TabButton>
      <TabButton onClick={() => selectTab('posts')}>Posts</TabButton>

      {isPending && <Spinner />}

      <Suspense fallback={<Loading />}>
        {tab === 'home' && <Home />}
        {tab === 'posts' && <Posts />}
      </Suspense>
    </>
  );
}
```

### Server Components (Next.js)

```javascript
// Server Component - no JS sent to client
async function ProductList() {
  const products = await db.products.findMany();

  return (
    <ul>
      {products.map(product => (
        <li key={product.id}>{product.name}</li>
      ))}
    </ul>
  );
}

// Client Component - interactive
'use client';

function AddToCart({ productId }) {
  const [loading, setLoading] = useState(false);

  return (
    <button onClick={() => addToCart(productId)}>
      Add to Cart
    </button>
  );
}
```

## Loading Strategies

### Resource Hints

```html
<!-- DNS prefetch for external domains -->
<link rel="dns-prefetch" href="https://api.example.com" />

<!-- Preconnect for critical third-parties -->
<link rel="preconnect" href="https://fonts.googleapis.com" />

<!-- Preload critical resources -->
<link rel="preload" href="/fonts/inter.woff2" as="font" type="font/woff2" crossorigin />

<!-- Prefetch for likely navigation -->
<link rel="prefetch" href="/dashboard" />

<!-- Prerender entire page (Chrome) -->
<link rel="prerender" href="/likely-next-page" />
```

### Script Loading

```html
<!-- Default: Blocks parsing -->
<script src="blocking.js"></script>

<!-- Async: Download parallel, execute when ready -->
<script async src="analytics.js"></script>

<!-- Defer: Download parallel, execute after parsing -->
<script defer src="app.js"></script>

<!-- Module: Deferred by default -->
<script type="module" src="app.js"></script>
```

### Font Loading

```css
/* Font display strategies */
@font-face {
  font-family: 'Inter';
  src: url('/fonts/inter.woff2') format('woff2');
  font-display: swap;  /* Show fallback, swap when loaded */
  /* font-display: optional; */  /* Only use if cached */
}
```

```javascript
// Preload critical fonts
<link
  rel="preload"
  href="/fonts/inter.woff2"
  as="font"
  type="font/woff2"
  crossorigin
/>
```

## Caching Strategies

### Service Worker Caching

```javascript
// sw.js
const CACHE_NAME = 'v1';
const ASSETS = ['/index.html', '/app.js', '/styles.css'];

self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(CACHE_NAME)
      .then(cache => cache.addAll(ASSETS))
  );
});

self.addEventListener('fetch', (event) => {
  event.respondWith(
    caches.match(event.request)
      .then(response => response || fetch(event.request))
  );
});
```

### HTTP Caching Headers

```
# Immutable assets (hashed filenames)
Cache-Control: public, max-age=31536000, immutable

# HTML pages
Cache-Control: no-cache

# API responses
Cache-Control: private, max-age=60

# Static assets
Cache-Control: public, max-age=86400
```

### SWR / React Query Caching

```javascript
import useSWR from 'swr';

function Profile() {
  const { data, error, isLoading } = useSWR('/api/user', fetcher, {
    revalidateOnFocus: false,
    revalidateOnReconnect: false,
    dedupingInterval: 60000,  // Dedupe requests within 1 minute
  });

  if (isLoading) return <Loading />;
  if (error) return <Error />;
  return <div>{data.name}</div>;
}
```

## Monitoring

### Performance Observer

```javascript
// Observe long tasks
const observer = new PerformanceObserver((list) => {
  for (const entry of list.getEntries()) {
    console.log('Long task:', entry.duration);
  }
});
observer.observe({ entryTypes: ['longtask'] });

// Observe LCP
new PerformanceObserver((entryList) => {
  const entries = entryList.getEntries();
  const lastEntry = entries[entries.length - 1];
  console.log('LCP:', lastEntry.startTime);
}).observe({ type: 'largest-contentful-paint', buffered: true });

// Observe layout shifts
new PerformanceObserver((entryList) => {
  for (const entry of entryList.getEntries()) {
    if (!entry.hadRecentInput) {
      console.log('CLS:', entry.value);
    }
  }
}).observe({ type: 'layout-shift', buffered: true });
```

### Navigation Timing

```javascript
window.addEventListener('load', () => {
  const timing = performance.getEntriesByType('navigation')[0];

  console.log({
    dns: timing.domainLookupEnd - timing.domainLookupStart,
    tcp: timing.connectEnd - timing.connectStart,
    ttfb: timing.responseStart - timing.requestStart,
    download: timing.responseEnd - timing.responseStart,
    domParsing: timing.domInteractive - timing.responseEnd,
    domComplete: timing.domComplete - timing.domInteractive,
    total: timing.loadEventEnd - timing.startTime,
  });
});
```

### Real User Monitoring (RUM)

```javascript
// Send metrics to analytics
function sendMetrics(metrics) {
  navigator.sendBeacon('/analytics', JSON.stringify(metrics));
}

// Collect on page hide
document.addEventListener('visibilitychange', () => {
  if (document.visibilityState === 'hidden') {
    sendMetrics(collectedMetrics);
  }
});
```

## Quick Wins Checklist

### Critical Path
- [ ] Inline critical CSS
- [ ] Defer non-critical JS
- [ ] Preload key resources (fonts, LCP image)
- [ ] Remove render-blocking resources

### Images
- [ ] Use modern formats (WebP, AVIF)
- [ ] Implement lazy loading
- [ ] Add width/height attributes
- [ ] Serve responsive images

### JavaScript
- [ ] Code split by route
- [ ] Tree shake unused code
- [ ] Minify and compress
- [ ] Use production builds

### Caching
- [ ] Set appropriate cache headers
- [ ] Use hashed filenames for assets
- [ ] Implement service worker
- [ ] Use CDN for static assets

### Fonts
- [ ] Use font-display: swap
- [ ] Preload critical fonts
- [ ] Subset fonts to used characters
- [ ] Self-host for control
