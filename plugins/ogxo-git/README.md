# ogxo-git

Git and GitHub workflow skills: Conventional Commit messages, PR titles and descriptions with template detection, resolving PR review threads (its workflow instructs it to present its analysis and wait for approval before replying or resolving), and a catchup command to restore branch context.

## Install

```bash
claude plugin marketplace add ogxo-io/plugins
claude plugin install ogxo-git@ogxo
```

## Contents

- `/ogxo-git:git-commit-generator` (skill)
- `/ogxo-git:pr-generator` (skill)
- `/ogxo-git:pr-review-resolver` (skill)
- `/ogxo-git:catchup` (command)
- `/ogxo-git:changelog-generator` (skill)
- `/ogxo-git:release-notes` (skill)
- `/ogxo-git:release` (command)
- `/ogxo-git:quick-fix` (command)
- `/ogxo-git:ship-feature [--no-gates] [base]` (command): security review, tests, and build, then branch (when on the default branch), commit what you staged, push, and open the PR with `pr-generator`, after one confirmation. `--no-gates` skips the checks for work already tested.
