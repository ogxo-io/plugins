# Prompt Template Reference

Use this template when generating the structured prompt in Step 5. Fill in every section — remove placeholder brackets and replace with actual project-specific content.

## Template

```markdown
# Task: [Clear, actionable title]

## Context

[2-3 sentences describing the project and relevant background]

### Project Stack
- **Framework:** [e.g., Next.js 15 with App Router]
- **Language:** [e.g., TypeScript 5.x]
- **Styling:** [e.g., Tailwind CSS v4]
- **Database:** [e.g., PostgreSQL via Prisma]
- **Testing:** [e.g., Vitest + Playwright]

### Relevant Existing Code
- `[path/to/related/file]` — [what it does and why it's relevant]
- `[path/to/pattern/example]` — [existing pattern to follow]

## Requirements

### Functional Requirements
1. [Specific, testable requirement]
2. [Specific, testable requirement]
3. ...

### Non-Functional Requirements
- **Security:** [specific security requirements]
- **Performance:** [specific performance targets]
- **Accessibility:** [WCAG level and specific needs]
- **Responsive:** [breakpoint requirements]

### Out of Scope
- [Explicitly excluded items]

## Implementation Strategy

### Phase 1: [Foundation]
**Agent:** `[agent-type]`
**Tasks:**
- [ ] [Specific deliverable]
- [ ] [Specific deliverable]
**Depends on:** nothing

### Phase 2: [Core Feature]
**Agent:** `[agent-type]`
**Tasks:**
- [ ] [Specific deliverable]
- [ ] [Specific deliverable]
**Depends on:** Phase 1

### Phase 3: [Integration & Polish]
**Agent:** `[agent-type]`
**Tasks:**
- [ ] [Specific deliverable]
- [ ] [Specific deliverable]
**Depends on:** Phase 1, Phase 2

### Parallel Work (can run alongside other phases)
**Agent:** `[agent-type]`
**Tasks:**
- [ ] [Specific deliverable]

## Agent Delegation

Dispatch these agents as sub-agents; run in parallel the ones whose dependencies are met, and start the rest when their dependencies finish (use a general-purpose agent unless a specialized agent type exists):

| Agent Name | Agent Type | Responsibility | Depends On |
|---|---|---|---|
| [name] | [subagent_type] | [what they do] | [dependencies] |

### Coordination Notes
- [How agents should communicate]
- [Shared conventions or contracts between agents]
- [Order of operations and sync points]

## Acceptance Criteria

- [ ] [Testable criterion]
- [ ] [Testable criterion]
- [ ] All new code has test coverage
- [ ] No type-check/lint errors introduced
- [ ] Follows existing project conventions

## Edge Cases & Error Handling

- [Scenario] → [Expected behavior]
- [Scenario] → [Expected behavior]
```

## Template Guidelines

### Filling in the Template

1. **Context** — Pull from Step 3 codebase exploration. Be specific about the project, not generic.
2. **Project Stack** — Use exact versions found in config files. Don't guess.
3. **Relevant Existing Code** — List actual files discovered during exploration that the agents should reference or follow as patterns.
4. **Functional Requirements** — Derived from Step 1 (user description) + Step 2 (clarifying questions). Each requirement should be testable.
5. **Non-Functional Requirements** — Only include categories relevant to the task. Remove irrelevant ones.
6. **Out of Scope** — Explicitly state what was discussed but excluded. This prevents scope creep.
7. **Implementation Strategy** — Order phases by dependency. Identify what can run in parallel.
8. **Agent Delegation** — Map from Step 4 agent identification. Use only agent type names present in the session's agent list.
9. **Coordination Notes** — Specify shared contracts (e.g., "API types defined by typescript-pro agent, consumed by frontend-developer agent").
10. **Acceptance Criteria** — Must be verifiable. "Works correctly" is not testable. "Returns 401 for unauthenticated requests" is testable.
11. **Edge Cases** — Include scenarios from the clarifying questions. Map each to an expected behavior.

### Adapting the Template

Not every task needs every section. Adjust based on complexity:

**Small task (1-2 agents):**
- Skip "Parallel Work" section
- Simplify "Agent Delegation" to a list instead of table
- Reduce phases to 1-2

**Large task (4+ agents):**
- Add a "Risks & Mitigations" section
- Add a "Migration Strategy" section if replacing existing code
- Consider splitting into multiple prompts for sub-projects
