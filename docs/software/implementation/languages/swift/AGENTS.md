# Swift Coding Guidelines

Swift-specific instructions for AI coding agents working on Swift projects for macOS, iOS, and other Apple platforms.

---

## Quick Reference

### Type Safety
- ✅ Leverage Swift's strong type system (Optionals, Enums, Generics)
- ✅ Use `guard let` and `if let` for optional unwrapping
- ✅ Prefer non-optional types when possible
- ✅ Use `enum` with associated values for complex state
- ✅ Leverage type inference where it improves readability
- ❌ Avoid force unwrapping (`!`) unless absolutely safe
- ❌ Avoid implicitly unwrapped optionals (`!`) in most cases

### Modern Syntax
- ✅ Use `async`/`await` for asynchronous operations (Swift 5.5+)
- ✅ Use structured concurrency (Tasks, TaskGroups, Actors)
- ✅ Prefer value types (structs) over reference types (classes)
- ✅ Use property wrappers (`@State`, `@Published`, `@Environment`)
- ✅ Leverage closures and trailing closure syntax
- ✅ Use `defer` for cleanup operations

### Error Handling
- ✅ Use `throws` for functions that can fail
- ✅ Use `Result<Success, Failure>` for async error handling
- ✅ Create custom error types conforming to `Error` protocol
- ✅ Use `do-catch` blocks for error handling
- ✅ Use `try?` when failure can be ignored
- ❌ Avoid using `try!` unless failure is truly impossible

### Code Organization
- ✅ One type per file (classes, structs, enums)
- ✅ Use extensions to organize protocol conformances
- ✅ Group related functionality in modules
- ✅ Follow Apple's naming conventions (camelCase for variables/functions, PascalCase for types)
- ✅ Use `// MARK:` comments for code organization

### Memory Management
- ✅ Use `weak` and `unowned` to break reference cycles
- ✅ Prefer value types to avoid reference counting overhead
- ✅ Use `[weak self]` in closures that capture self
- ✅ Understand when to use `weak` vs `unowned`

---

## Detailed Guidelines

For comprehensive Swift best practices, see:
- **[Best Practices](./best-practices.md)**: Type safety, protocols, performance
- **[Testing](./testing.md)**: XCTest, test patterns, CI/CD
- **[Patterns](./patterns.md)**: Protocol-oriented programming, common design patterns

---

## Common Pitfalls to Avoid

### ❌ Force Unwrapping
```swift
// Bad: Unsafe force unwrap
let name = user!.name

// Good: Safe optional handling
guard let user = user else { return }
let name = user.name

// Good: Optional chaining
let name = user?.name
```

### ❌ Retain Cycles in Closures
```swift
// Bad: Strong reference cycle
someMethod {
    self.doSomething()
}

// Good: Weak self to avoid cycles
someMethod { [weak self] in
    self?.doSomething()
}

// Good: Unowned when self will always exist
someMethod { [unowned self] in
    self.doSomething()
}
```

### ❌ Using Classes When Structs Are Better
```swift
// Bad: Unnecessary reference type
class Point {
    var x: Double
    var y: Double
}

// Good: Value type for data
struct Point {
    var x: Double
    var y: Double
}
```

### ❌ Ignoring Optionals with `try!` or `as!`
```swift
// Bad: Force try
let data = try! JSONDecoder().decode(User.self, from: data)

// Good: Handle errors properly
do {
    let data = try JSONDecoder().decode(User.self, from: data)
} catch {
    // Handle error
}
```

---

## Project Setup

### Swift Package Manager (SPM)
```swift
// Package.swift
// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "MyPackage",
    platforms: [.macOS(.v13), .iOS(.v16)],
    products: [
        .library(name: "MyPackage", targets: ["MyPackage"]),
    ],
    dependencies: [
        // Dependencies go here
    ],
    targets: [
        .target(name: "MyPackage", dependencies: []),
        .testTarget(name: "MyPackageTests", dependencies: ["MyPackage"]),
    ]
)
```

### Recommended Tools
- **IDE**: Xcode (official) or AppCode
- **Package Manager**: Swift Package Manager (SPM)
- **Linter**: SwiftLint
- **Formatter**: swift-format (Apple's official formatter)
- **Testing**: XCTest (built-in) or Quick/Nimble
- **Dependency Management**: SPM (preferred) or CocoaPods/Carthage (legacy)
- **CI/CD**: Xcode Cloud, GitHub Actions with xcodebuild

### Xcode Project Settings
- Enable "Treat Warnings as Errors" in production builds
- Use Swift 5.9+ language version
- Enable "Strict Concurrency Checking" for async/await safety
- Use "Explicit" module system for better isolation

---

## Swift Concurrency

### Async/Await
```swift
// Good: Modern async/await
func fetchUser(id: String) async throws -> User {
    let url = URL(string: "https://api.example.com/users/\(id)")!
    let (data, _) = try await URLSession.shared.data(from: url)
    return try JSONDecoder().decode(User.self, from: data)
}
```

### Actors for Thread Safety
```swift
// Good: Actor for thread-safe state
actor DataCache {
    private var cache: [String: Data] = [:]

    func get(_ key: String) -> Data? {
        cache[key]
    }

    func set(_ key: String, data: Data) {
        cache[key] = data
    }
}
```

---

## Protocol-Oriented Programming

Swift emphasizes protocols over inheritance:

```swift
// Good: Protocol with default implementation
protocol Identifiable {
    var id: String { get }
}

extension Identifiable {
    var displayName: String {
        "Item \(id)"
    }
}

// Good: Protocol composition
typealias Entity = Identifiable & Codable & Equatable
```

---

## Integration with General Principles

Swift code should also follow:
- **[Code Quality Principles](../../general/code-quality.md)**: Explicitness, locality, fail-fast
- **[Unix Philosophy](../../../../principles/unix-philosophy.md)**: Composability, single responsibility

---

## When to Escalate

Consult human developers for:
- **Major architectural decisions**: Choosing frameworks (SwiftUI vs UIKit), state management
- **API design**: Public interfaces for libraries and frameworks
- **Performance trade-offs**: Optimization vs. maintainability
- **Platform-specific decisions**: Feature availability across iOS/macOS/watchOS versions
- **Memory management complexity**: Complex ownership scenarios
