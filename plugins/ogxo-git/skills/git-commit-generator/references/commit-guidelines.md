# Commit Message Guidelines

This reference provides comprehensive guidelines for writing effective commit messages following the Conventional Commits specification with project-specific enhancements.

## Conventional Commits Format

```
<type>(<scope>): <description>

[optional body]

[optional footer(s)]
```

### Commit Types

- **feat**: A new feature for the user
- **fix**: A bug fix
- **docs**: Documentation only changes
- **style**: Changes that don't affect code meaning (white-space, formatting, missing semi-colons, etc.)
- **refactor**: Code change that neither fixes a bug nor adds a feature
- **perf**: Code change that improves performance
- **test**: Adding missing tests or correcting existing tests
- **build**: Changes affecting the build system or external dependencies
- **ci**: Changes to CI configuration files and scripts
- **chore**: Other changes that don't modify src or test files
- **revert**: Reverts a previous commit

### Scope Guidelines

The scope should be a noun describing the section of the codebase affected:

**Frontend/UI:**
- `ui`, `components`, `styles`, `layouts`, `forms`

**Backend/API:**
- `api`, `auth`, `database`, `models`, `services`, `controllers`

**Infrastructure:**
- `docker`, `ci`, `deploy`, `config`, `build`

**Features/Modules:**
- Use specific feature names: `user-management`, `payments`, `analytics`

**Examples:**
- `feat(auth): add JWT token refresh mechanism`
- `fix(database): resolve connection pool exhaustion`
- `docs(api): update endpoint documentation`

## Writing Style

### Subject Line (Description)

**DO:**
- Use imperative mood: "add feature" not "added feature" or "adds feature"
- Keep under 50 characters (72 max)
- Match the case of the repo's recent commit subjects (lowercase if there's no clear convention)
- Don't end with a period
- Be specific and descriptive

**DON'T:**
- Use vague descriptions: "update", "fix stuff", "changes"
- Include technical implementation details
- Write complete sentences
- Use past tense

**Examples:**

✅ Good:
- `feat(auth): add OAuth2 integration with Google`
- `fix(api): handle null values in user profile endpoint`
- `refactor(database): extract query logic into repository pattern`

❌ Bad:
- `feat(auth): added some auth stuff`
- `fix: fixed a bug`
- `update: updated the code.`

### Body

The body should explain:
- **WHY** the change was made (motivation)
- **WHAT** the impact is (user-facing or system changes)
- **HOW** (if complex or non-obvious)

**Format:**
- Separate from subject with a blank line
- Wrap at 72 characters
- Use bullet points for multiple changes
- Be concise but complete

**Example:**
```
refactor(auth): extract authentication logic into service layer

Moves authentication logic from controllers to dedicated service class:
- Improves testability by isolating business logic
- Reduces controller complexity
- Makes it easier to add new auth methods
- Prepares codebase for upcoming OAuth implementation

This change maintains backward compatibility with existing endpoints.
```

### Footer

Use footers for:
- **Breaking changes**: `BREAKING CHANGE: description`
- **Issue references**: `Closes #123`, `Fixes #456`, `Related to #789`
- **Reviewers**: `Reviewed-by: Name <email>`
- **Co-authors**: `Co-authored-by: Name <email>` (only when explicitly requested)

**Example:**
```
feat(api)!: restructure response format to match JSON:API spec

BREAKING CHANGE: All API responses now follow JSON:API specification

Previous format: { "data": {...}, "status": "ok" }
New format: { "data": {...}, "meta": {...} }

Migration guide: Update client code to parse new response structure.

Closes #234
```

## Breaking Changes

Indicate breaking changes in two ways:
1. Add `!` after type/scope: `feat(api)!:`
2. Add `BREAKING CHANGE:` footer with description

Always include:
- What changed
- Why it changed
- How to migrate

## Project-Specific Rules

### Issue-Key Integration

When working on a branch with an issue-key prefix (e.g., `PROJ-123-feature`):
- Extract the issue number from the branch name
- **DO NOT** automatically add it to commit messages
- Only add issue reference if explicitly requested by user

### Co-Author Attribution

**IMPORTANT**: Never automatically add co-author attribution.
- Only add `Co-authored-by:` when explicitly requested by the user
- Format: `Co-authored-by: Name <email>`

### File Filtering

When generating commit messages:
- Only include staged files in the analysis
- Ignore unstaged changes
- Don't mention untracked files unless relevant
- If staged files include planning or scratch artifacts (`plan.md`, task notes), point them out before committing

## Commit Message Examples

### Feature Addition

```
feat(payments): add Stripe integration for credit card processing

Implements Stripe payment gateway with support for:
- Credit card tokenization
- Recurring subscriptions
- Webhook handling for payment events
- PCI compliance through hosted checkout

Closes #456
```

### Bug Fix

```
fix(auth): prevent session fixation vulnerability

Regenerate session ID after successful login to prevent
session fixation attacks. This follows OWASP recommendations
for secure session management.

Fixes #789
```

### Refactoring

```
refactor(database): migrate to repository pattern

Extracts database queries from controllers into repository classes:
- UserRepository for user data operations
- OrderRepository for order management
- Improves testability with interface-based design
- Reduces code duplication across controllers

No user-facing changes. All tests passing.
```

### Documentation

```
docs(readme): add installation instructions for Docker setup

Includes step-by-step guide for:
- Docker Compose configuration
- Environment variable setup
- Database initialization
- Common troubleshooting steps
```

### Multiple Files

```
feat(dashboard): add real-time analytics visualization

Implements live dashboard with WebSocket updates:
- Chart.js integration for data visualization
- WebSocket connection for real-time data
- Responsive layout for mobile devices
- Export functionality (CSV/JSON)

Changes:
- frontend/components/Dashboard.js (new component)
- frontend/services/WebSocketService.js (new service)
- backend/websocket/analytics.js (new handler)
- styles/dashboard.css (new styles)

Closes #123
```

### Configuration Changes

```
chore(ci): update Node.js version to 20 LTS

Updates GitHub Actions workflow to use Node.js 20:
- Improves build performance
- Access to new language features
- Extends support timeline (LTS until 2026)
```

## Multi-File Commit Strategy

### Atomic Commits

Each commit should represent one logical change:
- Related changes grouped together
- Unrelated changes in separate commits
- Tests included with feature/fix
- Documentation updated in same commit

### When to Split

Create separate commits when:
- Changes are independent (can be deployed separately)
- Different types (feat vs refactor vs docs)
- Different scopes (auth vs payments)
- Large refactoring + new features

### When to Group

Group changes when:
- All changes support one feature
- Fix requires test updates
- Feature requires config changes
- Documentation describes the new code

## Commit Message Checklist

Before finalizing a commit message, verify:

- [ ] Type is appropriate and accurate
- [ ] Scope is specific and meaningful
- [ ] Subject is under 50 characters
- [ ] Subject uses imperative mood
- [ ] Subject description case matches repo history (lowercase if no clear convention), no period
- [ ] Body explains WHY, not just WHAT
- [ ] Breaking changes are clearly marked
- [ ] Issue numbers included (if applicable)
- [ ] No co-author unless explicitly requested
- [ ] Only staged files mentioned
- [ ] Description accurately reflects changes

## Common Mistakes to Avoid

1. **Vague descriptions**: "update code", "fix things", "changes"
2. **Wrong tense**: "added" instead of "add"
3. **Too long**: Subject lines over 72 characters
4. **No context**: Missing body for complex changes
5. **Mixing changes**: Unrelated changes in one commit
6. **Missing type**: No conventional commit prefix
7. **Auto co-authors**: Adding co-authors without request
8. **Including unstaged**: Mentioning files not staged

## Tips for Better Commits

1. **Review changes first**: Use `git diff --staged` before writing
2. **Follow patterns**: Check recent commits for consistency
3. **Be specific**: Name exact components/functions affected
4. **Explain impact**: How does this help users/developers?
5. **Test first**: Ensure code works before committing
6. **Keep focused**: One logical change per commit
7. **Think future**: Will you understand this in 6 months?
