# Investigation Commands

Command recipes for codebase archaeology. Adjust patterns to the project's languages. Read this when you reach the corresponding workflow step.

## Survey the Landscape

```bash
# What is this project?
cat README.md 2>/dev/null | head -50
cat package.json go.mod Cargo.toml pyproject.toml setup.py 2>/dev/null | head -40

# How old / how active?
git log --reverse --format="%ai %s" | head -5   # first commits
git log --format="%ai" | head -1                # last commit
git shortlog -sn --all | head -10               # top contributors

# Structure and file-type distribution
find . -type d -not -path '*/node_modules/*' -not -path '*/.git/*' -not -path '*/vendor/*' -maxdepth 3 | sort
find . -type f -not -path '*/node_modules/*' -not -path '*/.git/*' | sed 's/.*\.//' | sort | uniq -c | sort -rn | head -15
```

## Entry Points and Public API

```bash
# Entry points
grep -r '"main"\|"start"\|"scripts"' package.json 2>/dev/null
ls -la index.* server.js app.js main.py manage.py wsgi.py main.go cmd/*/main.go 2>/dev/null
grep -i "entrypoint\|cmd" Dockerfile 2>/dev/null

# HTTP routes / endpoints
grep -rn "app\.\(get\|post\|put\|delete\|patch\)\|@app\.route\|router\.\(get\|post\)" --include="*.py" --include="*.js" --include="*.ts" | head -30

# Exported surface
grep -rn "^export\|module\.exports\|^pub fn\|^pub struct\|^def " --include="*.ts" --include="*.js" --include="*.rs" --include="*.py" | head -30

# Environment + config
grep -rn "process\.env\|os\.environ\|os\.Getenv\|env::" --include="*.ts" --include="*.js" --include="*.py" --include="*.go" | head -20
ls -la .env.example .env.sample config/ *.config.* 2>/dev/null
```

## Git History Archaeology

```bash
# Churn hotspots (most-changed files)
git log --format=format: --name-only --since="6 months ago" | sort | uniq -c | sort -rn | head -20

# Why does this code exist?
git blame -L <start>,<end> <file>
git log -p --follow -S '<search-string>' -- <file>   # when a string appeared/disappeared

# When was a pattern introduced?
git log --all --oneline -S '<code-pattern>' | tail -5

# Explanatory messages and PR context
git log --all --grep='<keyword>' --oneline | head -10
git log --merges --oneline -- <directory>/ | head -10
```

## Dependency Mapping

```bash
# Internal: who imports what
grep -rn "import\|require\|from " --include="*.ts" --include="*.js" --include="*.py" <directory>/ | head -30
grep -rn "from.*<module>\|require.*<module>\|import.*<module>" --include="*.ts" --include="*.js" --include="*.py"

# External dependencies
cat package.json | grep -A 100 '"dependencies"' | head -30
cat requirements.txt 2>/dev/null | head -20
cat go.mod 2>/dev/null | grep -v "^//" | head -20
npm outdated 2>/dev/null || pip list --outdated 2>/dev/null | head -20
```

## Finding Dead Code

```bash
# Exports and their references
grep -rn "^export " --include="*.ts" --include="*.js" -l    # then grep each name for imports
npx depcheck 2>/dev/null                                    # unused npm dependencies
```

Assign confidence:
- **HIGH dead**: no imports, no tests, no git activity for 1+ year
- **MEDIUM dead**: no direct imports, but may be reached via reflection, dynamic import, or CLI
- **LOW dead**: imported only by code that is itself possibly dead (transitive)

## Reading Archaeology Signals

| Signal | What it tells you |
|--------|-------------------|
| Large `TODO`/`FIXME` comments | Known debt, often with context |
| `HACK`/`WORKAROUND` | Constraints that forced a non-ideal solution |
| Commented-out code blocks | Toggles or abandoned experiments |
| Multiple similar implementations | Failed refactor or in-progress migration |
| Inconsistent patterns in one codebase | Different authors or evolving standards |
| Tests marked `skip`/`pending` | Known-broken or incomplete features |
| `@deprecated` annotations | Planned removal — check whether consumers migrated |

**Naming conventions to infer:** file casing (kebab/camel/snake/Pascal), structure (by feature/layer/domain), function naming (verb-noun, is/has for booleans), class suffixes (Service, Controller, Repository, Handler, Factory).
