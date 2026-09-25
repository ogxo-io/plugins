# Troubleshooting Guide for Git Commit Generator

Common issues and solutions when generating commit messages.

## Pre-Commit Validation: Tool Detection and Commands

Full catalog for Step 1 of the workflow — detect the project's linting/formatting tools and run what exists before generating a message.

### Detection Priority

Check for tooling in this order and use the first that applies:

1. **Makefile** with `lint`, `format`, `check`, or `test` targets
2. **package.json** with lint/format/test scripts
3. **Language-specific** config files (`.eslintrc*`, `.prettierrc*`, `pyproject.toml`, `.golangci.yml`)
4. **Pre-commit hooks** (`.pre-commit-config.yaml`, `.git/hooks/pre-commit`)

Respect the project's preferred tooling — don't invoke `eslint` directly when `npm run lint` exists.

### Detect Project Configuration

```bash
# Makefile lint/format targets
if [ -f Makefile ]; then
  grep -E "^(lint|format|check|test):" Makefile
fi

# package.json scripts
if [ -f package.json ]; then
  cat package.json | grep -A5 '"scripts"' | grep -E '"(lint|format|test)"'
fi

# Pre-commit configuration
ls -la .pre-commit-config.yaml .git/hooks/pre-commit

# Language-specific configs
ls -la .eslintrc* .prettierrc* pyproject.toml .golangci.yml
```

### Run Project-Defined Commands

**Makefile (highest priority):**
```bash
make lint
make format
make check
make test
```

**package.json scripts:**
```bash
npm run lint          # or yarn lint
npm run format        # or yarn format
npm run format:check  # or yarn format:check
npm test              # or yarn test
```

### Language-Specific Tools

Use these only when no project-defined command exists.

**JavaScript/TypeScript:**
```bash
eslint .              # Linting
prettier --check .    # Format checking
```

**Python:**
```bash
black --check .       # Formatting
flake8                # Linting
pylint                # Advanced linting
mypy                  # Type checking
```

**Go:**
```bash
gofmt -l .            # Check formatting
golint ./...          # Linting
go vet ./...          # Static analysis
```

**Rust:**
```bash
cargo fmt --check     # Formatting check
cargo clippy          # Linting
```

### Pre-Commit Hooks

```bash
# pre-commit framework
pre-commit run --all-files

# Native git hook
if [ -x .git/hooks/pre-commit ]; then
  .git/hooks/pre-commit
fi
```

---

## Lint/Format Checks Failing

**Issue:** Code quality checks fail before commit

**Solutions:**

1. **Identify the tool**: Check what's failing (ESLint, Prettier, Black, etc.)

2. **Auto-fix if available**:
   ```bash
   # JavaScript/TypeScript
   npm run lint:fix       # or eslint --fix .
   npm run format         # or prettier --write .

   # Python
   black .                # Auto-format
   autopep8 --in-place --recursive .

   # Go
   gofmt -w .             # Auto-format
   go fmt ./...

   # Rust
   cargo fmt              # Auto-format
   ```

3. **Manual fixes**: If auto-fix doesn't resolve all issues, fix manually

4. **Check configuration**: Ensure lint/format configs are correct

5. **Staged files only**: Some tools can check only staged files:
   ```bash
   # Check only staged files
   git diff --staged --name-only | xargs eslint
   git diff --staged --name-only | xargs prettier --check
   ```

**Important**: Do NOT proceed with commit message generation until all quality checks pass.

---

## Script Not Running

**Issue:** `python3 ${CLAUDE_PLUGIN_ROOT}/skills/git-commit-generator/scripts/analyze_changes.py` fails

**Solutions:**
- Check Python 3 is installed: `python3 --version`
- Verify script permissions: `chmod +x ${CLAUDE_PLUGIN_ROOT}/skills/git-commit-generator/scripts/analyze_changes.py`
- Run from skill directory or use absolute path
- Fall back to manual git commands if script unavailable

**Fallback commands:**
```bash
# Get staged files
git diff --staged --name-only

# Get file statistics
git diff --staged --stat

# View actual changes
git diff --staged
```

---

## Unclear Changes

**Issue:** Diff is large or complex, hard to summarize

**Solutions:**

1. **Ask user**: "Can you describe what these changes accomplish?"

2. **Review file names and structure** for clues:
   - Test files often reveal intended behavior
   - Component/module names suggest functionality
   - Config changes indicate what's being configured

3. **Check test files** for intended behavior:
   ```bash
   git diff --staged -- '*.test.*' '*.spec.*'
   ```

4. **Suggest splitting into smaller commits**:
   - "These changes touch multiple areas. Would you like to split them into separate commits?"
   - Use `git add -p` for interactive staging

5. **Focus on file groups**:
   - Group related files together
   - Summarize by feature/component
   - Prioritize what changed over how

---

## Style Conflicts

**Issue:** Recent commits don't follow conventional commits format

**Solutions:**

1. **Still generate conventional commits** (project may be transitioning):
   - Explain: "I'll use conventional commits format as it's a best practice"
   - Offer to match existing style if user prefers

2. **Ask user for preference**:
   - "Should I follow the conventional commits format, or match the existing style?"
   - Show example of both styles

3. **Explain benefits** if user is open:
   - Automated changelog generation
   - Semantic versioning automation
   - Better commit history searchability
   - Standard tooling support

4. **Hybrid approach**:
   - Use conventional format as primary
   - Add additional context in body if needed

---

## Missing Context

**Issue:** Changes are clear but motivation is unclear

**Solutions:**

1. **Ask targeted questions**:
   - "What problem does this solve?"
   - "Why was this change needed?"
   - "What's the business/technical reason for this?"

2. **Review related issues or PR descriptions** if available:
   ```bash
   # Check branch name for issue reference
   git branch --show-current

   # Look for issue mentions in recent commits
   git log --grep="#[0-9]" -5
   ```

3. **Make educated guess with caveat**:
   - "If this adds OAuth support, then..."
   - "Assuming this fixes authentication issues..."
   - Always note uncertainty and ask for confirmation

4. **Focus on observable effects**:
   - What will work differently after this commit?
   - What capabilities are being added/changed/removed?

---

## GPG Signing Issues

**Issue:** Commit fails due to GPG signing requirements

**Solutions:**

1. **Respect GPG requirements**:
   - NEVER use `--no-gpg-sign` to bypass
   - NEVER use `--no-verify` to skip hooks
   - Follow user's CLAUDE.md instructions

2. **Let the user commit**: present the generated message and ask the user to stage and commit themselves so their GPG signature is applied. Do not run `git add` on their behalf.

3. **Check GPG configuration**:
   ```bash
   git config commit.gpgsign
   # If true, GPG signing is required
   ```

4. **Provide the commit message** for user to apply:
   - Display the generated message
   - User runs: `git commit -m "your message"`
   - This preserves their GPG workflow

---

## Pre-commit Hook Failures

**Issue:** Pre-commit hooks block the commit

**Common hook failures:**
- Linting/formatting checks
- Test failures
- Security scans
- License checks
- Commit message format validation

**Solutions:**

1. **Fix the underlying issue** (preferred):
   - Run the failing check manually
   - Address the problems
   - Re-attempt commit

2. **Understand what's failing**:
   ```bash
   # Pre-commit hooks are usually in:
   .git/hooks/pre-commit
   .husky/pre-commit
   ```

3. **Don't bypass hooks** — don't pass `--no-verify` yourself:
   - Hooks exist for good reasons
   - Bypassing can break CI/CD
   - May violate team policies

4. **If hook is broken/misconfigured**:
   - Report which hook fails and why
   - Help fix the hook
   - Let the user decide how to proceed

---

## Large Diffs

**Issue:** Changes are too large to analyze effectively

**Solutions:**

1. **Suggest focused commits**:
   - "This diff is quite large. Would you like to split it into multiple focused commits?"
   - Helps with code review and bisection

2. **Use `git add -p`** for interactive staging:
   ```bash
   git add -p [file]
   # Stage hunks interactively
   ```

3. **Group by concern**:
   - Refactoring vs. new features
   - Tests vs. implementation
   - Formatting vs. logic changes

4. **Summarize at higher level**:
   - Focus on modules/components changed
   - List major changes only
   - Detail in commit body, not subject

---

## Conflicting Change Types

**Issue:** Staged changes include multiple types (feat + fix + refactor)

**Solutions:**

1. **Recommend splitting** (preferred):
   - Each commit should have one primary type
   - Easier to review and revert
   - Better for changelog generation

2. **If user wants single commit**:
   - Use the dominant/most important type
   - Mention other types in commit body
   - Example: `feat(auth): add OAuth support`
     ```
     Body:
     - Refactored existing auth flow
     - Fixed session timeout bug
     - Added OAuth provider integration
     ```

3. **Prioritize user-facing changes**:
   - `feat` > `fix` > `refactor` > `chore`
   - Breaking changes always mentioned in footer

---

## Getting Help

If you encounter issues not covered here:

1. **Check commit-guidelines.md** for format details
2. **Review examples.md** for sample commit messages
3. **Ask user** for clarification or preferences
4. **Fall back to manual** git commands if scripts fail

Remember: **Generating a good commit message is more important than following the exact workflow**. Adapt as needed while maintaining quality.
