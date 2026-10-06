#!/usr/bin/env node
/**
 * Universal Playwright Executor
 *
 * Executes Playwright automation code from:
 * - File path: node run.js script.js
 * - Inline code: node run.js 'await page.goto("...")'
 * - Stdin: cat script.js | node run.js
 *
 * Resolves modules from BROWSER_TESTING_HOME (the plugin data dir) and writes wrapped scripts to the OS temp
 * directory, so the runner itself writes nothing into the plugin copy.
 */

const fs = require('fs');
const os = require('os');
const path = require('path');
const { spawnSync } = require('child_process');

// Dependencies live in a writable per-user directory: BROWSER_TESTING_HOME (passed by the
// skill), else PLUGIN_DATA/browser-testing, else ${XDG_CACHE_HOME:-~/.cache}/ogxo-debug/browser-testing.
// CLAUDE_PLUGIN_DATA is deliberately never read: it can point at another plugin's data dir.
// A BROWSER_TESTING_HOME of just "/browser-testing" is what an unfilled
// `${CLAUDE_PLUGIN_DATA}/browser-testing` expands to outside Claude Code; it is ignored.
// Never the plugin copy, which updates replace.
const SKILL_DIR = path.join(__dirname, '..');
const ORIG_CWD = process.cwd();
const explicitHome = process.env.BROWSER_TESTING_HOME;
const HOME = (explicitHome && explicitHome !== '/browser-testing' && explicitHome)
  || (process.env.PLUGIN_DATA && path.join(process.env.PLUGIN_DATA, 'browser-testing'))
  || path.join(process.env.XDG_CACHE_HOME || path.join(os.homedir(), '.cache'), 'ogxo-debug', 'browser-testing');
// Wrapped scripts are written to the OS temp directory.
const TEMP_DIR = path.join(os.tmpdir(), 'ogxo-browser-testing');
fs.mkdirSync(HOME, { recursive: true });
fs.mkdirSync(TEMP_DIR, { recursive: true });
process.env.NODE_PATH = [path.join(HOME, 'node_modules'), process.env.NODE_PATH].filter(Boolean).join(path.delimiter);
require('module').Module._initPaths();
process.chdir(HOME);

/**
 * Where Playwright comes from, in order: HOME (the plugin data dir), then the project
 * the runner was started in (its `playwright` or `@playwright/test`, when that version's
 * Chromium is downloaded), then a one-time install into HOME. Returns false when none works.
 */
function chromiumReady(mod) {
  try {
    const exe = require(mod).chromium.executablePath();
    return Boolean(exe) && fs.existsSync(exe);
  } catch (e) {
    return false;
  }
}

function homePlaywright() {
  try {
    return require.resolve('playwright', { paths: [HOME] });
  } catch (e) {
    return null;
  }
}

function projectPlaywright() {
  for (const name of ['playwright', '@playwright/test']) {
    let mod;
    try {
      mod = require.resolve(name, { paths: [ORIG_CWD] });
    } catch (e) {
      continue;
    }
    if (chromiumReady(mod)) return { name, mod };
  }
  return null;
}

// Scripts call require('playwright'); point that at the project's copy. @playwright/test
// re-exports the same API (chromium, firefox, webkit, devices) plus test and expect.
function aliasPlaywright(mod) {
  const Module = require('module');
  const resolve = Module._resolveFilename;
  Module._resolveFilename = function (request, ...rest) {
    if (request === 'playwright') return mod;
    return resolve.call(this, request, ...rest);
  };
}

function sleep(ms) {
  Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, ms);
}

function run(cmd, args) {
  console.error(`$ ${cmd} ${args.join(' ')}`);
  const r = spawnSync(cmd, args, { cwd: HOME, stdio: ['ignore', 2, 2], shell: process.platform === 'win32' });
  return r.status === 0;
}

/**
 * One-time install of the pinned Playwright and Chromium into HOME. A lock directory
 * keeps parallel runs from installing twice: a second run waits for the first. Set
 * BROWSER_TESTING_NO_INSTALL=1 to report instead of installing.
 */
function install() {
  if (process.env.BROWSER_TESTING_NO_INSTALL === '1') return false;
  const lock = path.join(HOME, '.installing');
  const deadline = Date.now() + 15 * 60 * 1000;
  for (;;) {
    try {
      fs.mkdirSync(lock);
      break;
    } catch (e) {
      if (e.code !== 'EEXIST') return false;
      let age = 0;
      try { age = Date.now() - fs.statSync(lock).mtimeMs; } catch (_) { continue; }
      if (age > 15 * 60 * 1000) { fs.rmSync(lock, { recursive: true, force: true }); continue; }
      if (Date.now() > deadline) return false;
      console.error('⏳ Another run is installing Playwright; waiting...');
      sleep(5000);
      if (homePlaywright() && chromiumReady(homePlaywright())) return true;
    }
  }
  try {
    console.error(`📦 Installing Playwright and Chromium into ${HOME} (one time, downloads a browser build; BROWSER_TESTING_NO_INSTALL=1 skips this).`);
    if (!homePlaywright()) {
      for (const f of ['package.json', 'package-lock.json']) fs.copyFileSync(path.join(SKILL_DIR, f), path.join(HOME, f));
      if (!run('npm', ['ci', '--no-audit', '--no-fund'])) return false;
    }
    const mod = homePlaywright();
    if (!mod) return false;
    if (!chromiumReady(mod) && !run('npx', ['playwright', 'install', 'chromium'])) return false;
    return chromiumReady(mod);
  } finally {
    fs.rmSync(lock, { recursive: true, force: true });
  }
}

function ensurePlaywright() {
  const home = homePlaywright();
  if (home && chromiumReady(home)) return true;
  const project = projectPlaywright();
  if (project) {
    console.log(`Using the project's Playwright (${project.name}) from ${path.dirname(project.mod)}`);
    aliasPlaywright(project.mod);
    return true;
  }
  return install();
}

/**
 * Report a missing Playwright install.
 */
function reportMissingPlaywright() {
  console.error('❌ Playwright is not available: not in', HOME, 'nor in the project at', ORIG_CWD);
  if (process.env.BROWSER_TESTING_NO_INSTALL === '1') {
    console.error('BROWSER_TESTING_NO_INSTALL=1 is set, so nothing was installed. Unset it, or run the Setup block in the browser-testing SKILL.md.');
  } else {
    console.error('The one-time install failed (see the npm or playwright output above). Fix that, or run the Setup block in the browser-testing SKILL.md.');
  }
}

/**
 * Get code to execute from various sources
 */
function getCodeToExecute() {
  const args = process.argv.slice(2);

  // Case 1: File path provided
  const candidate = args.length > 0 ? path.resolve(ORIG_CWD, args[0]) : null;
  if (candidate && fs.existsSync(candidate)) {
    const filePath = candidate;
    console.log(`📄 Executing file: ${filePath}`);
    return fs.readFileSync(filePath, 'utf8');
  }

  // Case 2: Inline code provided as argument
  if (args.length > 0) {
    console.log('⚡ Executing inline code');
    return args.join(' ');
  }

  // Case 3: Code from stdin
  if (!process.stdin.isTTY) {
    console.log('📥 Reading from stdin');
    return fs.readFileSync(0, 'utf8');
  }

  // No input
  console.error('❌ No code to execute');
  console.error('Usage:');
  console.error('  node run.js script.js          # Execute file');
  console.error('  node run.js "code here"        # Execute inline');
  console.error('  cat script.js | node run.js    # Execute from stdin');
  process.exit(1);
}

/**
 * Clean up old temporary execution files from previous runs
 */
function cleanupOldTempFiles() {
  try {
    const files = fs.readdirSync(TEMP_DIR);
    const tempFiles = files.filter(f => f.startsWith('.temp-execution-') && f.endsWith('.js'));

    if (tempFiles.length > 0) {
      tempFiles.forEach(file => {
        const filePath = path.join(TEMP_DIR, file);
        try {
          fs.unlinkSync(filePath);
        } catch (e) {
          // Ignore errors - file might be in use or already deleted
        }
      });
    }
  } catch (e) {
    // Ignore directory read errors
  }
}

/**
 * Wrap code in async IIFE if not already wrapped
 */
function wrapCodeIfNeeded(code) {
  // Check if code already has require() and async structure
  const hasRequire = code.includes('require(');
  const hasAsyncIIFE = code.includes('(async () => {') || code.includes('(async()=>{');

  // If it's already a complete script, return as-is
  if (hasRequire && hasAsyncIIFE) {
    return code;
  }

  // If it's just Playwright commands, wrap in full template
  if (!hasRequire) {
    return `
const { chromium, firefox, webkit, devices } = require('playwright');
const helpers = require(${JSON.stringify(path.join(SKILL_DIR, 'lib', 'helpers'))});

(async () => {
  try {
    ${code}
  } catch (error) {
    console.error('❌ Automation error:', error.message);
    if (error.stack) {
      console.error(error.stack);
    }
    process.exit(1);
  }
})();
`;
  }

  // If has require but no async wrapper
  if (!hasAsyncIIFE) {
    return `
(async () => {
  try {
    ${code}
  } catch (error) {
    console.error('❌ Automation error:', error.message);
    if (error.stack) {
      console.error(error.stack);
    }
    process.exit(1);
  }
})();
`;
  }

  return code;
}

/**
 * Main execution
 */
async function main() {
  console.log('🎭 Playwright Skill - Universal Executor\n');

  // Clean up old temp files from previous runs
  cleanupOldTempFiles();

  // Find or install Playwright
  if (!ensurePlaywright()) {
    reportMissingPlaywright();
    process.exit(1);
  }

  // Get code to execute
  const rawCode = getCodeToExecute();
  const code = wrapCodeIfNeeded(rawCode);

  // Create temporary file for execution
  const tempFile = path.join(TEMP_DIR, `.temp-execution-${Date.now()}.js`);

  try {
    // Write code to temp file
    fs.writeFileSync(tempFile, code, 'utf8');

    // Execute the code
    console.log('🚀 Starting automation...\n');
    require(tempFile);

    // Note: Temp file will be cleaned up on next run
    // This allows long-running async operations to complete safely

  } catch (error) {
    console.error('❌ Execution failed:', error.message);
    if (error.stack) {
      console.error('\n📋 Stack trace:');
      console.error(error.stack);
    }
    process.exit(1);
  }
}

// Run main function
main().catch(error => {
  console.error('❌ Fatal error:', error.message);
  process.exit(1);
});
