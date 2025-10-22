# Swift Best Practices

Comprehensive best practices for writing production-quality Swift code.

---

## Type System

### Optionals

**Prefer safe unwrapping**
```swift
// Good
guard let user = optionalUser else {
    return
}
processUser(user)

// Good: Multiple bindings
guard let user = optionalUser,
      let name = user.name,
      !name.isEmpty else {
    return
}

// Good: Optional chaining
let street = user?.address?.street

// Bad: Force unwrapping
let user = optionalUser!  // Crashes if nil
```

**Use nil coalescing for defaults**
```swift
// Good
let displayName = user.name ?? "Anonymous"

// Bad
let displayName = user.name != nil ? user.name! : "Anonymous"
```

### Enums with Associated Values

**Model complex state with enums**
```swift
// Good: Rich state representation
enum NetworkResponse {
    case success(Data)
    case failure(Error)
    case loading
    case idle
}

// Good: Pattern matching
switch response {
case .success(let data):
    processData(data)
case .failure(let error):
    handleError(error)
case .loading:
    showLoadingIndicator()
case .idle:
    break
}
```

### Generics

**Use generics for reusable code**
```swift
// Good: Generic data structure
struct Cache<Key: Hashable, Value> {
    private var storage: [Key: Value] = [:]

    mutating func set(_ value: Value, forKey key: Key) {
        storage[key] = value
    }

    func get(_ key: Key) -> Value? {
        storage[key]
    }
}

// Good: Generic constraints
func findFirst<T: Equatable>(in array: [T], matching predicate: (T) -> Bool) -> T? {
    array.first(where: predicate)
}
```

---

## Value Types vs Reference Types

### Prefer Structs

**Use structs for data models**
```swift
// Good: Value semantics
struct User {
    let id: String
    var name: String
    var email: String
}

// Good: Copy-on-write behavior (built-in for structs)
var user1 = User(id: "1", name: "Alice", email: "alice@example.com")
var user2 = user1
user2.name = "Bob"  // user1.name is still "Alice"
```

### Use Classes When Needed

**Classes for reference semantics, inheritance, or Objective-C interop**
```swift
// Good: Class for reference type behavior
class ViewModel: ObservableObject {
    @Published var data: [Item] = []

    func fetchData() async {
        // Fetch data
    }
}

// Good: Class for inheritance
class BaseViewController: UIViewController {
    // Shared functionality
}
```

---

## Protocol-Oriented Programming

### Protocol Extensions

**Provide default implementations**
```swift
// Good: Protocol with defaults
protocol Timestamped {
    var timestamp: Date { get }
}

extension Timestamped {
    var isRecent: Bool {
        Date().timeIntervalSince(timestamp) < 86400  // 24 hours
    }
}
```

### Protocol Composition

**Combine protocols for rich types**
```swift
// Good: Protocol composition
protocol Identifiable {
    var id: String { get }
}

protocol Displayable {
    var displayName: String { get }
}

typealias ListItem = Identifiable & Displayable & Codable

struct Product: ListItem {
    let id: String
    let displayName: String
    let price: Decimal
}
```

---

## Error Handling

### Throwing Functions

**Use throws for recoverable errors**
```swift
// Good: Throwing function
enum ValidationError: Error {
    case emptyName
    case invalidEmail
    case tooShort(minimum: Int)
}

func validateUser(_ user: User) throws {
    guard !user.name.isEmpty else {
        throw ValidationError.emptyName
    }

    guard user.email.contains("@") else {
        throw ValidationError.invalidEmail
    }
}

// Usage
do {
    try validateUser(user)
} catch ValidationError.emptyName {
    print("Name cannot be empty")
} catch ValidationError.invalidEmail {
    print("Invalid email format")
} catch {
    print("Unknown error: \(error)")
}
```

### Result Type

**Use Result for async operations**
```swift
// Good: Result type for async results
func fetchUser(id: String, completion: @escaping (Result<User, Error>) -> Void) {
    URLSession.shared.dataTask(with: url) { data, response, error in
        if let error = error {
            completion(.failure(error))
            return
        }

        guard let data = data else {
            completion(.failure(NetworkError.noData))
            return
        }

        do {
            let user = try JSONDecoder().decode(User.self, from: data)
            completion(.success(user))
        } catch {
            completion(.failure(error))
        }
    }.resume()
}

// Better: Use async/await instead
func fetchUser(id: String) async throws -> User {
    let (data, _) = try await URLSession.shared.data(from: url)
    return try JSONDecoder().decode(User.self, from: data)
}
```

---

## Concurrency

### Async/Await

**Prefer async/await over callbacks**
```swift
// Good: Sequential async operations
func loadUserData(id: String) async throws -> UserData {
    let user = try await fetchUser(id: id)
    let posts = try await fetchPosts(userId: user.id)
    let friends = try await fetchFriends(userId: user.id)

    return UserData(user: user, posts: posts, friends: friends)
}

// Good: Parallel async operations
func loadMultipleUsers(ids: [String]) async throws -> [User] {
    try await withThrowingTaskGroup(of: User.self) { group in
        for id in ids {
            group.addTask {
                try await fetchUser(id: id)
            }
        }

        var users: [User] = []
        for try await user in group {
            users.append(user)
        }
        return users
    }
}
```

### Actors

**Use actors for thread-safe state**
```swift
// Good: Actor for mutable shared state
actor ImageCache {
    private var cache: [String: UIImage] = [:]

    func image(for url: URL) -> UIImage? {
        cache[url.absoluteString]
    }

    func setImage(_ image: UIImage, for url: URL) {
        cache[url.absoluteString] = image
    }

    func clearCache() {
        cache.removeAll()
    }
}

// Usage (automatically thread-safe)
let cache = ImageCache()
await cache.setImage(image, for: url)
let cached = await cache.image(for: url)
```

---

## Memory Management

### Avoiding Retain Cycles

**Use weak/unowned in closures**
```swift
// Good: Weak self in closures
class ViewModel {
    var onDataLoaded: (() -> Void)?

    func loadData() {
        fetchData { [weak self] result in
            guard let self = self else { return }
            self.processResult(result)
            self.onDataLoaded?()
        }
    }
}

// Good: Unowned when self always exists
class ViewController: UIViewController {
    private let viewModel: ViewModel

    init(viewModel: ViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)

        viewModel.onUpdate = { [unowned self] in
            self.updateUI()
        }
    }
}
```

### Delegate Pattern

**Use weak delegates**
```swift
// Good: Weak delegate
protocol DataSourceDelegate: AnyObject {
    func dataDidUpdate(_ dataSource: DataSource)
}

class DataSource {
    weak var delegate: DataSourceDelegate?

    func notifyUpdate() {
        delegate?.dataDidUpdate(self)
    }
}
```

---

## Code Organization

### Extensions for Organization

**Group functionality by concern**
```swift
// Good: Extension for protocol conformance
struct User {
    let id: String
    let name: String
    let email: String
}

// MARK: - Codable
extension User: Codable {}

// MARK: - CustomStringConvertible
extension User: CustomStringConvertible {
    var description: String {
        "User(id: \(id), name: \(name))"
    }
}

// MARK: - Validation
extension User {
    func validate() throws {
        guard !name.isEmpty else {
            throw ValidationError.emptyName
        }
    }
}
```

### Access Control

**Use appropriate access levels**
```swift
// Good: Explicit access control
public struct API {
    private let baseURL: URL
    private let session: URLSession

    public init(baseURL: URL) {
        self.baseURL = baseURL
        self.session = URLSession.shared
    }

    public func fetchData() async throws -> Data {
        try await performRequest()
    }

    private func performRequest() async throws -> Data {
        // Implementation
    }
}
```

---

## Property Wrappers

### Custom Property Wrappers

**Create reusable property behaviors**
```swift
// Good: Custom property wrapper
@propertyWrapper
struct Clamped<Value: Comparable> {
    private var value: Value
    private let range: ClosedRange<Value>

    var wrappedValue: Value {
        get { value }
        set { value = min(max(newValue, range.lowerBound), range.upperBound) }
    }

    init(wrappedValue: Value, _ range: ClosedRange<Value>) {
        self.range = range
        self.value = min(max(wrappedValue, range.lowerBound), range.upperBound)
    }
}

// Usage
struct AudioPlayer {
    @Clamped(0...100) var volume: Int = 50
}
```

---

## API Design

### Clear Method Names

**Follow Swift naming conventions**
```swift
// Good: Clear, descriptive names
func convertToUserModel(from dto: UserDTO) -> User { ... }
func validateEmail(_ email: String) throws { ... }
func fetchUsers(matching query: String) async throws -> [User] { ... }

// Bad: Unclear names
func convert(_ dto: UserDTO) -> User { ... }  // Convert to what?
func validate(_ s: String) throws { ... }  // Validate what aspect?
func get(_ q: String) async throws -> [User] { ... }  // Get what?
```

### Default Parameters

**Use default parameters for flexibility**
```swift
// Good: Default parameters
func fetchData(
    from url: URL,
    cachePolicy: URLRequest.CachePolicy = .useProtocolCachePolicy,
    timeout: TimeInterval = 30
) async throws -> Data {
    // Implementation
}

// Usage
try await fetchData(from: url)  // Uses defaults
try await fetchData(from: url, timeout: 60)  // Custom timeout
```

---

## Performance

### Copy-on-Write for Large Data Structures

**Implement CoW for custom types**
```swift
// Good: Copy-on-write implementation
struct LargeDataStructure {
    private final class Storage {
        var data: [Int]
        init(data: [Int]) { self.data = data }
    }

    private var storage: Storage

    init(data: [Int]) {
        storage = Storage(data: data)
    }

    private mutating func ensureUniqueStorage() {
        if !isKnownUniquelyReferenced(&storage) {
            storage = Storage(data: storage.data)
        }
    }

    mutating func append(_ value: Int) {
        ensureUniqueStorage()
        storage.data.append(value)
    }
}
```

### Lazy Initialization

**Use lazy for expensive computations**
```swift
// Good: Lazy property
class DataProcessor {
    lazy var expensiveComputation: [Result] = {
        // Heavy computation performed only when accessed
        performExpensiveOperation()
    }()
}
```

---

## Testing Considerations

**Write testable code**
```swift
// Good: Dependency injection for testability
protocol NetworkServiceProtocol {
    func fetchData(from url: URL) async throws -> Data
}

class RealNetworkService: NetworkServiceProtocol {
    func fetchData(from url: URL) async throws -> Data {
        try await URLSession.shared.data(from: url).0
    }
}

class ViewModel {
    private let networkService: NetworkServiceProtocol

    init(networkService: NetworkServiceProtocol = RealNetworkService()) {
        self.networkService = networkService
    }

    func loadData() async throws {
        let data = try await networkService.fetchData(from: url)
        // Process data
    }
}

// In tests: inject mock service
class MockNetworkService: NetworkServiceProtocol {
    func fetchData(from url: URL) async throws -> Data {
        // Return test data
    }
}
```
