# Java Best Practices

Comprehensive best practices for writing clean, maintainable, and efficient Java code.

---

## Immutability

### Prefer Immutable Objects
Immutable objects are thread-safe, easier to reason about, and prevent bugs.

```java
// Good: Immutable with record (Java 14+)
public record User(Long id, String name, String email) {}

// Good: Immutable with traditional class
public final class User {
    private final Long id;
    private final String name;
    private final String email;

    public User(Long id, String name, String email) {
        this.id = Objects.requireNonNull(id);
        this.name = Objects.requireNonNull(name);
        this.email = Objects.requireNonNull(email);
    }

    // Only getters, no setters
    public Long id() { return id; }
    public String name() { return name; }
    public String email() { return email; }
}

// Bad: Mutable
public class User {
    private Long id;
    private String name;

    public void setId(Long id) { this.id = id; } // Mutability
    public void setName(String name) { this.name = name; }
}
```

### Collections
```java
// Good: Immutable collections
List<String> items = List.of("a", "b", "c"); // Java 9+
Map<String, Integer> map = Map.of("key1", 1, "key2", 2);

// For larger collections
List<String> immutable = List.copyOf(mutableList);

// Bad: Mutable exposed
private List<String> items = new ArrayList<>();
public List<String> getItems() {
    return items; // Callers can modify!
}
```

---

## Null Safety

### Use Optional for Nullable Returns
```java
// Good: Optional signals "may be absent"
public Optional<User> findById(Long id) {
    return Optional.ofNullable(repository.get(id));
}

// Usage
findById(123)
    .map(User::name)
    .orElse("Unknown");

// Bad: Null return
public User findById(Long id) {
    return repository.get(id); // Null is a time bomb
}
```

### Input Validation
```java
// Good: Fail fast
public void process(String input) {
    Objects.requireNonNull(input, "input must not be null");
    if (input.isEmpty()) {
        throw new IllegalArgumentException("input must not be empty");
    }
    // ... process
}

// Bad: No validation
public void process(String input) {
    // NPE waiting to happen
    String upper = input.toUpperCase();
}
```

---

## Exception Handling

### Be Specific
```java
// Good: Specific exceptions
public User loadUser(Long id) throws UserNotFoundException {
    return repository.findById(id)
        .orElseThrow(() -> new UserNotFoundException(id));
}

// Bad: Generic exception
public User loadUser(Long id) throws Exception {
    // Too broad
}
```

### Custom Exceptions
```java
// Good: Domain-specific exception
public class UserNotFoundException extends RuntimeException {
    public UserNotFoundException(Long id) {
        super("User not found: " + id);
    }
}

// Bad: Using generic exceptions
throw new RuntimeException("User not found"); // No context
```

### Try-with-resources
```java
// Good: Automatic resource management
public String readFile(Path path) throws IOException {
    try (BufferedReader reader = Files.newBufferedReader(path)) {
        return reader.lines().collect(Collectors.joining("\n"));
    }
}

// Bad: Manual closing
public String readFile(Path path) throws IOException {
    BufferedReader reader = Files.newBufferedReader(path);
    try {
        return reader.lines().collect(Collectors.joining("\n"));
    } finally {
        reader.close(); // Error-prone
    }
}
```

---

## Modern Java Features

### Records (Java 14+)
```java
// Good: Concise immutable data carrier
public record Point(int x, int y) {}

// Automatically generates:
// - Constructor
// - Getters (x(), y())
// - equals(), hashCode(), toString()

// With validation
public record Point(int x, int y) {
    public Point {
        if (x < 0 || y < 0) {
            throw new IllegalArgumentException("Coordinates must be non-negative");
        }
    }
}
```

### Sealed Classes (Java 17+)
```java
// Good: Restricted hierarchy
public sealed interface Result<T> permits Success, Failure {
    record Success<T>(T value) implements Result<T> {}
    record Failure<T>(String error) implements Result<T> {}
}

// Pattern matching with sealed types
public String formatResult(Result<String> result) {
    return switch (result) {
        case Success<String> s -> "Success: " + s.value();
        case Failure<String> f -> "Error: " + f.error();
    }; // Exhaustive - compiler checks all cases
}
```

### Pattern Matching (Java 16+)
```java
// Good: Pattern matching for instanceof
public double getPerimeter(Shape shape) {
    return switch (shape) {
        case Circle c -> 2 * Math.PI * c.radius();
        case Rectangle r -> 2 * (r.width() + r.height());
        case Square s -> 4 * s.side();
    };
}

// Old way
if (shape instanceof Circle) {
    Circle c = (Circle) shape;
    return 2 * Math.PI * c.radius();
} else if (shape instanceof Rectangle) {
    // ... more casting
}
```

### Text Blocks (Java 15+)
```java
// Good: Multi-line strings
String json = """
    {
        "name": "John",
        "age": 30
    }
    """;

// Bad: String concatenation
String json = "{\n" +
              "    \"name\": \"John\",\n" +
              "    \"age\": 30\n" +
              "}";
```

---

## Performance

### Stream API - When to Use
```java
// Good: Streams for declarative operations
List<String> activeUserNames = users.stream()
    .filter(User::isActive)
    .map(User::name)
    .sorted()
    .toList();

// Bad: Streams for simple operations (overhead)
// If you just need to iterate, use for-each
List<String> names = new ArrayList<>();
for (User user : users) {
    names.add(user.name()); // Simpler and faster
}
```

### String Concatenation
```java
// Good: StringBuilder for loops
StringBuilder sb = new StringBuilder();
for (int i = 0; i < 1000; i++) {
    sb.append("Item ").append(i).append(", ");
}
String result = sb.toString();

// Bad: String concatenation in loops
String result = "";
for (int i = 0; i < 1000; i++) {
    result += "Item " + i + ", "; // Creates new String each time
}
```

---

## Code Organization

### Package by Feature
```
com.company.ecommerce
├── order
│   ├── Order.java
│   ├── OrderService.java
│   ├── OrderRepository.java
│   └── OrderController.java
├── payment
│   ├── Payment.java
│   ├── PaymentService.java
│   └── PaymentGateway.java
└── user
    ├── User.java
    ├── UserService.java
    └── UserRepository.java
```

### Small, Focused Classes
```java
// Good: Single Responsibility
public class UserValidator {
    public void validate(User user) {
        // Only validation logic
    }
}

public class UserRepository {
    public Optional<User> findById(Long id) {
        // Only persistence logic
    }
}

// Bad: God class
public class UserManager {
    public void validate(User user) { }
    public void save(User user) { }
    public void sendEmail(User user) { }
    public void logActivity(User user) { }
    // Too many responsibilities
}
```

---

## Testing

### Use JUnit 5
```java
import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;

class UserServiceTest {
    @Test
    void shouldFindUserById() {
        // Given
        UserService service = new UserService();

        // When
        Optional<User> user = service.findById(1L);

        // Then
        assertTrue(user.isPresent());
        assertEquals("John", user.get().name());
    }
}
```

### AssertJ for Fluent Assertions
```java
import static org.assertj.core.api.Assertions.*;

@Test
void shouldReturnActiveUsers() {
    List<User> users = service.getActiveUsers();

    assertThat(users)
        .isNotEmpty()
        .hasSize(3)
        .extracting(User::name)
        .containsExactly("Alice", "Bob", "Charlie");
}
```

---

## Concurrency

### Use Higher-Level Abstractions
```java
// Good: ExecutorService
ExecutorService executor = Executors.newFixedThreadPool(10);
Future<String> future = executor.submit(() -> {
    return expensiveComputation();
});
String result = future.get();
executor.shutdown();

// Bad: Raw threads
Thread thread = new Thread(() -> {
    expensiveComputation();
});
thread.start();
```

### Thread-Safe Collections
```java
// Good: Concurrent collections
Map<String, User> cache = new ConcurrentHashMap<>();
BlockingQueue<Task> queue = new LinkedBlockingQueue<>();

// Bad: Synchronized wrapper (lower performance)
Map<String, User> cache = Collections.synchronizedMap(new HashMap<>());
```

---

## Logging

### Use SLF4J
```java
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

public class UserService {
    private static final Logger log = LoggerFactory.getLogger(UserService.class);

    public void processUser(User user) {
        log.info("Processing user: {}", user.id());
        try {
            // ... process
            log.debug("User processed successfully: {}", user.id());
        } catch (Exception e) {
            log.error("Failed to process user: {}", user.id(), e);
        }
    }
}
```

### Log Levels
- **ERROR**: System errors, exceptions that need immediate attention
- **WARN**: Potential issues, deprecated API usage
- **INFO**: Important business events (user login, order created)
- **DEBUG**: Detailed diagnostic information
- **TRACE**: Very detailed diagnostic information

---

## References

- [Effective Java (3rd Edition) by Joshua Bloch](https://www.oreilly.com/library/view/effective-java/9780134686097/)
- [Modern Java in Action by Raoul-Gabriel Urma](https://www.manning.com/books/modern-java-in-action)
- [Google Java Style Guide](https://google.github.io/styleguide/javaguide.html)
