# Codemod Development

Guidance for creating automated code transformation scripts to apply mechanical changes at scale.

## When to Write a Codemod

- More than 10 files need the same mechanical transformation
- The change follows a predictable pattern (rename, restructure, wrap)
- Manual changes are error-prone due to volume

## Codemod Tools by Language

| Language | Tool | Description |
|----------|------|-------------|
| JavaScript/TypeScript | jscodeshift | AST-based transforms via recast |
| TypeScript | ts-morph | TypeScript compiler API wrapper |
| Python | libcst | Concrete syntax tree for Python |
| Go | `go fix` + custom analyzers | Go analysis framework |
| General | `sed`/`awk` | Simple text-based transforms |
| General | `comby` | Structural search and replace |

## Simple Codemod Example (jscodeshift)

```javascript
// Transform: jest.fn() -> vi.fn()
export default function transformer(file, api) {
  const j = api.jscodeshift;
  const root = j(file.source);

  root.find(j.CallExpression, {
    callee: {
      object: { name: 'jest' },
      property: { name: 'fn' }
    }
  }).forEach(path => {
    path.node.callee.object.name = 'vi';
  });

  return root.toSource();
}
```
