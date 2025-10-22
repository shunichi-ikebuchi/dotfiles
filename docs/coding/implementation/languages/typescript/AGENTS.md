# TypeScript Coding Guidelines

TypeScript-specific instructions for AI coding agents working on TypeScript/JavaScript projects.

---

## Quick Reference

### Type Safety
- ✅ Enable `strict` mode in `tsconfig.json`
- ✅ Prefer `interface` over `type` for object shapes (extensibility)
- ✅ Use `unknown` instead of `any` when type is uncertain
- ✅ Leverage type guards for runtime type checking
- ✅ Use `const` assertions for literal types
- ❌ Avoid `any` unless absolutely necessary (use `unknown` + type guards)

### Modern Syntax
- ✅ Use `async`/`await` over raw Promises
- ✅ Use optional chaining (`?.`) and nullish coalescing (`??`)
- ✅ Prefer `const` and `let` over `var`
- ✅ Use arrow functions for callbacks and short functions
- ✅ Destructuring for object/array access

### Error Handling
- ✅ Use discriminated unions for Result types
- ✅ Throw errors for exceptional cases, return Results for expected failures
- ✅ Provide specific error types (extend `Error`)
- ✅ Use `try`/`catch` with `async`/`await`

### Code Organization
- ✅ One export per file for major classes/functions
- ✅ Group related utilities in barrel exports (`index.ts`)
- ✅ Co-locate tests with source files (`*.test.ts` or `__tests__/`)
- ✅ Use path aliases for cleaner imports (`@/`, `~/`)

---

## Detailed Guidelines

For comprehensive TypeScript best practices, see:
- **[Best Practices](./best-practices.md)**: Type safety, modern patterns, performance
- **[Testing](./testing.md)**: Testing strategies, frameworks, patterns
- **[Patterns](./patterns.md)**: Common design patterns in TypeScript

---

## Common Pitfalls to Avoid

### ❌ Type Assertions Without Validation
```typescript
// Bad: Unsafe type assertion
const user = data as User

// Good: Type guard + assertion
function isUser(data: unknown): data is User {
  return typeof data === 'object' && data !== null && 'id' in data
}
const user = isUser(data) ? data : null
```

### ❌ Implicit Any
```typescript
// Bad: Implicit any
function process(data) { ... }

// Good: Explicit types
function process(data: ProcessData): ProcessResult { ... }
```

### ❌ Mutable Exports
```typescript
// Bad: Mutable constant
export const CONFIG = { apiUrl: '...' }

// Good: Immutable or readonly
export const CONFIG = Object.freeze({ apiUrl: '...' })
// or
export const CONFIG: Readonly<Config> = { apiUrl: '...' }
```

---

## Project Setup

### Recommended tsconfig.json
```json
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "ESNext",
    "lib": ["ES2022"],
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "forceConsistentCasingInFileNames": true,
    "resolveJsonModule": true,
    "isolatedModules": true,
    "noUnusedLocals": true,
    "noUnusedParameters": true,
    "noImplicitReturns": true,
    "noFallthroughCasesInSwitch": true
  }
}
```

### Recommended Tools
- **Linter**: ESLint with `@typescript-eslint/*` plugins
- **Formatter**: Prettier
- **Testing**: Vitest (modern) or Jest (established)
- **Type Checking**: `tsc --noEmit` in CI/CD
- **Build**: tsup, esbuild, or Vite

---

## Integration with General Principles

TypeScript code should also follow:
- **[Code Quality Principles](../general/code-quality.md)**: Explicitness, locality, fail-fast
- **[Unix Philosophy](../general/unix-philosophy.md)**: Composability, single responsibility

---

## When to Escalate

Consult human developers for:
- **Major architectural decisions**: Choosing frameworks, state management patterns
- **Breaking API changes**: Modifying public interfaces
- **Performance trade-offs**: Optimization vs. readability decisions
- **Type system limitations**: When types become too complex or fight the system
