#!/usr/bin/env node
/**
 * Universal Playwright Executor for Claude Code
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

// Dependencies live in a writable per-user directory: BROWSER_TESTING_HOME (set by the
// skill to ${CLAUDE_PLUGIN_DATA}/browser-testing), else ${CLAUDE_PLUGIN_DATA}/browser-testing,
// else ~/.cache/ogxo-browser-testing. Never the plugin copy, which updates replace.
const SKILL_DIR = path.join(__dirname, '..');
const ORIG_CWD = process.cwd();
const HOME = process.env.BROWSER_TESTING_HOME
  || (process.env.CLAUDE_PLUGIN_DATA && path.join(process.env.CLAUDE_PLUGIN_DATA, 'browser-testing'))
  || path.join(os.homedir(), '.cache', 'ogxo-browser-testing');
// Wrapped scripts are written to the OS temp directory.
const TEMP_DIR = path.join(os.tmpdir(), 'ogxo-browser-testing');
fs.mkdirSync(HOME, { recursive: true });
fs.mkdirSync(TEMP_DIR, { recursive: true });
process.env.NODE_PATH = [path.join(HOME, 'node_modules'), process.env.NODE_PATH].filter(Boolean).join(path.delimiter);
require('module').Module._initPaths();
process.chdir(HOME);

/**
 * Check if Playwright is installed
 */
function checkPlaywrightInstalled() {
  try {
    require.resolve('playwright');
    return true;
  } catch (e) {
    return false;
  }
}

/**
 * Report a missing Playwright install. The runner does not install anything itself:
 * setup downloads packages and a browser build, which the user should agree to first.
 */
function reportMissingPlaywright() {
  console.error('❌ Playwright is not installed in', HOME);
  console.error('Run the Setup block in the browser-testing SKILL.md (npm ci + a Chromium download into that directory) after the user agrees.');
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

  // Check Playwright installation
  if (!checkPlaywrightInstalled()) {
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
