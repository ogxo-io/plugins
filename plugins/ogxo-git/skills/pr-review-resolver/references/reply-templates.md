# Reply Templates for PR Review Resolution

Reference file for the `pr-review-resolver` skill. Contains reply guidelines and diplomatic response templates for each comment classification.

## Reply Guidelines

### General Principles

1. **Be diplomatic and professional** — Assume good intent from reviewers
2. **Keep replies concise** — Reviewers appreciate brevity
3. **Reference code or docs** — Back up reasoning with evidence
4. **Acknowledge valid points** — Even when declining a suggestion, acknowledge the reviewer's perspective
5. **Never auto-resolve without addressing** — Every resolved thread must have a reply or fix

### Reply Templates by Classification

Templates and examples are illustrative — vary the wording and match the reviewer's tone rather than reusing the same opener and closer on every reply.

#### Valid Fix / Valid Suggestion (Code Changed)

Template:
```
Fixed — [brief description of what was changed].
```

Examples:
- "Fixed — added null guard before accessing user properties."
- "Fixed — refactored to use async/await as suggested."
- "Fixed — added input validation for the email parameter."

Keep it short. The reviewer can see the code change in the next push.

#### Style/Preference (Declined)

Template:
```
Thanks for the suggestion! [Reasoning for current approach]. [Reference to project convention if applicable]. Happy to discuss further if you see a concern I'm missing.
```

Examples:
- "Thanks for the suggestion! This module follows the existing pattern of short variable names (`req`, `res`, `ctx`) for consistency with the rest of the codebase. Happy to discuss further if you see a concern I'm missing."
- "Thanks for flagging this! We use single-line arrow functions for simple transforms throughout this file — keeping it consistent here. Let me know if you feel strongly about changing the convention."

#### Already Addressed

Template:
```
This was addressed in [commit hash] — [brief description].
```

Examples:
- "This was addressed in abc1234 — moved the validation check to before the API call."
- "Good catch! This was already fixed in the previous commit (def5678) where we refactored the error handling."

#### Not Applicable

Template:
```
Thanks for the review! [Explanation of why the concern doesn't apply]. [Technical reasoning or reference]. Let me know if I'm missing something.
```

Examples:
- "Thanks for the review! The `user` parameter is guaranteed non-null here because of the middleware check on line 15. The TypeScript compiler also enforces this via the NonNullable type. Let me know if I'm missing something."
- "Appreciate the concern! This function is only called internally after authentication, so the role check at the caller level already covers this case."

#### Needs Discussion

Template:
```
Great point — this involves [trade-off description]. [Your perspective]. [Options to consider]. Would love to get the team's input on this.
```

Examples:
- "Great point — this involves a trade-off between query performance and code readability. I went with the denormalized approach for speed, but a join would be more maintainable. Would love to get the team's input on which we prefer here."

#### Question

Template:
```
[Direct answer to the question]. [Additional context if helpful].
```

Examples:
- "Tests for this module are in `test/auth.test.ts`. The new flow is covered by the 'handles expired tokens' test case."
- "We use this pattern because the API returns paginated results, so we need to accumulate across multiple requests."

#### Deferred (Tracked)

Template:
```
Valid point — created [#issue](url) to track this. Outside this PR's scope but will be addressed.
```

Examples:
- "Valid point — created [#142](https://github.com/org/repo/issues/142) to track this. The input sanitization concern is legitimate but outside the scope of this auth refactor. Will be addressed separately."
- "Good catch — created [#87](https://github.com/org/repo/issues/87) to track the missing error boundary. This PR focuses on the API layer, so handling it in a follow-up makes sense."

**Fallback template** (when `gh issue create` fails due to permissions):
```
Valid point — this is a legitimate concern but outside the scope of this PR. I wasn't able to create a tracking issue automatically. Could you create one with the following details?

**Title:** [proposed title]
**Description:** [brief description of the issue and context]
```

## Tone Calibration

### DO

- Thank reviewers for their time and attention
- Use collaborative language ("we", "let's", "our codebase")
- Provide objective evidence (code references, docs, benchmarks)
- Offer to discuss or reconsider if the reviewer feels strongly
- Track legitimate out-of-scope issues with GitHub issues — never reply and forget

### DO NOT

- Be dismissive ("That's not needed", "Works fine")
- Be defensive ("I already considered that", "That's obvious")
- Be passive-aggressive ("As I mentioned before...")
- Ignore the reviewer's expertise or perspective
- Dismiss legitimate issues as out of scope without creating a tracking mechanism
