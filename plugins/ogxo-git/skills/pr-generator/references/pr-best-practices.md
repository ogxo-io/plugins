# Pull Request Best Practices

This reference provides comprehensive guidelines for creating effective pull requests that are easy to review, understand, and merge.

## PR Title Format

### Conventional Format

Follow the Conventional Commits format for PR titles:

```
<type>(<scope>): <description>
```

Or with an issue key:

```
[PROJ-123] <type>(<scope>): <description>
```

### Title Components

**Type** - Indicates the nature of changes:
- `feat` - New feature
- `fix` - Bug fix
- `refactor` - Code restructuring
- `perf` - Performance improvement
- `docs` - Documentation only
- `style` - Code style/formatting
- `test` - Test additions/updates
- `build` - Build system changes
- `ci` - CI/CD changes
- `chore` - Maintenance tasks

**Scope** (optional) - Component/module affected:
- Use specific names: `auth`, `api`, `database`, `ui`
- Can be omitted for broad changes

**Description** - Brief summary:
- Use imperative mood: "add feature" not "added feature"
- Keep under 50 characters
- Be specific and descriptive
- Match the case of the repo's recent commit/PR titles (lowercase if there's no clear convention)
- No period at the end

### Title Examples

✅ **Good titles:**
- `feat(auth): add OAuth2 integration with Google`
- `[PROJ-456] fix(api): prevent null pointer in user endpoint`
- `refactor(database): migrate to repository pattern`
- `docs: update API documentation for v2 endpoints`

❌ **Bad titles:**
- `Update stuff` (too vague)
- `Fix bug` (not specific)
- `[PROJ-123] Updated the authentication system.` (past tense, period)
- `feat: This PR adds a new feature for users` (too verbose)

## PR Description Structure

### Essential Sections

Every PR description should include:

#### 1. Summary/Overview

Brief explanation of what the PR does and why:

```markdown
## Summary

This PR implements JWT-based authentication to replace the current
session-based auth system. This change improves API security and
enables stateless authentication for mobile clients.
```

**Guidelines:**
- 2-3 sentences maximum
- Focus on the "what" and "why"
- Mention user-facing impact if applicable

#### 2. Changes

Detailed breakdown of what changed:

```markdown
## Changes

- Add JWT token generation on successful login
- Implement token validation middleware for protected routes
- Add token refresh endpoint for seamless re-authentication
- Update user service to support token-based auth
- Remove old session management code
```

**Guidelines:**
- Use bullet points for clarity
- Group related changes together
- Be specific about modified components
- Mention removed/deprecated code

#### 3. Test Plan

How to verify the changes work:

```markdown
## Test Plan

- [ ] Create new user account via `/auth/register`
- [ ] Login and verify JWT token in response
- [ ] Access protected endpoint with token
- [ ] Test token expiration (wait 1 hour)
- [ ] Verify token refresh mechanism
- [ ] Confirm old session auth no longer works
```

**Guidelines:**
- Use checkboxes for actionable items
- Include both positive and negative test cases
- Mention manual and automated tests
- Specify data/environment requirements

#### 4. Related Issues

Link to relevant tickets:

```markdown
## Related Issues

Closes #234
Fixes #456
Related to #789
```

**GitHub Keywords:**
- `Closes`, `Fixes`, `Resolves` - Automatically closes issue
- `Related to`, `See also` - Links without closing

**Issue References:**
- Include the issue key in the title: `[PROJ-123]`
- Can also mention in description body

### Optional Sections

Include these when relevant:

#### Breaking Changes

For backwards-incompatible changes:

```markdown
## ⚠️ Breaking Changes

**Authentication endpoints changed:**
- `POST /login` now returns JWT instead of session cookie
- Clients must include `Authorization: Bearer <token>` header
- Session endpoints `/session/*` are deprecated

**Migration steps:**
1. Update client to handle JWT tokens
2. Store token in secure storage (not localStorage)
3. Include token in Authorization header for all requests
```

#### Screenshots/Recordings

For UI changes:

```markdown
## Visual Changes

### Before
![Screenshot of old UI](url)

### After
![Screenshot of new UI](url)

### Demo
[Watch demo video](url)
```

#### Performance Impact

For performance-related changes:

```markdown
## Performance Impact

**Before:** Average response time: 450ms
**After:** Average response time: 120ms

Benchmark results:
- 73% reduction in database queries
- 60% faster page load time
- Memory usage reduced by 40%
```

#### Security Considerations

For security-related changes:

```markdown
## Security Considerations

- JWT tokens expire after 1 hour
- Refresh tokens stored securely with HTTP-only cookies
- Token signing uses RS256 algorithm
- No sensitive data included in token payload
- Rate limiting applied to auth endpoints
```

#### Deployment Notes

For changes requiring special deployment steps:

```markdown
## Deployment Notes

**Before deployment:**
1. Run database migration: `npm run migrate:up`
2. Update environment variables (see .env.example)
3. Generate new JWT secret: `openssl rand -hex 32`

**After deployment:**
1. Monitor error logs for auth failures
2. Verify token generation in production
3. Test mobile app authentication
```

## PR Size Guidelines

### Optimal PR Size

**Small to Medium (preferred):**
- **Lines changed:** 50-400
- **Files changed:** 1-10
- **Review time:** 15-30 minutes

**Large (acceptable):**
- **Lines changed:** 400-1000
- **Files changed:** 10-20
- **Review time:** 30-60 minutes

**Very Large (avoid):**
- **Lines changed:** 1000+
- **Files changed:** 20+
- **Review time:** 1+ hours

### When PRs Are Too Large

If your PR exceeds 1000 lines:

1. **Split into multiple PRs** - Group by logical functionality
2. **Create draft PRs** - For context before final review
3. **Add detailed documentation** - Help reviewers navigate
4. **Use PR chaining** - Series of dependent PRs

### Exception Cases

Large PRs are acceptable for:
- Major refactoring with automated tools
- Generated code (migrations, API clients)
- Initial project setup
- Dependency updates

## Reviewer Guidelines

### For PR Authors

**Make it easy to review:**
- Write clear, descriptive titles and descriptions
- Keep PRs focused on single logical change
- Add comments to complex code sections
- Respond promptly to review feedback
- Update PR description as changes evolve

**Before requesting review:**
- [ ] All tests passing locally
- [ ] Code follows project conventions
- [ ] No debug code or console.logs
- [ ] Documentation updated
- [ ] Self-review completed

## Common Mistakes

### Title Mistakes

❌ **Too vague:**
- "Update code"
- "Fix issue"
- "Changes"

❌ **Wrong tense:**
- "Added feature" (should be "add feature")
- "Fixed bug" (should be "fix bug")

❌ **Too detailed:**
- "This PR adds a new authentication system using JWT tokens with refresh mechanism"

### Description Mistakes

❌ **No context:**
```markdown
Made some changes to the auth system.
```

❌ **Just listing files:**
```markdown
Changed:
- auth.js
- user.js
- db.js
```

❌ **Missing test plan:**
```markdown
## Changes
Added new feature.

Please review.
```

### Content Mistakes

❌ **Mixing unrelated changes:**
- Feature + refactoring + dependency updates in one PR

❌ **No tests:**
- Code changes without corresponding test updates

❌ **Incomplete work:**
- Commented-out code
- TODOs left in code
- Debug statements

## PR Templates

### Feature PR Template

```markdown
## Summary
[Brief description of the feature and its purpose]

## Changes
- [Change 1]
- [Change 2]
- [Change 3]

## Test Plan
- [ ] [Test case 1]
- [ ] [Test case 2]
- [ ] [Test case 3]

## Screenshots (if applicable)
[Add screenshots or recordings]

## Related Issues
Closes #[issue-number]
```

### Bug Fix PR Template

```markdown
## Summary
[Brief description of the bug and the fix]

## Root Cause
[Explanation of what caused the bug]

## Solution
[How the fix addresses the root cause]

## Test Plan
- [ ] Reproduce original bug
- [ ] Verify fix resolves the issue
- [ ] Test edge cases
- [ ] Confirm no regression

## Related Issues
Fixes #[issue-number]
```

### Refactoring PR Template

```markdown
## Summary
[Brief description of the refactoring]

## Motivation
[Why this refactoring is needed]

## Changes
- [Structural change 1]
- [Structural change 2]
- [Structural change 3]

## Impact
- No functional changes
- Improved [performance/maintainability/readability]

## Test Plan
- [ ] All existing tests pass
- [ ] No behavioral changes
- [ ] Verified with [specific test scenarios]
```

## Example: Great PR Description

```markdown
[PROJ-234] feat(auth): add OAuth2 integration with Google

## Summary

This PR adds Google OAuth2 authentication as an alternative login method
for users. This enables users to sign in with their Google accounts,
reducing friction in the registration process and improving security.

## Changes

**Authentication:**
- Add OAuth2 client configuration for Google
- Implement OAuth2 callback handler
- Create user account linking logic
- Add Google sign-in button to login page

**Database:**
- Add `oauth_provider` and `oauth_id` columns to users table
- Create migration for new columns
- Update user model to support OAuth

**UI:**
- Add "Sign in with Google" button
- Update login page layout
- Add OAuth error handling UI

## Test Plan

- [ ] Configure OAuth2 credentials in `.env`
- [ ] Click "Sign in with Google" on login page
- [ ] Authorize app in Google consent screen
- [ ] Verify user account created/linked
- [ ] Test logging in with existing Google-linked account
- [ ] Test error cases (denied permission, network error)
- [ ] Verify email verification bypassed for Google accounts
- [ ] Confirm existing email/password login still works

## Screenshots

### Login page with Google sign-in
![Login UI](screenshot-url)

### OAuth consent flow
![OAuth flow](demo-video-url)

## Security Considerations

- OAuth2 tokens are never stored (only used for initial auth)
- User's Google account email is verified automatically
- CSRF protection enabled for OAuth callback
- Redirect URLs validated against whitelist

## Related Issues

Closes #234
Related to #189 (SSO epic)

## Deployment Notes

**Before deployment:**
1. Set up Google OAuth2 credentials in Google Cloud Console
2. Add credentials to environment variables:
   ```
   GOOGLE_CLIENT_ID=your_client_id
   GOOGLE_CLIENT_SECRET=your_client_secret
   GOOGLE_CALLBACK_URL=https://yourapp.com/auth/google/callback
   ```
3. Run database migration: `npm run migrate:up`

**After deployment:**
1. Test OAuth flow in production
2. Monitor error logs for auth failures
```

This PR description is comprehensive, clear, and provides all the information
a reviewer needs to understand and validate the changes.
