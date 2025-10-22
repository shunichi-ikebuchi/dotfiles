# TypeScript Testing Strategies

Testing guide for TypeScript projects.

---

## Testing Frameworks

### Recommended: Vitest
- Modern, fast, ESM-first
- Compatible with Jest API
- Built-in TypeScript support
- Excellent DX with Vite integration

### Alternative: Jest
- Mature, widely adopted
- Extensive ecosystem
- May require additional configuration for TypeScript

---

## Test Structure

### Unit Tests

```typescript
import { describe, it, expect } from 'vitest'
import { calculateDiscount } from './pricing'

describe('calculateDiscount', () => {
  it('applies 10% discount for orders over $100', () => {
    expect(calculateDiscount(150)).toBe(135)
  })

  it('applies no discount for orders under $100', () => {
    expect(calculateDiscount(50)).toBe(50)
  })

  it('throws error for negative amounts', () => {
    expect(() => calculateDiscount(-10)).toThrow('Amount cannot be negative')
  })
})
```

### Integration Tests

```typescript
import { describe, it, expect, beforeEach, afterEach } from 'vitest'
import { startTestServer, stopTestServer } from './test-utils'

describe('UserAPI Integration', () => {
  beforeEach(async () => {
    await startTestServer()
  })

  afterEach(async () => {
    await stopTestServer()
  })

  it('creates a new user', async () => {
    const response = await fetch('/api/users', {
      method: 'POST',
      body: JSON.stringify({ name: 'Test User', email: 'test@example.com' }),
    })
    const user = await response.json()
    expect(user.id).toBeDefined()
    expect(user.name).toBe('Test User')
  })
})
```

---

## Mocking

### Function Mocks

```typescript
import { vi } from 'vitest'

const mockFetch = vi.fn()
global.fetch = mockFetch

mockFetch.mockResolvedValue({
  ok: true,
  json: async () => ({ id: '123', name: 'User' }),
})
```

### Module Mocks

```typescript
vi.mock('./database', () => ({
  query: vi.fn(),
}))
```

---

## Type-Safe Testing

### Testing Types with `expectTypeOf`

```typescript
import { expectTypeOf } from 'vitest'

expectTypeOf<User>().toHaveProperty('id')
expectTypeOf<User['id']>().toBeString()
```

---

## Best Practices

- ✅ Test behavior, not implementation
- ✅ Use descriptive test names
- ✅ Follow AAA pattern: Arrange, Act, Assert
- ✅ Mock external dependencies
- ✅ Use test fixtures for complex data
- ❌ Don't test private methods directly
- ❌ Avoid testing library code

---

## Related

- [Best Practices](./best-practices.md)
- [Patterns](./patterns.md)
- [General Testing Strategy](../../principles/testing-qa.md)
