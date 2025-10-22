# Java Coding Guidelines

Java-specific instructions for AI coding agents working on Java projects.

---

## Quick Reference

### Type Safety & Null Safety
- ✅ Use Optional<T> for nullable return values
- ✅ Prefer immutable objects (final fields, no setters)
- ✅ Use @NonNull/@Nullable annotations (Checker Framework, JetBrains)
- ✅ Validate inputs early with Objects.requireNonNull()
- ❌ Avoid returning null from methods (use Optional or throw)
- ❌ Avoid catching generic Exception (be specific)

### Modern Java Features (Java 17+)
- ✅ Use Records for immutable data carriers
- ✅ Use Sealed Classes for restricted type hierarchies
- ✅ Pattern Matching for instanceof
- ✅ Text Blocks for multi-line strings
- ✅ var for local variables when type is obvious
- ✅ Switch Expressions (not statements)

### Error Handling
- ✅ Use specific exception types (IllegalArgumentException, IllegalStateException)
- ✅ Create custom exceptions for domain-specific errors
- ✅ Use try-with-resources for AutoCloseable resources
- ✅ Fail fast: validate inputs at method entry
- ❌ Avoid empty catch blocks
- ❌ Avoid catching Throwable or Error

### Code Organization
- ✅ Package by feature, not by layer
- ✅ Keep classes small and focused (Single Responsibility)
- ✅ Use interfaces for public contracts
- ✅ Co-locate tests with source (src/test/java mirroring src/main/java)
- ✅ Use builder pattern for complex object construction

### Naming Conventions
- ✅ Classes: PascalCase (UserService, OrderRepository)
- ✅ Methods: camelCase (getUserById, processOrder)
- ✅ Constants: UPPER_SNAKE_CASE (MAX_RETRY_COUNT)
- ✅ Packages: lowercase (com.company.module)

---

## Detailed Guidelines

For comprehensive Java best practices, see:
- **[Best Practices](./best-practices.md)**: Immutability, concurrency, performance

---

## Common Pitfalls to Avoid

### ❌ Null Returns Instead of Optional
```java
// Bad: Null return
public User findUserById(Long id) {
    return userMap.get(id); // May return null
}

// Good: Optional
public Optional<User> findUserById(Long id) {
    return Optional.ofNullable(userMap.get(id));
}
```

### ❌ Mutable Collections in Public APIs
```java
// Bad: Exposes mutable collection
public List<String> getItems() {
    return items; // Caller can modify
}

// Good: Defensive copy or immutable
public List<String> getItems() {
    return List.copyOf(items); // Immutable copy (Java 10+)
}
```

### ❌ String Concatenation in Loops
```java
// Bad: Inefficient string building
String result = "";
for (String item : items) {
    result += item + ", ";
}

// Good: StringBuilder
StringBuilder sb = new StringBuilder();
for (String item : items) {
    sb.append(item).append(", ");
}
String result = sb.toString();
```

### ❌ Not Closing Resources
```java
// Bad: Resource leak
InputStream is = new FileInputStream("file.txt");
// ... use stream

// Good: try-with-resources
try (InputStream is = new FileInputStream("file.txt")) {
    // ... use stream
} // Automatically closed
```

---

## Project Setup

### Recommended Build Tools
- **Maven** (traditional, XML-based)
- **Gradle** (modern, Groovy/Kotlin DSL, recommended for new projects)

### Recommended Tools & Libraries
- **Linter**: Checkstyle or SpotBugs
- **Formatter**: Google Java Format or Spotless
- **Testing**: JUnit 5 (Jupiter) + AssertJ or Hamcrest
- **Mocking**: Mockito
- **Static Analysis**: SonarQube, Error Prone
- **Dependency Injection**: Spring Framework (if applicable)
- **Logging**: SLF4J + Logback

### Recommended Java Version
- **Minimum**: Java 17 (LTS)
- **Recommended**: Java 21+ (latest LTS with modern features)

### Sample pom.xml (Maven)
```xml
<properties>
    <java.version>17</java.version>
    <maven.compiler.source>17</maven.compiler.source>
    <maven.compiler.target>17</maven.compiler.target>
</properties>

<dependencies>
    <!-- Testing -->
    <dependency>
        <groupId>org.junit.jupiter</groupId>
        <artifactId>junit-jupiter</artifactId>
        <version>5.10.0</version>
        <scope>test</scope>
    </dependency>
    <dependency>
        <groupId>org.mockito</groupId>
        <artifactId>mockito-core</artifactId>
        <version>5.5.0</version>
        <scope>test</scope>
    </dependency>
</dependencies>
```

---

## Integration with General Principles

Java code should also follow:
- **[Code Quality Principles](../../general/code-quality.md)**: Explicitness, locality, fail-fast
- **[SOLID Principles](../../../design/principles/solid.md)**: Object-oriented design
- **[Unix Philosophy](../../../design/practices/unix-philosophy.md)**: Composability, single responsibility

---

## When to Escalate

Consult human developers for:
- **Framework selection**: Spring Boot vs. Quarkus vs. Micronaut
- **Architecture decisions**: Microservices vs. monolith, hexagonal architecture
- **Performance-critical code**: JVM tuning, memory optimization
- **Security decisions**: Authentication/authorization patterns
- **Major version migrations**: Java version upgrades
