# TypeScript Best Practices

Comprehensive guide to writing high-quality TypeScript code.

---

## Table of Contents
1. [Type Safety](#type-safety)
2. [Modern TypeScript Patterns](#modern-typescript-patterns)
3. [Error Handling](#error-handling)
4. [Async Programming](#async-programming)
5. [Performance](#performance)
6. [Code Organization](#code-organization)

---

## Type Safety

### Use Strict Mode

**Always enable strict mode** in `tsconfig.json`:

```json
{
  "compilerOptions": {
    "strict": true
  }
}
```

This enables:
- `noImplicitAny`: Catch missing type annotations
- `strictNullChecks`: Prevent null/undefined errors
- `strictFunctionTypes`: Ensure function parameter compatibility
- `strictBindCallApply`: Type-check bind/call/apply
- `strictPropertyInitialization`: Ensure class properties are initialized

### Prefer Interface over Type for Objects

**✅ Use `interface` for object shapes** (extensible):

```typescript
interface User {
  id: string
  name: string
  email: string
}

// Can be extended
interface AdminUser extends User {
  permissions: string[]
}
```

**Use `type` for unions, intersections, and primitives**:

```typescript
type Status = 'active' | 'inactive' | 'pending'
type ID = string | number
type Point = { x: number } & { y: number }
```

### Avoid `any`, Use `unknown`

**❌ Bad (loses type safety)**:

```typescript
function process(data: any) {
  return data.value.toUpperCase() // No type checking
}
```

**✅ Good (maintains type safety)**:

```typescript
function process(data: unknown) {
  if (typeof data === 'object' && data !== null && 'value' in data) {
    const value = (data as { value: unknown }).value
    if (typeof value === 'string') {
      return value.toUpperCase()
    }
  }
  throw new Error('Invalid data format')
}
```

### Use Type Guards

**Define reusable type guards**:

```typescript
interface User {
  id: string
  name: string
}

function isUser(value: unknown): value is User {
  return (
    typeof value === 'object' &&
    value !== null &&
    'id' in value &&
    typeof (value as User).id === 'string' &&
    'name' in value &&
    typeof (value as User).name === 'string'
  )
}

// Usage
const data: unknown = fetchData()
if (isUser(data)) {
  console.log(data.name) // TypeScript knows data is User
}
```

### Discriminated Unions

**Use discriminated unions for variant types**:

```typescript
type Result<T, E = Error> =
  | { success: true; value: T }
  | { success: false; error: E }

function divide(a: number, b: number): Result<number> {
  if (b === 0) {
    return { success: false, error: new Error('Division by zero') }
  }
  return { success: true, value: a / b }
}

// Usage with type narrowing
const result = divide(10, 2)
if (result.success) {
  console.log(result.value) // TypeScript knows result has value
} else {
  console.error(result.error) // TypeScript knows result has error
}
```

---

## Modern TypeScript Patterns

### Optional Chaining & Nullish Coalescing

**✅ Use optional chaining (`?.`)**:

```typescript
// Old way
const city = user && user.address && user.address.city

// Modern way
const city = user?.address?.city
```

**✅ Use nullish coalescing (`??`)**:

```typescript
// Bad (0 and '' are falsy)
const count = userInput || 10

// Good (only null/undefined trigger default)
const count = userInput ?? 10
```

### Const Assertions

**Use `as const` for literal types**:

```typescript
// Without const assertion
const config = {
  apiUrl: 'https://api.example.com',
  timeout: 5000,
}
// Type: { apiUrl: string; timeout: number }

// With const assertion
const config = {
  apiUrl: 'https://api.example.com',
  timeout: 5000,
} as const
// Type: { readonly apiUrl: "https://api.example.com"; readonly timeout: 5000 }

// For arrays
const colors = ['red', 'green', 'blue'] as const
// Type: readonly ["red", "green", "blue"]
```

### Template Literal Types

**Use template literals for string patterns**:

```typescript
type HTTPMethod = 'GET' | 'POST' | 'PUT' | 'DELETE'
type Endpoint = `/api/${string}`
type APIRoute = `${HTTPMethod} ${Endpoint}`

// Examples:
// "GET /api/users"
// "POST /api/products"
```

### Utility Types

**Leverage built-in utility types**:

```typescript
interface User {
  id: string
  name: string
  email: string
  createdAt: Date
}

// Make all properties optional
type PartialUser = Partial<User>

// Make all properties required
type RequiredUser = Required<User>

// Pick specific properties
type UserPreview = Pick<User, 'id' | 'name'>

// Omit specific properties
type UserWithoutDates = Omit<User, 'createdAt'>

// Make all properties readonly
type ImmutableUser = Readonly<User>

// Extract keys as union type
type UserKeys = keyof User // 'id' | 'name' | 'email' | 'createdAt'

// Create type from object values
const statusMap = {
  active: 'Active',
  inactive: 'Inactive',
  pending: 'Pending',
} as const

type Status = keyof typeof statusMap // 'active' | 'inactive' | 'pending'
```

---

## Error Handling

### Result Type Pattern

**Use discriminated unions for expected errors**:

```typescript
type Result<T, E = Error> =
  | { ok: true; value: T }
  | { ok: false; error: E }

async function fetchUser(id: string): Promise<Result<User>> {
  try {
    const response = await fetch(`/api/users/${id}`)
    if (!response.ok) {
      return { ok: false, error: new Error(`HTTP ${response.status}`) }
    }
    const data = await response.json()
    if (!isUser(data)) {
      return { ok: false, error: new Error('Invalid user data') }
    }
    return { ok: true, value: data }
  } catch (error) {
    return { ok: false, error: error instanceof Error ? error : new Error('Unknown error') }
  }
}

// Usage
const result = await fetchUser('123')
if (result.ok) {
  console.log(result.value.name)
} else {
  console.error(result.error.message)
}
```

### Custom Error Types

**Create specific error types**:

```typescript
class ValidationError extends Error {
  constructor(
    message: string,
    public field: string,
    public value: unknown
  ) {
    super(message)
    this.name = 'ValidationError'
  }
}

class NotFoundError extends Error {
  constructor(
    message: string,
    public resource: string,
    public id: string
  ) {
    super(message)
    this.name = 'NotFoundError'
  }
}

// Usage
function validateEmail(email: string): void {
  if (!email.includes('@')) {
    throw new ValidationError('Invalid email format', 'email', email)
  }
}

// Handling
try {
  validateEmail('invalid')
} catch (error) {
  if (error instanceof ValidationError) {
    console.error(`Validation failed for ${error.field}: ${error.value}`)
  } else {
    throw error
  }
}
```

---

## Async Programming

### Prefer async/await over Promises

**❌ Promise chains (harder to read)**:

```typescript
function fetchUserData(id: string): Promise<UserData> {
  return fetchUser(id)
    .then(user => fetchProfile(user.profileId))
    .then(profile => fetchSettings(profile.settingsId))
    .then(settings => ({ user, profile, settings }))
    .catch(error => {
      console.error(error)
      throw error
    })
}
```

**✅ async/await (clearer flow)**:

```typescript
async function fetchUserData(id: string): Promise<UserData> {
  try {
    const user = await fetchUser(id)
    const profile = await fetchProfile(user.profileId)
    const settings = await fetchSettings(profile.settingsId)
    return { user, profile, settings }
  } catch (error) {
    console.error(error)
    throw error
  }
}
```

### Parallel Async Operations

**Use `Promise.all` for parallel operations**:

```typescript
// ❌ Sequential (slow)
async function fetchAllData() {
  const users = await fetchUsers()
  const products = await fetchProducts()
  const orders = await fetchOrders()
  return { users, products, orders }
}

// ✅ Parallel (fast)
async function fetchAllData() {
  const [users, products, orders] = await Promise.all([
    fetchUsers(),
    fetchProducts(),
    fetchOrders(),
  ])
  return { users, products, orders }
}
```

**Use `Promise.allSettled` for independent operations**:

```typescript
async function fetchWithFallbacks() {
  const results = await Promise.allSettled([
    fetchFromPrimaryAPI(),
    fetchFromBackupAPI(),
    fetchFromCache(),
  ])

  // Handle each result independently
  results.forEach((result, index) => {
    if (result.status === 'fulfilled') {
      console.log(`Source ${index} succeeded:`, result.value)
    } else {
      console.error(`Source ${index} failed:`, result.reason)
    }
  })
}
```

---

## Performance

### Avoid Expensive Type Computations

**❌ Complex recursive types (slow compilation)**:

```typescript
type DeepPartial<T> = {
  [K in keyof T]?: T[K] extends object ? DeepPartial<T[K]> : T[K]
}
```

**✅ Limit recursion depth or use simpler types**:

```typescript
type PartialUser = Partial<User> // Built-in, fast
```

### Use `const enum` for Constants

**`const enum` is erased at runtime**:

```typescript
const enum Direction {
  Up,
  Down,
  Left,
  Right,
}

const move = Direction.Up // Compiles to: const move = 0
```

**Regular enum generates runtime code**:

```typescript
enum Direction {
  Up,
  Down,
  Left,
  Right,
}
// Generates object at runtime
```

### Memoization for Expensive Computations

```typescript
function memoize<T extends (...args: any[]) => any>(fn: T): T {
  const cache = new Map<string, ReturnType<T>>()
  return ((...args: Parameters<T>) => {
    const key = JSON.stringify(args)
    if (cache.has(key)) {
      return cache.get(key)!
    }
    const result = fn(...args)
    cache.set(key, result)
    return result
  }) as T
}

// Usage
const expensiveCalculation = memoize((a: number, b: number) => {
  console.log('Computing...')
  return a * b
})

expensiveCalculation(5, 10) // Logs "Computing...", returns 50
expensiveCalculation(5, 10) // Returns 50 from cache (no log)
```

---

## Code Organization

### Barrel Exports

**Use `index.ts` for clean imports**:

```typescript
// utils/index.ts
export { formatDate } from './date'
export { validateEmail } from './validation'
export { debounce, throttle } from './timing'

// Consumer
import { formatDate, validateEmail, debounce } from './utils'
```

### Path Aliases

**Configure path aliases in `tsconfig.json`**:

```json
{
  "compilerOptions": {
    "baseUrl": ".",
    "paths": {
      "@/*": ["src/*"],
      "~/components/*": ["src/components/*"]
    }
  }
}
```

```typescript
// Instead of
import { Button } from '../../../components/Button'

// Use
import { Button } from '@/components/Button'
```

---

## Summary

**TypeScript Best Practices Checklist**:

- ✅ Enable `strict` mode
- ✅ Prefer `interface` for objects, `type` for unions
- ✅ Use `unknown` over `any`
- ✅ Define type guards for runtime checks
- ✅ Use discriminated unions for variant types
- ✅ Leverage optional chaining (`?.`) and nullish coalescing (`??`)
- ✅ Use `as const` for literal types
- ✅ Create custom error types
- ✅ Use async/await over Promise chains
- ✅ Parallelize independent async operations
- ✅ Organize code with barrel exports and path aliases

For testing strategies, see [testing.md](./testing.md).
For design patterns, see [patterns.md](./patterns.md).
