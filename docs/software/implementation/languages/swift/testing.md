# Swift Testing Guidelines

Testing strategies and best practices for Swift projects.

---

## Testing Frameworks

### XCTest (Apple's Official Framework)

**Standard testing framework**
```swift
import XCTest
@testable import MyApp

final class UserServiceTests: XCTestCase {
    var sut: UserService!  // System Under Test

    override func setUp() {
        super.setUp()
        sut = UserService()
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    func testFetchUser_WithValidID_ReturnsUser() async throws {
        // Arrange
        let userID = "123"

        // Act
        let user = try await sut.fetchUser(id: userID)

        // Assert
        XCTAssertEqual(user.id, userID)
        XCTAssertFalse(user.name.isEmpty)
    }

    func testFetchUser_WithInvalidID_ThrowsError() async {
        // Arrange
        let invalidID = ""

        // Act & Assert
        await XCTAssertThrowsError(try await sut.fetchUser(id: invalidID)) { error in
            XCTAssertEqual(error as? UserServiceError, .invalidID)
        }
    }
}
```

### Swift Testing (New Framework - Swift 5.9+)

**Modern testing framework with better syntax**
```swift
import Testing
@testable import MyApp

@Suite("User Service Tests")
struct UserServiceTests {
    let sut = UserService()

    @Test("Fetch user with valid ID returns user")
    func fetchUserWithValidID() async throws {
        // Arrange
        let userID = "123"

        // Act
        let user = try await sut.fetchUser(id: userID)

        // Assert
        #expect(user.id == userID)
        #expect(!user.name.isEmpty)
    }

    @Test("Fetch user with invalid ID throws error")
    func fetchUserWithInvalidID() async {
        // Arrange
        let invalidID = ""

        // Act & Assert
        await #expect(throws: UserServiceError.invalidID) {
            try await sut.fetchUser(id: invalidID)
        }
    }

    @Test("Fetch multiple users", arguments: [
        ["1", "2", "3"],
        ["a", "b", "c"]
    ])
    func fetchMultipleUsers(ids: [String]) async throws {
        let users = try await sut.fetchUsers(ids: ids)
        #expect(users.count == ids.count)
    }
}
```

---

## Test Organization

### File Structure

```
MyApp/
├── Sources/
│   └── MyApp/
│       ├── Models/
│       ├── Services/
│       └── ViewModels/
└── Tests/
    └── MyAppTests/
        ├── Models/
        │   └── UserTests.swift
        ├── Services/
        │   └── UserServiceTests.swift
        └── ViewModels/
            └── UserViewModelTests.swift
```

### Naming Conventions

**Clear, descriptive test names**
```swift
// Good: Descriptive test names
func testLogin_WithValidCredentials_ReturnsSuccess()
func testLogin_WithInvalidPassword_ReturnsError()
func testLogin_WhenNetworkFails_ThrowsNetworkError()

// Pattern: test[MethodName]_[Condition]_[ExpectedResult]

// Bad: Unclear names
func testLogin1()
func testLogin2()
func testLoginError()
```

---

## Unit Testing Patterns

### Arrange-Act-Assert (AAA)

**Structure tests clearly**
```swift
func testCalculateTotal_WithMultipleItems_ReturnsCorrectSum() {
    // Arrange
    let items = [
        Item(price: 10.0),
        Item(price: 20.0),
        Item(price: 30.0)
    ]
    let calculator = PriceCalculator()

    // Act
    let total = calculator.calculateTotal(for: items)

    // Assert
    XCTAssertEqual(total, 60.0)
}
```

### Dependency Injection for Testing

**Use protocols for mockable dependencies**
```swift
// Production code
protocol NetworkServiceProtocol {
    func fetchData(from url: URL) async throws -> Data
}

class RealNetworkService: NetworkServiceProtocol {
    func fetchData(from url: URL) async throws -> Data {
        try await URLSession.shared.data(from: url).0
    }
}

class UserRepository {
    private let networkService: NetworkServiceProtocol

    init(networkService: NetworkServiceProtocol) {
        self.networkService = networkService
    }

    func fetchUser(id: String) async throws -> User {
        let url = URL(string: "https://api.example.com/users/\(id)")!
        let data = try await networkService.fetchData(from: url)
        return try JSONDecoder().decode(User.self, from: data)
    }
}

// Test code
class MockNetworkService: NetworkServiceProtocol {
    var mockData: Data?
    var shouldThrowError = false

    func fetchData(from url: URL) async throws -> Data {
        if shouldThrowError {
            throw NetworkError.requestFailed
        }
        return mockData ?? Data()
    }
}

final class UserRepositoryTests: XCTestCase {
    func testFetchUser_WithValidResponse_ReturnsUser() async throws {
        // Arrange
        let mockService = MockNetworkService()
        let userData = """
        {"id": "123", "name": "John Doe"}
        """.data(using: .utf8)!
        mockService.mockData = userData

        let repository = UserRepository(networkService: mockService)

        // Act
        let user = try await repository.fetchUser(id: "123")

        // Assert
        XCTAssertEqual(user.id, "123")
        XCTAssertEqual(user.name, "John Doe")
    }

    func testFetchUser_WhenNetworkFails_ThrowsError() async {
        // Arrange
        let mockService = MockNetworkService()
        mockService.shouldThrowError = true

        let repository = UserRepository(networkService: mockService)

        // Act & Assert
        await XCTAssertThrowsError(try await repository.fetchUser(id: "123"))
    }
}
```

---

## Async Testing

### Testing Async/Await

**Test async functions properly**
```swift
func testAsyncOperation() async throws {
    let result = try await sut.performAsyncOperation()
    XCTAssertNotNil(result)
}

// Multiple async operations
func testMultipleAsyncOperations() async throws {
    async let result1 = sut.operation1()
    async let result2 = sut.operation2()

    let (r1, r2) = try await (result1, result2)
    XCTAssertEqual(r1, expectedValue1)
    XCTAssertEqual(r2, expectedValue2)
}
```

### Testing Actors

**Test actor isolation**
```swift
actor DataCache {
    private var cache: [String: Data] = [:]

    func set(_ data: Data, forKey key: String) {
        cache[key] = data
    }

    func get(_ key: String) -> Data? {
        cache[key]
    }
}

final class DataCacheTests: XCTestCase {
    func testCacheStoresAndRetrievesData() async {
        // Arrange
        let cache = DataCache()
        let testData = "test".data(using: .utf8)!
        let key = "testKey"

        // Act
        await cache.set(testData, forKey: key)
        let retrieved = await cache.get(key)

        // Assert
        XCTAssertEqual(retrieved, testData)
    }
}
```

---

## UI Testing

### XCTest UI Testing

**Test user interactions**
```swift
import XCTest

final class LoginUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    func testSuccessfulLogin() {
        // Arrange
        let emailTextField = app.textFields["emailTextField"]
        let passwordSecureTextField = app.secureTextFields["passwordTextField"]
        let loginButton = app.buttons["loginButton"]

        // Act
        emailTextField.tap()
        emailTextField.typeText("user@example.com")

        passwordSecureTextField.tap()
        passwordSecureTextField.typeText("password123")

        loginButton.tap()

        // Assert
        let welcomeLabel = app.staticTexts["welcomeLabel"]
        XCTAssertTrue(welcomeLabel.waitForExistence(timeout: 5))
        XCTAssertEqual(welcomeLabel.label, "Welcome!")
    }

    func testLoginWithInvalidCredentials() {
        // Arrange
        let emailTextField = app.textFields["emailTextField"]
        let passwordSecureTextField = app.secureTextFields["passwordTextField"]
        let loginButton = app.buttons["loginButton"]

        // Act
        emailTextField.tap()
        emailTextField.typeText("invalid@example.com")

        passwordSecureTextField.tap()
        passwordSecureTextField.typeText("wrong")

        loginButton.tap()

        // Assert
        let errorAlert = app.alerts["Error"]
        XCTAssertTrue(errorAlert.waitForExistence(timeout: 2))
    }
}
```

---

## Mocking and Stubbing

### Protocol-Based Mocks

**Create testable mocks**
```swift
protocol UserServiceProtocol {
    func fetchUser(id: String) async throws -> User
    func updateUser(_ user: User) async throws
    func deleteUser(id: String) async throws
}

// Real implementation
class UserService: UserServiceProtocol {
    func fetchUser(id: String) async throws -> User {
        // Real network call
    }

    func updateUser(_ user: User) async throws {
        // Real network call
    }

    func deleteUser(id: String) async throws {
        // Real network call
    }
}

// Mock for testing
class MockUserService: UserServiceProtocol {
    var fetchUserCalled = false
    var updateUserCalled = false
    var deleteUserCalled = false

    var userToReturn: User?
    var errorToThrow: Error?

    func fetchUser(id: String) async throws -> User {
        fetchUserCalled = true

        if let error = errorToThrow {
            throw error
        }

        guard let user = userToReturn else {
            throw MockError.noUserConfigured
        }

        return user
    }

    func updateUser(_ user: User) async throws {
        updateUserCalled = true

        if let error = errorToThrow {
            throw error
        }
    }

    func deleteUser(id: String) async throws {
        deleteUserCalled = true

        if let error = errorToThrow {
            throw error
        }
    }
}
```

---

## Performance Testing

### Measure Execution Time

**Test performance of critical code**
```swift
func testDataProcessingPerformance() {
    let largeDataSet = generateLargeDataSet(count: 10000)

    measure {
        _ = processor.process(largeDataSet)
    }
}

// XCTMetrics for detailed performance testing
func testNetworkRequestPerformance() {
    let options = XCTMeasureOptions()
    options.iterationCount = 10

    measure(metrics: [XCTClockMetric()], options: options) {
        let expectation = expectation(description: "Request completes")

        Task {
            _ = try? await networkService.fetchData()
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 5.0)
    }
}
```

---

## Test Coverage

### Measuring Coverage

**Generate coverage reports in Xcode**
1. Edit scheme → Test → Options
2. Enable "Gather coverage for all targets"
3. Run tests
4. View Report Navigator → Coverage tab

**Coverage goals**
- Critical business logic: 90%+ coverage
- Data models: 80%+ coverage
- View controllers/UI: 60%+ coverage (use UI tests for the rest)
- Utilities: 90%+ coverage

---

## Continuous Integration

### GitHub Actions Example

```yaml
name: Swift Tests

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  test:
    runs-on: macos-latest

    steps:
    - uses: actions/checkout@v3

    - name: Select Xcode version
      run: sudo xcode-select -s /Applications/Xcode_15.0.app

    - name: Build and test
      run: |
        xcodebuild test \
          -scheme MyApp \
          -destination 'platform=iOS Simulator,name=iPhone 15,OS=17.0' \
          -enableCodeCoverage YES \
          | xcpretty

    - name: Upload coverage
      uses: codecov/codecov-action@v3
```

### Swift Package Manager

```bash
# Run tests
swift test

# Run tests with coverage
swift test --enable-code-coverage

# Generate coverage report
xcrun llvm-cov report \
  .build/debug/MyPackagePackageTests.xctest/Contents/MacOS/MyPackagePackageTests \
  -instr-profile .build/debug/codecov/default.profdata
```

---

## Testing Best Practices

### Do's
- ✅ Write tests before or alongside production code
- ✅ Keep tests independent and isolated
- ✅ Use descriptive test names
- ✅ Test one thing per test
- ✅ Mock external dependencies
- ✅ Test edge cases and error conditions
- ✅ Maintain test code quality (refactor when needed)

### Don'ts
- ❌ Don't test implementation details
- ❌ Don't write interdependent tests
- ❌ Don't use real network calls in unit tests
- ❌ Don't skip flaky tests (fix them instead)
- ❌ Don't hardcode test data without context
- ❌ Don't test framework code (trust Apple's testing)

---

## Common Testing Patterns

### Builder Pattern for Test Data

```swift
class UserBuilder {
    private var id = UUID().uuidString
    private var name = "Test User"
    private var email = "test@example.com"
    private var age = 25

    func withID(_ id: String) -> UserBuilder {
        self.id = id
        return self
    }

    func withName(_ name: String) -> UserBuilder {
        self.name = name
        return self
    }

    func withEmail(_ email: String) -> UserBuilder {
        self.email = email
        return self
    }

    func build() -> User {
        User(id: id, name: name, email: email, age: age)
    }
}

// Usage in tests
func testUserValidation() {
    let user = UserBuilder()
        .withName("")
        .build()

    XCTAssertThrowsError(try user.validate())
}
```

### Test Fixtures

```swift
enum TestFixtures {
    static var sampleUser: User {
        User(id: "123", name: "John Doe", email: "john@example.com")
    }

    static var sampleUsers: [User] {
        [
            User(id: "1", name: "Alice", email: "alice@example.com"),
            User(id: "2", name: "Bob", email: "bob@example.com"),
            User(id: "3", name: "Charlie", email: "charlie@example.com")
        ]
    }
}

// Usage
func testUserProcessing() {
    let user = TestFixtures.sampleUser
    let result = processor.process(user)
    XCTAssertNotNil(result)
}
```
