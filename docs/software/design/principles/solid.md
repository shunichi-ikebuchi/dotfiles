# SOLID Principles

**Design principles for creating maintainable, flexible, and scalable object-oriented code.**

SOLID represents five fundamental design principles that guide how we structure classes and modules. These principles help prevent code from becoming rigid, fragile, and difficult to change.

---

## Overview: Why SOLID Matters

**Common Problems SOLID Solves**:
- **Rigid code**: Changes require modifying many places
- **Fragile code**: Changes break unrelated parts
- **Immobile code**: Can't reuse code without dragging dependencies
- **Viscous development**: Doing things right is harder than hacking

**SOLID as a System**: These principles work together. Violating one often leads to violating others.

---

## 1. Single Responsibility Principle (SRP)

**A class should have one, and only one, reason to change.**

### Core Idea

Each module, class, or function should be responsible for a single part of the functionality. If you can describe what it does with "and" or "or", it's doing too much.

### Why It Matters

- **Easier to understand**: Focused purpose is clear
- **Easier to test**: Fewer scenarios to cover
- **Easier to change**: Changes are localized
- **Reduces coupling**: Fewer dependencies between components

### Example

**❌ Violates SRP (Multiple responsibilities)**:
```typescript
class User {
  constructor(
    public name: string,
    public email: string
  ) {}

  // Responsibility 1: User data validation
  validate(): boolean {
    return this.email.includes('@')
  }

  // Responsibility 2: Database persistence
  save(): void {
    database.execute(`INSERT INTO users...`)
  }

  // Responsibility 3: Email notification
  sendWelcomeEmail(): void {
    emailService.send(this.email, 'Welcome!')
  }
}
```

**Why this is problematic**:
- Changes to email validation logic require modifying User class
- Changes to database schema require modifying User class
- Changes to email templates require modifying User class
- Can't test validation without database/email dependencies

**✅ Follows SRP (Single responsibility per class)**:
```typescript
// Responsibility: User data representation
class User {
  constructor(
    public name: string,
    public email: string
  ) {}
}

// Responsibility: User validation
class UserValidator {
  validate(user: User): boolean {
    return user.email.includes('@') && user.name.length > 0
  }
}

// Responsibility: User persistence
class UserRepository {
  save(user: User): void {
    database.execute(`INSERT INTO users...`)
  }
}

// Responsibility: User notifications
class UserNotificationService {
  sendWelcomeEmail(user: User): void {
    emailService.send(user.email, 'Welcome!')
  }
}
```

### How to Apply

1. **Identify reasons to change**: List all possible reasons a class might need modification
2. **Count responsibilities**: If there are multiple reasons, there are multiple responsibilities
3. **Extract and separate**: Create separate classes for each responsibility
4. **Compose at higher level**: Coordinate these classes from a higher-level orchestrator

### Pitfalls

- **Over-fragmentation**: Don't create a class for every single method (use judgment)
- **Premature splitting**: Wait until you have a real reason to split (YAGNI applies)
- **Context matters**: "Responsibility" depends on your system's architecture level

---

## 2. Open/Closed Principle (OCP)

**Software entities should be open for extension but closed for modification.**

### Core Idea

You should be able to add new functionality without changing existing code. Extend behavior through composition, inheritance, or plugins—not by modifying existing classes.

### Why It Matters

- **Stability**: Existing code stays untouched, reducing regression risk
- **Scalability**: Adding features doesn't require cascading changes
- **Safe evolution**: Can extend without breaking existing clients
- **Plugin architecture**: Enables modular, extensible systems

### Example

**❌ Violates OCP (Modification required for extension)**:
```typescript
class PaymentProcessor {
  processPayment(type: string, amount: number): void {
    if (type === 'credit-card') {
      // Credit card logic
      console.log(`Processing credit card payment: $${amount}`)
    } else if (type === 'paypal') {
      // PayPal logic
      console.log(`Processing PayPal payment: $${amount}`)
    }
    // Adding new payment method requires modifying this class
  }
}
```

**Why this is problematic**:
- Adding new payment method (e.g., Bitcoin) requires modifying `processPayment`
- Risk of breaking existing payment methods
- Testing requires re-testing all payment types
- Violates OCP: not closed for modification

**✅ Follows OCP (Extension without modification)**:
```typescript
// Abstraction (interface)
interface PaymentMethod {
  process(amount: number): void
}

// Concrete implementations (closed for modification, open for extension)
class CreditCardPayment implements PaymentMethod {
  process(amount: number): void {
    console.log(`Processing credit card payment: $${amount}`)
  }
}

class PayPalPayment implements PaymentMethod {
  process(amount: number): void {
    console.log(`Processing PayPal payment: $${amount}`)
  }
}

// New payment method: no modification to existing code
class BitcoinPayment implements PaymentMethod {
  process(amount: number): void {
    console.log(`Processing Bitcoin payment: $${amount}`)
  }
}

// Payment processor (closed for modification)
class PaymentProcessor {
  processPayment(method: PaymentMethod, amount: number): void {
    method.process(amount)
  }
}
```

### How to Apply

1. **Identify variation points**: Where might new features be added?
2. **Abstract the variation**: Create interfaces or abstract classes
3. **Depend on abstractions**: Use the interface, not concrete implementations
4. **Extend through new implementations**: Add new classes, don't modify existing ones

### Patterns That Enable OCP

- **Strategy Pattern**: Encapsulate algorithms in separate classes
- **Template Method**: Define skeleton, let subclasses fill in details
- **Plugin Architecture**: Load extensions dynamically
- **Dependency Injection**: Inject different implementations

### Pitfalls

- **Over-abstraction**: Don't create interfaces for everything "just in case"
- **Premature generalization**: Wait for second or third use case before abstracting
- **Apply when it matters**: Focus on likely extension points, not hypothetical ones

---

## 3. Liskov Substitution Principle (LSP)

**Subtypes must be substitutable for their base types without altering correctness.**

### Core Idea

If class B is a subtype of class A, you should be able to replace A with B without breaking the program. Subclasses should strengthen, not weaken, the base class contract.

### Why It Matters

- **Polymorphism works correctly**: Clients can rely on base class behavior
- **Prevents surprising bugs**: Subclasses don't violate expectations
- **Enables safe refactoring**: Can swap implementations confidently
- **Maintains abstraction integrity**: Interface contracts remain trustworthy

### Example

**❌ Violates LSP (Subclass breaks contract)**:
```typescript
class Rectangle {
  constructor(
    protected width: number,
    protected height: number
  ) {}

  setWidth(width: number): void {
    this.width = width
  }

  setHeight(height: number): void {
    this.height = height
  }

  getArea(): number {
    return this.width * this.height
  }
}

class Square extends Rectangle {
  setWidth(width: number): void {
    this.width = width
    this.height = width // Violates LSP: changes behavior
  }

  setHeight(height: number): void {
    this.width = height // Violates LSP: changes behavior
    this.height = height
  }
}

// Client code expecting Rectangle behavior
function testRectangle(rect: Rectangle) {
  rect.setWidth(5)
  rect.setHeight(10)
  console.log(rect.getArea()) // Expects 50
}

const square = new Square(0, 0)
testRectangle(square) // Prints 100, not 50! 🐛
```

**Why this is problematic**:
- Square changes width/height coupling, violating Rectangle's contract
- Client expecting independent width/height gets surprising behavior
- Substitution fails: Square is NOT a valid Rectangle substitute

**✅ Follows LSP (Proper abstraction)**:
```typescript
// Base abstraction
interface Shape {
  getArea(): number
}

// Independent implementations (no inheritance relationship)
class Rectangle implements Shape {
  constructor(
    private width: number,
    private height: number
  ) {}

  setWidth(width: number): void {
    this.width = width
  }

  setHeight(height: number): void {
    this.height = height
  }

  getArea(): number {
    return this.width * this.height
  }
}

class Square implements Shape {
  constructor(private size: number) {}

  setSize(size: number): void {
    this.size = size
  }

  getArea(): number {
    return this.size * this.size
  }
}
```

### LSP Rules

**Subclasses must**:
1. **Accept same inputs** (or weaker preconditions)
2. **Provide same outputs** (or stronger postconditions)
3. **Maintain invariants** of the base class
4. **Not throw unexpected exceptions** beyond base class contract

### How to Apply

1. **Check preconditions**: Subclass should accept >= what base accepts
2. **Check postconditions**: Subclass should guarantee >= what base guarantees
3. **Check invariants**: Properties true in base must remain true in subclass
4. **Verify substitution**: Can you replace base with subclass without surprises?

### Pitfalls

- **Is-A vs Behaves-Like-A**: Inheritance should model behavior, not just taxonomy
- **Real-world relationships don't always map**: Square "is-a" Rectangle mathematically, but not behaviorally in code
- **Favor composition**: Often safer than inheritance for extending behavior

---

## 4. Interface Segregation Principle (ISP)

**Clients should not be forced to depend on interfaces they don't use.**

### Core Idea

Create small, focused interfaces instead of large, bloated ones. Clients should only need to know about methods they actually use.

### Why It Matters

- **Reduces coupling**: Clients don't depend on irrelevant functionality
- **Easier to implement**: Smaller contracts are simpler to satisfy
- **Clearer intent**: Interface names convey precise purpose
- **Prevents cascading changes**: Changes to unused methods don't affect clients

### Example

**❌ Violates ISP (Fat interface)**:
```typescript
interface Worker {
  work(): void
  eat(): void
  sleep(): void
  getPaid(): void
}

// Robot worker doesn't eat or sleep!
class RobotWorker implements Worker {
  work(): void {
    console.log('Robot working')
  }

  eat(): void {
    throw new Error('Robots don\'t eat') // Forced to implement
  }

  sleep(): void {
    throw new Error('Robots don\'t sleep') // Forced to implement
  }

  getPaid(): void {
    throw new Error('Robots don\'t get paid') // Forced to implement
  }
}

// Human worker is fine
class HumanWorker implements Worker {
  work(): void { console.log('Human working') }
  eat(): void { console.log('Human eating') }
  sleep(): void { console.log('Human sleeping') }
  getPaid(): void { console.log('Human getting paid') }
}
```

**Why this is problematic**:
- RobotWorker forced to implement irrelevant methods
- Throws exceptions or provides meaningless implementations
- Clients depending on Worker get methods they might not need

**✅ Follows ISP (Segregated interfaces)**:
```typescript
// Focused, role-specific interfaces
interface Workable {
  work(): void
}

interface Eatable {
  eat(): void
}

interface Sleepable {
  sleep(): void
}

interface Payable {
  getPaid(): void
}

// Robot implements only relevant interfaces
class RobotWorker implements Workable {
  work(): void {
    console.log('Robot working')
  }
}

// Human implements all relevant interfaces
class HumanWorker implements Workable, Eatable, Sleepable, Payable {
  work(): void { console.log('Human working') }
  eat(): void { console.log('Human eating') }
  sleep(): void { console.log('Human sleeping') }
  getPaid(): void { console.log('Human getting paid') }
}

// Clients depend only on what they need
function manageWork(worker: Workable) {
  worker.work() // Only depends on Workable
}

function serveLunch(eater: Eatable) {
  eater.eat() // Only depends on Eatable
}
```

### How to Apply

1. **Identify client needs**: What does each client actually use?
2. **Split fat interfaces**: Break large interfaces into focused roles
3. **Compose when needed**: Classes can implement multiple small interfaces
4. **Name by role**: Interface names should reflect specific capability (e.g., `Readable`, `Writable`)

### Patterns That Support ISP

- **Role Interfaces**: Interfaces named by what they do (e.g., `Sortable`, `Loggable`)
- **Interface Composition**: Combine small interfaces when needed
- **Adapter Pattern**: Convert fat interfaces to thin ones for specific clients

### Pitfalls

- **Over-segregation**: Don't create one-method interfaces for everything
- **Cohesion matters**: Methods that always go together should stay together
- **Context-dependent**: What's "too large" depends on your domain

---

## 5. Dependency Inversion Principle (DIP)

**High-level modules should not depend on low-level modules. Both should depend on abstractions.**

### Core Idea

Depend on interfaces or abstract classes, not concrete implementations. The direction of dependency should point toward abstraction, not concretion.

### Why It Matters

- **Decoupling**: High-level logic independent of implementation details
- **Testability**: Can inject mocks/stubs for testing
- **Flexibility**: Swap implementations without changing clients
- **Reusability**: High-level modules can work with different low-level modules

### Example

**❌ Violates DIP (Direct dependency on concrete class)**:
```typescript
// Low-level module
class MySQLDatabase {
  save(data: string): void {
    console.log(`Saving to MySQL: ${data}`)
  }
}

// High-level module depends on concrete MySQLDatabase
class UserService {
  private database: MySQLDatabase // Tight coupling!

  constructor() {
    this.database = new MySQLDatabase() // Can't swap implementation
  }

  createUser(name: string): void {
    this.database.save(name)
  }
}
```

**Why this is problematic**:
- UserService can ONLY work with MySQL
- Can't test UserService without real MySQL database
- Switching to PostgreSQL requires modifying UserService
- High-level (UserService) depends on low-level (MySQLDatabase)

**✅ Follows DIP (Depend on abstraction)**:
```typescript
// Abstraction (high-level and low-level both depend on this)
interface Database {
  save(data: string): void
}

// Low-level modules implement abstraction
class MySQLDatabase implements Database {
  save(data: string): void {
    console.log(`Saving to MySQL: ${data}`)
  }
}

class PostgreSQLDatabase implements Database {
  save(data: string): void {
    console.log(`Saving to PostgreSQL: ${data}`)
  }
}

class InMemoryDatabase implements Database {
  save(data: string): void {
    console.log(`Saving to memory: ${data}`)
  }
}

// High-level module depends on abstraction
class UserService {
  constructor(private database: Database) {} // Depends on interface

  createUser(name: string): void {
    this.database.save(name)
  }
}

// Dependency injection at runtime
const prodService = new UserService(new MySQLDatabase())
const testService = new UserService(new InMemoryDatabase())
```

### DIP vs Dependency Injection (DI)

**Dependency Inversion Principle (DIP)**: *Design principle*
- Depend on abstractions, not concretions
- About the direction of dependencies in code structure

**Dependency Injection (DI)**: *Implementation technique*
- Pass dependencies from outside (constructor, setter, parameter)
- One way to achieve DIP

DIP is the "what" (principle), DI is the "how" (technique).

### How to Apply

1. **Identify dependencies**: What concrete classes does your module depend on?
2. **Extract interface**: Create abstraction representing the capability you need
3. **Invert the dependency**: Depend on the interface, not the concrete class
4. **Inject at runtime**: Pass concrete implementation from outside

### Patterns That Enable DIP

- **Dependency Injection**: Pass dependencies externally
- **Service Locator**: Look up dependencies from registry
- **Factory Pattern**: Encapsulate object creation
- **Strategy Pattern**: Inject different algorithms

### Pitfalls

- **Not every dependency needs inversion**: Don't abstract stable, unlikely-to-change classes (e.g., standard library)
- **Abstraction cost**: Adds indirection and complexity
- **Apply strategically**: Focus on volatile dependencies (databases, external services, changing algorithms)

---

## Applying SOLID Together

### How Principles Reinforce Each Other

**SRP + OCP**: Single-responsibility classes are easier to extend without modification

**LSP + OCP**: Correct substitution enables safe extension through polymorphism

**ISP + DIP**: Small interfaces make it easier to depend on abstractions

**DIP + OCP**: Depending on abstractions enables extension through new implementations

### When to Apply SOLID

**✅ Apply when**:
- Building reusable libraries or frameworks
- Code that will evolve frequently
- Complex business logic with multiple variations
- Team collaboration on shared codebase

**⚠️ Use judgment when**:
- Prototyping or exploring solutions
- Simple, stable code unlikely to change
- Performance-critical code (abstraction has cost)
- Early-stage projects with unclear requirements

### Golden Rule

**SOLID principles are tools, not laws.** Apply them when they solve real problems, not dogmatically.

Ask:
1. **Does this make the code easier to change?**
2. **Does this reduce coupling?**
3. **Does this improve testability?**
4. **Is the added complexity worth it?**

If yes to most → apply SOLID.
If no → simpler might be better.

---

## Common Anti-Patterns

### 1. SOLID Dogma

**Problem**: Applying all principles everywhere, even when harmful

**Solution**: Use judgment. Simple code beats over-engineered code.

### 2. Premature Abstraction

**Problem**: Creating interfaces and abstractions "just in case"

**Solution**: Wait for second or third use case. YAGNI (You Aren't Gonna Need It).

### 3. Interface Explosion

**Problem**: Creating too many tiny interfaces

**Solution**: Balance ISP with cohesion. Group related methods.

### 4. Abstraction for Its Own Sake

**Problem**: Abstracting stable dependencies (e.g., standard library)

**Solution**: Abstract volatile dependencies, not stable ones.

---

## References and Further Reading

- **Books**:
  - *Clean Architecture* by Robert C. Martin
  - *Design Patterns* by Gang of Four
  - *Refactoring* by Martin Fowler

- **Key Insight**: SOLID principles emerged from decades of OOP experience. They codify patterns that consistently lead to maintainable code.

- **Context Matters**: These principles assume object-oriented design. Functional programming has different but related principles (immutability, pure functions, composition).
