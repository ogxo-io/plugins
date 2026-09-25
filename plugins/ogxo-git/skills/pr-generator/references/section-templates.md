# PR Section Templates and Format Examples

Detailed templates and examples for each section of a pull request description.

## Summary Section Template

Create a concise overview that explains:
- **What** changes were made (high-level)
- **Why** these changes were made (motivation/purpose)
- **Impact** on users or system (if applicable)

**Generation approach:**
1. Review all commit messages
2. Identify the overarching goal
3. Synthesize into concise summary
4. Focus on user-facing or system-level impact

**Example:**
```markdown
## Summary

This PR implements JWT-based authentication to replace the current
session-based auth system. This change improves API security and
enables stateless authentication, which is essential for mobile
client support and horizontal scaling.
```

---

## Changes Section Template

Create a detailed bullet-point list of what changed:

**Generation approach:**
1. Group commits by logical area (use scopes and file categories)
2. Summarize related commits into single bullet points
3. Be specific about components/modules affected
4. Mention removals or deprecations
5. Organize by importance (major changes first)
6. **Avoid unnecessary details** - Do NOT include file counts, line counts, or technical metrics
7. Focus on WHAT changed and WHY, not statistics

**Format:**
```markdown
## Changes

**Authentication:**
- Add JWT token generation on successful login
- Implement token validation middleware
- Add token refresh endpoint for seamless re-authentication

**Database:**
- Add user token storage table
- Create migration for auth schema changes

**Configuration:**
- Update auth config to support JWT settings
- Add token expiration configuration

**Cleanup:**
- Remove deprecated session management code
```

**Categorization guide:**
- Use `files.categorized` from analysis to group changes
- Combine related commits under logical headings
- Highlight breaking changes or removals

---

## Test Plan Section Template

Create a comprehensive checklist for validating the changes:

**Generation approach:**
1. Based on changed files, identify what needs testing
2. Include positive test cases (expected behavior)
3. Include negative test cases (error handling, edge cases)
4. Mention both automated and manual tests
5. Include integration/end-to-end scenarios

**Format:**
```markdown
## Test Plan

**Automated Tests:**
- [ ] All unit tests pass (`npm test`)
- [ ] Integration tests pass (`npm run test:integration`)
- [ ] New test coverage for OAuth flow

**Manual Testing:**
- [ ] Create new account via `/auth/register`
- [ ] Login with OAuth and verify JWT token in response
- [ ] Access protected endpoint with valid token
- [ ] Test token expiration after configured time
- [ ] Verify token refresh mechanism works
- [ ] Confirm error handling for invalid tokens
- [ ] Test backwards compatibility with existing accounts

**Edge Cases:**
- [ ] Handle expired tokens gracefully
- [ ] Test rate limiting on auth endpoints
- [ ] Verify behavior with network failures
```

---

## Related Issues Section Template

Link to relevant issues and tickets:

**Generation approach:**
1. If an issue key is detected in the branch name, include it
2. Search commit messages for issue references (#123, Closes #456)
3. Use appropriate closing keywords

**Format:**
```markdown
## Related Issues

Closes #234
Fixes #456
Related to #789
```

**GitHub closing keywords:**
- `Closes`, `Fixes`, `Resolves` - Auto-closes issue when PR merges
- `Related to`, `See also` - Links without auto-closing

---

## Optional Sections

Include these sections when relevant based on the analysis:

### Breaking Changes Section

**When to include**: If `commit_analysis.has_breaking_changes` is true

**Format:**
```markdown
## ⚠️ Breaking Changes

**API Endpoint Changes:**
- `POST /login` now returns JWT instead of session cookie
- All authenticated requests must include `Authorization: Bearer <token>` header

**Migration Steps:**
1. Update client code to store JWT tokens
2. Include Authorization header in all API requests
3. Remove session cookie handling code
```

---

### Performance Impact Section

**When to include**: If commit type is `perf` or file changes suggest performance work

**Format:**
```markdown
## Performance Impact

- Reduced authentication overhead by 60%
- Eliminated database queries for every request
- Stateless tokens enable better horizontal scaling
```

---

### Security Considerations Section

**When to include**: If changes affect security

**Format:**
```markdown
## Security Considerations

- JWT tokens expire after 1 hour (configurable)
- Tokens signed with RS256 algorithm
- Refresh tokens use secure HTTP-only cookies
- Rate limiting applied to auth endpoints (10 req/min)
```

---

### Deployment Notes Section

**When to include**: If changes require special deployment steps

**Format:**
```markdown
## Deployment Notes

**Before deployment:**
1. Run database migration: `npm run migrate:up`
2. Generate JWT secret: `openssl rand -hex 32`
3. Update environment variables (see .env.example)

**After deployment:**
1. Monitor auth endpoint response times
2. Verify token generation in production
3. Test with staging environment first
```

---

## Tips for Effective PR Descriptions

1. **Be specific**: Use actual component/module names, not generic terms
2. **Focus on impact**: Explain WHY changes matter, not just WHAT changed
3. **Group logically**: Organize changes by functional area or scope
4. **Test comprehensively**: Cover happy path, edge cases, and error scenarios
5. **Link context**: Reference issues, docs, or related PRs
6. **Highlight breaking changes**: Make them impossible to miss
7. **Consider deployment**: Document any special steps or considerations

---

## Section Selection Guide

**Always include:**
- Summary
- Changes
- Test Plan

**Include when applicable:**
- Related Issues (if tracker/GitHub issues exist)
- Breaking Changes (if `has_breaking_changes` is true)
- Security Considerations (for auth, permissions, data access changes)
- Performance Impact (for perf commits or optimization work)
- Deployment Notes (for database changes, config updates, or migrations)

**Avoid including:**
- File/line count statistics
- Low-level technical details better suited for commit messages
- Duplicate information already in commits
- Overly verbose explanations
