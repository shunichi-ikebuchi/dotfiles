# TypeScript Design Patterns

Common design patterns and their TypeScript implementations.

---

## Creational Patterns

### Factory Pattern

```typescript
interface Product {
  name: string
  price: number
}

class ProductFactory {
  static create(type: 'book' | 'electronics', name: string, price: number): Product {
    // Factory logic here
    return { name, price }
  }
}
```

### Builder Pattern

```typescript
class UserBuilder {
  private user: Partial<User> = {}

  setName(name: string): this {
    this.user.name = name
    return this
  }

  setEmail(email: string): this {
    this.user.email = email
    return this
  }

  build(): User {
    if (!this.user.name || !this.user.email) {
      throw new Error('Missing required fields')
    }
    return this.user as User
  }
}

// Usage
const user = new UserBuilder()
  .setName('John')
  .setEmail('john@example.com')
  .build()
```

---

## Structural Patterns

### Adapter Pattern

```typescript
interface ModernAPI {
  fetchUsers(): Promise<User[]>
}

class LegacyAPIAdapter implements ModernAPI {
  constructor(private legacyAPI: LegacyAPI) {}

  async fetchUsers(): Promise<User[]> {
    const legacyUsers = await this.legacyAPI.getUsers()
    return legacyUsers.map(convertToModernUser)
  }
}
```

### Decorator Pattern

```typescript
function withLogging<T extends (...args: any[]) => any>(fn: T): T {
  return ((...args: Parameters<T>) => {
    console.log(`Calling ${fn.name} with`, args)
    const result = fn(...args)
    console.log(`${fn.name} returned`, result)
    return result
  }) as T
}

// Usage
const add = withLogging((a: number, b: number) => a + b)
add(2, 3) // Logs call and result
```

---

## Behavioral Patterns

### Strategy Pattern

```typescript
interface PaymentStrategy {
  pay(amount: number): Promise<void>
}

class CreditCardPayment implements PaymentStrategy {
  async pay(amount: number) {
    console.log(`Paid ${amount} via credit card`)
  }
}

class PayPalPayment implements PaymentStrategy {
  async pay(amount: number) {
    console.log(`Paid ${amount} via PayPal`)
  }
}

class PaymentProcessor {
  constructor(private strategy: PaymentStrategy) {}

  async process(amount: number) {
    await this.strategy.pay(amount)
  }
}
```

### Observer Pattern

```typescript
type Listener<T> = (data: T) => void

class EventEmitter<T> {
  private listeners: Listener<T>[] = []

  subscribe(listener: Listener<T>): () => void {
    this.listeners.push(listener)
    return () => {
      this.listeners = this.listeners.filter(l => l !== listener)
    }
  }

  emit(data: T): void {
    this.listeners.forEach(listener => listener(data))
  }
}
```

---

## Functional Patterns

### Pipeline Pattern

```typescript
const pipeline = <T>(...fns: Array<(arg: T) => T>) => (value: T): T =>
  fns.reduce((acc, fn) => fn(acc), value)

// Usage
const processUser = pipeline(
  (user: User) => ({ ...user, name: user.name.trim() }),
  (user: User) => ({ ...user, email: user.email.toLowerCase() }),
  (user: User) => ({ ...user, createdAt: new Date() })
)
```

### Option/Maybe Pattern

```typescript
class Option<T> {
  private constructor(private value: T | null) {}

  static some<T>(value: T): Option<T> {
    return new Option(value)
  }

  static none<T>(): Option<T> {
    return new Option<T>(null)
  }

  map<U>(fn: (value: T) => U): Option<U> {
    return this.value !== null ? Option.some(fn(this.value)) : Option.none()
  }

  unwrapOr(defaultValue: T): T {
    return this.value !== null ? this.value : defaultValue
  }
}
```

---

## Related

- [Best Practices](./best-practices.md)
- [Testing](./testing.md)
- [SOLID Principles](../../principles/solid.md)
