# Code Quality Principles

**Write code as communication to future readers (including yourself).**

Code is read far more often than it is written. Optimize for clarity and maintainability.

---

## Core Philosophy

**Code is primarily for humans, secondarily for machines.**

Compilers and interpreters don't care about naming, structure, or comments—but the next developer (often future you) cares deeply. Every line of code is a message to another human about intent, behavior, and reasoning.

---

## Key Principles

### 1. Explicitness over Implicitness

**Make behavior observable and predictable.**

- Avoid magic values, hidden dependencies, and surprising side effects
- Surface intent through naming and structure
- Make assumptions and constraints visible
- Prefer clarity over cleverness

**Examples**:

**❌ Implicit (unclear intent)**:
```typescript
function process(data: any, flag: boolean) {
  if (flag) {
    return data.filter((x: any) => x > 10)
  }
  return data
}
```

**✅ Explicit (clear intent)**:
```typescript
const MIN_VALID_VALUE = 10

function filterValidValues(values: number[]): number[] {
  return values.filter(value => value > MIN_VALID_VALUE)
}

function getValues(values: number[], shouldFilter: boolean): number[] {
  if (shouldFilter) {
    return filterValidValues(values)
  }
  return values
}
```

**Benefits**:
- Named constant reveals "why 10?"
- Type signatures clarify expected inputs
- Function names describe what they do
- Boolean parameter name explains its purpose

### 2. Locality of Behavior

**Related logic should be physically close in the code.**

- Minimize cognitive jumps when reading and understanding code
- Co-locate what changes together (temporal coupling)
- Keep related functions/methods together
- Avoid scattering related logic across distant files

**Examples**:

**❌ Distant coupling (hard to follow)**:
```typescript
// file: services/user.ts
export function createUser(data: UserData) {
  const user = new User(data)
  user.save()
  return user
}

// file: utils/email.ts (far away)
export function sendWelcomeEmail(user: User) {
  emailService.send(user.email, 'Welcome!')
}

// file: services/analytics.ts (even farther)
export function trackUserSignup(user: User) {
  analytics.track('user_signup', { userId: user.id })
}

// Caller needs to know about all three separate modules
import { createUser } from './services/user'
import { sendWelcomeEmail } from './utils/email'
import { trackUserSignup } from './services/analytics'

const user = createUser(data)
sendWelcomeEmail(user)
trackUserSignup(user)
```

**✅ Localized behavior (easy to follow)**:
```typescript
// file: services/user.ts
export function createUser(data: UserData): User {
  const user = new User(data)
  user.save()
  sendWelcomeEmail(user)
  trackUserSignup(user)
  return user
}

function sendWelcomeEmail(user: User): void {
  emailService.send(user.email, 'Welcome!')
}

function trackUserSignup(user: User): void {
  analytics.track('user_signup', { userId: user.id })
}

// Caller only needs one module
import { createUser } from './services/user'
const user = createUser(data)
```

**Benefits**:
- All user creation logic in one place
- Easy to understand full behavior
- Changes to signup flow localized to one file

### 3. Fail Fast and Loud

**Surface errors at compile-time if possible, runtime otherwise.**

- Validate inputs early (at function entry)
- Runtime errors should be explicit and informative
- Silent failures compound into mysterious bugs
- Use static typing to catch errors before runtime

**Examples**:

**❌ Fails late and silently**:
```typescript
function calculateDiscount(price: any, discountPercent: any) {
  // No validation
  const discount = price * discountPercent
  return price - discount
}

calculateDiscount(100, 1.5) // Returns -50 (150% discount?!)
calculateDiscount('100', '0.1') // Returns '1000.1' (string concatenation!)
calculateDiscount(null, 0.1) // Returns NaN (silent failure)
```

**✅ Fails fast and loud**:
```typescript
function calculateDiscount(price: number, discountPercent: number): number {
  // Type system catches non-numbers at compile time

  // Validate business rules at runtime (fail fast)
  if (price < 0) {
    throw new Error('Price cannot be negative')
  }
  if (discountPercent < 0 || discountPercent > 1) {
    throw new Error('Discount percent must be between 0 and 1')
  }

  const discount = price * discountPercent
  return price - discount
}

calculateDiscount(100, 1.5) // Compile-time: type error (or runtime: throws immediately)
calculateDiscount('100', '0.1') // Compile-time: type error
calculateDiscount(null, 0.1) // Compile-time: type error
```

**Benefits**:
- Errors caught immediately, not buried deep in call stack
- Clear, actionable error messages
- Type system prevents entire classes of bugs

### 4. Configuration over Hard-coding

**Separate data from logic.**

- Make change points explicit and discoverable
- Centralize configuration rather than scattering it
- Use environment variables, config files, or feature flags
- Avoid embedding constants throughout code

**Examples**:

**❌ Hard-coded (scattered, fragile)**:
```typescript
// Scattered across multiple files
function sendEmail(to: string, subject: string, body: string) {
  fetch('https://api.sendgrid.com/v3/mail/send', {
    method: 'POST',
    headers: {
      'Authorization': 'Bearer SG.abc123...',
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({ to, subject, body })
  })
}

function uploadFile(file: File) {
  const maxSize = 10485760 // 10MB in bytes (what is this number?)
  if (file.size > maxSize) {
    throw new Error('File too large')
  }
  // ...
}

function fetchUsers() {
  return fetch('https://api.example.com/users')
}
```

**✅ Configured (centralized, flexible)**:
```typescript
// config.ts (single source of truth)
export const config = {
  email: {
    apiUrl: process.env.SENDGRID_API_URL || 'https://api.sendgrid.com/v3/mail/send',
    apiKey: process.env.SENDGRID_API_KEY || '',
  },
  upload: {
    maxFileSizeMB: parseInt(process.env.MAX_FILE_SIZE_MB || '10', 10),
  },
  api: {
    baseUrl: process.env.API_BASE_URL || 'https://api.example.com',
  },
}

// services/email.ts
import { config } from './config'

function sendEmail(to: string, subject: string, body: string) {
  fetch(config.email.apiUrl, {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${config.email.apiKey}`,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({ to, subject, body })
  })
}

// services/upload.ts
import { config } from './config'

function uploadFile(file: File) {
  const maxSizeBytes = config.upload.maxFileSizeMB * 1024 * 1024
  if (file.size > maxSizeBytes) {
    throw new Error(`File size exceeds ${config.upload.maxFileSizeMB}MB limit`)
  }
  // ...
}
```

**Benefits**:
- Configuration centralized and discoverable
- Easy to change across environments (dev, staging, prod)
- No magic numbers scattered throughout code

### 5. Simplicity over Cleverness

**Straightforward code beats clever optimizations (until proven necessary).**

- Reduce cognitive load through simplicity
- Avoid premature abstraction
- Optimize for readability first, performance second (measure before optimizing)
- Clever code is harder to debug and maintain

**Examples**:

**❌ Clever (hard to understand)**:
```typescript
// One-liner that does too much
const result = data.reduce((acc, x) => ({ ...acc, [x.id]: x.name }), {})

// Regex golf (unreadable)
const isValid = /^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]{8,}$/.test(password)

// Bitwise tricks (obscure)
const isEven = (n & 1) === 0
```

**✅ Simple (easy to understand)**:
```typescript
// Clear loop with descriptive variable names
const userNamesById: Record<string, string> = {}
for (const user of data) {
  userNamesById[user.id] = user.name
}

// Named validation function with clear intent
function isValidPassword(password: string): boolean {
  const hasLowerCase = /[a-z]/.test(password)
  const hasUpperCase = /[A-Z]/.test(password)
  const hasDigit = /\d/.test(password)
  const hasSpecialChar = /[@$!%*?&]/.test(password)
  const isLongEnough = password.length >= 8

  return hasLowerCase && hasUpperCase && hasDigit && hasSpecialChar && isLongEnough
}

// Clear arithmetic
const isEven = (n % 2 === 0)
```

**Benefits**:
- Anyone can understand and modify the code
- Easier to debug and test
- Self-documenting (intent is clear)

**When Cleverness Is Justified**:
- Performance-critical code (after profiling proves bottleneck)
- Well-known idioms in the language/community
- Accompanied by clear comments explaining the "why"

### 6. Stateless Design & Idempotency

**Minimize mutable state and synchronization complexity.**

- Operations should produce the same result regardless of how many times they're executed
- Stateless components are easier to reason about, test, and scale
- Design for reproducibility and composability
- Prefer pure functions over stateful objects

**Examples**:

**❌ Stateful (hard to reason about)**:
```typescript
class UserService {
  private cachedUsers: User[] = []

  async getUsers(): Promise<User[]> {
    if (this.cachedUsers.length > 0) {
      return this.cachedUsers
    }
    this.cachedUsers = await database.query('SELECT * FROM users')
    return this.cachedUsers
  }

  async updateUser(id: string, data: Partial<User>): Promise<void> {
    await database.query('UPDATE users SET ... WHERE id = ?', [id, data])
    // Cache is now stale! Bugs ahead...
  }
}

// Caller 1
const users = await userService.getUsers() // Gets from DB

// Caller 2
const users = await userService.getUsers() // Gets cached version

// After update, cache is stale
await userService.updateUser('123', { name: 'New Name' })
const users = await userService.getUsers() // Still returns old cached data!
```

**✅ Stateless (easy to reason about)**:
```typescript
// Stateless service (no internal state)
class UserService {
  async getUsers(): Promise<User[]> {
    return database.query('SELECT * FROM users')
  }

  async updateUser(id: string, data: Partial<User>): Promise<void> {
    await database.query('UPDATE users SET ... WHERE id = ?', [id, data])
  }
}

// If caching is needed, use external cache with TTL
const cache = new Cache({ ttl: 60000 }) // 1 minute TTL

async function getCachedUsers(): Promise<User[]> {
  return cache.getOrSet('users', async () => {
    return userService.getUsers()
  })
}
```

**Idempotency Example**:

**❌ Not idempotent (different results on repeat)**:
```typescript
let counter = 0

function increment() {
  counter += 1 // Calling twice gives different results
  return counter
}

increment() // Returns 1
increment() // Returns 2 (different!)
```

**✅ Idempotent (same result on repeat)**:
```typescript
function setUserStatus(userId: string, status: 'active' | 'inactive'): void {
  database.query('UPDATE users SET status = ? WHERE id = ?', [status, userId])
  // Calling this 10 times has the same effect as calling it once
}

setUserStatus('123', 'active') // User 123 is active
setUserStatus('123', 'active') // User 123 is still active (same result)
```

**Benefits**:
- Easier to test (no hidden state)
- Easier to parallelize (no shared mutable state)
- Idempotent operations safe to retry
- Stateless components scale horizontally

---

## Anti-Patterns to Avoid

### 1. Magic Values

**Problem**: Unexplained numbers, strings, or flags scattered in code

**Example**:
```typescript
if (user.age > 18 && user.score > 500 && user.tier === 3) {
  // What do these numbers mean?
}
```

**Solution**:
```typescript
const ADULT_AGE = 18
const PREMIUM_SCORE_THRESHOLD = 500
const PLATINUM_TIER = 3

if (user.age > ADULT_AGE && user.score > PREMIUM_SCORE_THRESHOLD && user.tier === PLATINUM_TIER) {
  // Clear intent
}
```

### 2. Deep Nesting

**Problem**: More than 2-3 levels suggests missing abstractions or early returns

**Example**:
```typescript
function processOrder(order: Order) {
  if (order) {
    if (order.items.length > 0) {
      if (order.isPaid) {
        if (order.isShipped) {
          // Deep nesting hell
        }
      }
    }
  }
}
```

**Solution**:
```typescript
function processOrder(order: Order | null) {
  if (!order || order.items.length === 0) return
  if (!order.isPaid) return
  if (!order.isShipped) return

  // Flat, readable code
}
```

### 3. Large Functions

**Problem**: Doing too much in one place (violates Single Responsibility Principle)

**Example**:
```typescript
function createUserAndSendEmail(data: UserData) {
  // 200 lines of validation, database logic, email formatting, analytics...
}
```

**Solution**:
```typescript
function createUser(data: UserData): User {
  validateUserData(data)
  const user = saveUser(data)
  sendWelcomeEmail(user)
  trackUserSignup(user)
  return user
}
```

### 4. Global Mutable State

**Problem**: Makes reasoning about code behavior nearly impossible

**Example**:
```typescript
let currentUser: User | null = null

function login(user: User) {
  currentUser = user
}

function processPayment() {
  // Relies on global currentUser (who set it? when? is it stale?)
  if (currentUser) {
    // ...
  }
}
```

**Solution**:
```typescript
function processPayment(user: User) {
  // Explicit dependency, no global state
}
```

### 5. Unclear Naming

**Problem**: Variable/function names that don't convey purpose

**Example**:
```typescript
const d = new Date()
function proc(data: any) { /* ... */ }
const temp = calculate()
```

**Solution**:
```typescript
const currentDate = new Date()
function processUserRegistration(userData: UserData) { /* ... */ }
const discountedPrice = calculateDiscount(originalPrice, discountPercent)
```

---

## Golden Rule

**If someone asks "why does this behave this way?", the answer should be obvious from reading the code, not from archeological investigation.**

Write code that explains itself. Comments should explain "why", not "what"—the code itself should make the "what" clear.

**Examples**:

**❌ Comments explaining "what" (code is unclear)**:
```typescript
// Add 1 to counter
counter += 1

// Check if user is admin
if (user.role === 2) {
  // ...
}
```

**✅ Code explains "what", comments explain "why"**:
```typescript
// Increment page view counter for analytics
pageViewCounter += 1

const ADMIN_ROLE = 2
// Only admins can delete users to prevent accidental data loss
if (user.role === ADMIN_ROLE) {
  // ...
}
```

---

## Summary

**Code quality is about communication**:

1. **Explicitness**: Make intent and behavior obvious
2. **Locality**: Keep related logic together
3. **Fail Fast**: Surface errors early and clearly
4. **Configuration**: Separate data from logic
5. **Simplicity**: Clarity over cleverness
6. **Statelessness**: Minimize mutable state, design for idempotency

**The Goal**: Write code that is easy to:
- **Read** (understand intent quickly)
- **Modify** (change without fear)
- **Test** (verify behavior confidently)
- **Debug** (trace issues easily)

**Remember**: You write code once, but it's read dozens or hundreds of times. Optimize for the reader.
