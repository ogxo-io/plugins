# ADR and Output Templates

Full templates for Architecture Decision Records and implementation roadmaps. Use these when documenting a decision or handing an approved architecture to the development team.

## ADR Template

```markdown
# ADR-[NNN]: [Short Title of Decision]

## Status

[Proposed | Accepted | Deprecated | Superseded by ADR-XXX]

## Date

[YYYY-MM-DD]

## Context

[What is the issue that we are seeing that is motivating this decision or change?
Describe the forces at play, including technical, business, social, and project-local.
These forces are likely in tension and should be called out as such.]

## Decision Drivers

- [Driver 1: quality attribute or constraint]
- [Driver 2: quality attribute or constraint]
- [Driver 3: quality attribute or constraint]

## Considered Options

1. [Option A]
2. [Option B]
3. [Option C]

## Decision

[We will use Option X because...]

[Justify the decision in terms of the decision drivers. Explain why this option
best addresses the forces described in the context.]

## Consequences

### Positive
- [Consequence 1: specific benefit]
- [Consequence 2: specific benefit]

### Negative
- [Consequence 1: specific cost or risk]
- [Consequence 2: specific cost or risk]

### Neutral
- [Consequence 1: neither good nor bad, but worth noting]

## Compliance

[How will we verify this decision is being followed? Fitness functions, code reviews, automated checks?]

## Notes

[Any additional information, references, or related ADRs]
```

## Options Template (present at least 2-3)

```markdown
## Option [A/B/C]: [Architecture Name]

### Description
[Clear description of the approach]

### How It Works
[High-level design showing key components and interactions]

### Advantages
- [Specific advantage tied to a quality attribute]

### Disadvantages
- [Specific disadvantage tied to a quality attribute]
- [Operational complexity implications]

### Best When
- [Conditions that make this the right choice]

### Risk Assessment
- [Key risks and mitigation strategies]

### Estimated Effort
- [Development effort, operational overhead, learning curve]
```

## Recommendation Template

```markdown
## Recommendation: Option [X] - [Architecture Name]

### Why This Approach
Given the identified architectural drivers:
- [Quality Attribute]: This approach provides [specific benefit] because [reasoning]
- [Team Factor]: Aligns with team capabilities because [reasoning]

### Why Not the Others
- Option [Y]: [Specific reason it is less suitable for this context]

### Migration Path (if applicable)
1. [Phase 1] 2. [Phase 2] 3. [Phase 3]

### Risks and Mitigations
| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| [Risk] | Medium | High | [Mitigation strategy] |
```

## Implementation Roadmap Template

```markdown
## Implementation Roadmap

### Phase 1: Foundation (Week 1-2)
- [ ] [Specific task]
- [ ] Fitness function: [Automated check to verify architecture]

### Phase 2: Core Structure (Week 3-4)
- [ ] [Specific task]
- [ ] Fitness function: [Automated check]

### Phase 3: Migration/Completion (Week 5+)
- [ ] [Specific task]
- [ ] Fitness function: [Automated check]

### Success Criteria
- [ ] [Measurable criterion]
- [ ] All fitness functions passing
```
