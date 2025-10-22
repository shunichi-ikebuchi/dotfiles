# Swift Design Patterns

Common design patterns and architectural approaches in Swift.

---

## Creational Patterns

### Singleton

**Use sparingly, prefer dependency injection**
```swift
// Good: Thread-safe singleton
final class AppConfiguration {
    static let shared = AppConfiguration()

    private init() {
        // Private initializer prevents external instantiation
    }

    var apiBaseURL: String = "https://api.example.com"
}

// Better: Dependency injection for testability
protocol ConfigurationProtocol {
    var apiBaseURL: String { get }
}

struct Configuration: ConfigurationProtocol {
    let apiBaseURL: String
}

class APIService {
    private let config: ConfigurationProtocol

    init(config: ConfigurationProtocol) {
        self.config = config
    }
}
```

### Factory

**Create objects without exposing creation logic**
```swift
protocol Vehicle {
    func drive()
}

struct Car: Vehicle {
    func drive() {
        print("Driving a car")
    }
}

struct Motorcycle: Vehicle {
    func drive() {
        print("Riding a motorcycle")
    }
}

enum VehicleType {
    case car
    case motorcycle
}

struct VehicleFactory {
    static func createVehicle(type: VehicleType) -> Vehicle {
        switch type {
        case .car:
            return Car()
        case .motorcycle:
            return Motorcycle()
        }
    }
}

// Usage
let vehicle = VehicleFactory.createVehicle(type: .car)
vehicle.drive()
```

### Builder

**Construct complex objects step by step**
```swift
struct URLRequestBuilder {
    private var url: URL?
    private var method: String = "GET"
    private var headers: [String: String] = [:]
    private var body: Data?

    func with(url: URL) -> URLRequestBuilder {
        var builder = self
        builder.url = url
        return builder
    }

    func with(method: String) -> URLRequestBuilder {
        var builder = self
        builder.method = method
        return builder
    }

    func with(header key: String, value: String) -> URLRequestBuilder {
        var builder = self
        builder.headers[key] = value
        return builder
    }

    func with(body: Data) -> URLRequestBuilder {
        var builder = self
        builder.body = body
        return builder
    }

    func build() throws -> URLRequest {
        guard let url = url else {
            throw BuilderError.missingURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.httpBody = body

        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }

        return request
    }
}

// Usage
let request = try URLRequestBuilder()
    .with(url: URL(string: "https://api.example.com")!)
    .with(method: "POST")
    .with(header: "Content-Type", value: "application/json")
    .with(body: jsonData)
    .build()
```

---

## Structural Patterns

### Adapter

**Convert one interface to another**
```swift
// Third-party library interface
class ThirdPartyImageLoader {
    func downloadImage(from urlString: String, completion: @escaping (UIImage?) -> Void) {
        // Implementation
    }
}

// Our app's interface
protocol ImageLoader {
    func loadImage(from url: URL) async -> UIImage?
}

// Adapter
class ImageLoaderAdapter: ImageLoader {
    private let thirdPartyLoader = ThirdPartyImageLoader()

    func loadImage(from url: URL) async -> UIImage? {
        await withCheckedContinuation { continuation in
            thirdPartyLoader.downloadImage(from: url.absoluteString) { image in
                continuation.resume(returning: image)
            }
        }
    }
}
```

### Decorator

**Add functionality to objects dynamically**
```swift
protocol Coffee {
    var cost: Double { get }
    var description: String { get }
}

struct SimpleCoffee: Coffee {
    let cost: Double = 2.0
    let description: String = "Simple coffee"
}

struct MilkDecorator: Coffee {
    private let coffee: Coffee

    init(coffee: Coffee) {
        self.coffee = coffee
    }

    var cost: Double {
        coffee.cost + 0.5
    }

    var description: String {
        coffee.description + ", milk"
    }
}

struct SugarDecorator: Coffee {
    private let coffee: Coffee

    init(coffee: Coffee) {
        self.coffee = coffee
    }

    var cost: Double {
        coffee.cost + 0.2
    }

    var description: String {
        coffee.description + ", sugar"
    }
}

// Usage
let coffee = SimpleCoffee()
let coffeeWithMilk = MilkDecorator(coffee: coffee)
let coffeeWithMilkAndSugar = SugarDecorator(coffee: coffeeWithMilk)

print(coffeeWithMilkAndSugar.description)  // "Simple coffee, milk, sugar"
print(coffeeWithMilkAndSugar.cost)  // 2.7
```

### Facade

**Simplified interface to complex subsystem**
```swift
// Complex subsystem
class AuthenticationService {
    func authenticate(username: String, password: String) async throws -> Token { ... }
}

class UserProfileService {
    func fetchProfile(token: Token) async throws -> UserProfile { ... }
}

class PreferencesService {
    func loadPreferences(userID: String) async throws -> Preferences { ... }
}

// Facade
class LoginFacade {
    private let authService = AuthenticationService()
    private let profileService = UserProfileService()
    private let preferencesService = PreferencesService()

    func login(username: String, password: String) async throws -> (UserProfile, Preferences) {
        let token = try await authService.authenticate(username: username, password: password)
        let profile = try await profileService.fetchProfile(token: token)
        let preferences = try await preferencesService.loadPreferences(userID: profile.id)

        return (profile, preferences)
    }
}

// Usage
let facade = LoginFacade()
let (profile, preferences) = try await facade.login(username: "user", password: "pass")
```

---

## Behavioral Patterns

### Observer

**Notify multiple objects about events**
```swift
// Using Combine
import Combine

class DataSource {
    @Published var data: [Item] = []

    func fetchData() {
        // Fetch and update data
        data = [/* new items */]
    }
}

class ViewController {
    private let dataSource = DataSource()
    private var cancellables = Set<AnyCancellable>()

    func setupObserver() {
        dataSource.$data
            .sink { [weak self] newData in
                self?.updateUI(with: newData)
            }
            .store(in: &cancellables)
    }

    private func updateUI(with data: [Item]) {
        // Update UI
    }
}
```

### Strategy

**Define family of algorithms, make them interchangeable**
```swift
protocol SortingStrategy {
    func sort<T: Comparable>(_ array: [T]) -> [T]
}

struct BubbleSortStrategy: SortingStrategy {
    func sort<T: Comparable>(_ array: [T]) -> [T] {
        var arr = array
        // Bubble sort implementation
        return arr
    }
}

struct QuickSortStrategy: SortingStrategy {
    func sort<T: Comparable>(_ array: [T]) -> [T] {
        guard array.count > 1 else { return array }
        // Quick sort implementation
        return array
    }
}

class Sorter {
    private var strategy: SortingStrategy

    init(strategy: SortingStrategy) {
        self.strategy = strategy
    }

    func setStrategy(_ strategy: SortingStrategy) {
        self.strategy = strategy
    }

    func sort<T: Comparable>(_ array: [T]) -> [T] {
        strategy.sort(array)
    }
}

// Usage
let sorter = Sorter(strategy: QuickSortStrategy())
let sorted = sorter.sort([5, 2, 8, 1, 9])
```

### Command

**Encapsulate request as object**
```swift
protocol Command {
    func execute()
    func undo()
}

class Document {
    private var content: String = ""

    func insert(_ text: String, at position: Int) {
        let index = content.index(content.startIndex, offsetBy: position)
        content.insert(contentsOf: text, at: index)
    }

    func delete(from: Int, to: Int) {
        let start = content.index(content.startIndex, offsetBy: from)
        let end = content.index(content.startIndex, offsetBy: to)
        content.removeSubrange(start..<end)
    }

    var text: String { content }
}

class InsertCommand: Command {
    private let document: Document
    private let text: String
    private let position: Int

    init(document: Document, text: String, position: Int) {
        self.document = document
        self.text = text
        self.position = position
    }

    func execute() {
        document.insert(text, at: position)
    }

    func undo() {
        document.delete(from: position, to: position + text.count)
    }
}

class CommandManager {
    private var history: [Command] = []
    private var currentIndex = -1

    func execute(_ command: Command) {
        // Remove any commands after current index (new branch)
        if currentIndex < history.count - 1 {
            history.removeSubrange((currentIndex + 1)...)
        }

        command.execute()
        history.append(command)
        currentIndex += 1
    }

    func undo() {
        guard currentIndex >= 0 else { return }
        history[currentIndex].undo()
        currentIndex -= 1
    }

    func redo() {
        guard currentIndex < history.count - 1 else { return }
        currentIndex += 1
        history[currentIndex].execute()
    }
}
```

---

## Protocol-Oriented Patterns

### Protocol Extensions

**Provide default implementations**
```swift
protocol Identifiable {
    var id: String { get }
}

extension Identifiable {
    var debugDescription: String {
        "Object with ID: \(id)"
    }
}

protocol Fetchable {
    associatedtype FetchResult
    func fetch() async throws -> FetchResult
}

extension Fetchable {
    func fetchWithRetry(maxAttempts: Int = 3) async throws -> FetchResult {
        var lastError: Error?

        for attempt in 1...maxAttempts {
            do {
                return try await fetch()
            } catch {
                lastError = error
                if attempt < maxAttempts {
                    try await Task.sleep(nanoseconds: UInt64(attempt) * 1_000_000_000)
                }
            }
        }

        throw lastError ?? FetchError.unknown
    }
}
```

### Phantom Types

**Compile-time type safety**
```swift
struct Validated {}
struct Unvalidated {}

struct Email<State> {
    let value: String
}

extension Email where State == Unvalidated {
    init(_ value: String) {
        self.value = value
    }

    func validated() -> Email<Validated>? {
        guard value.contains("@") else { return nil }
        return Email<Validated>(value: value)
    }
}

extension Email where State == Validated {
    private init(value: String) {
        self.value = value
    }
}

func sendEmail(to: Email<Validated>) {
    // Can only send to validated emails
    print("Sending email to \(to.value)")
}

// Usage
let unvalidatedEmail = Email<Unvalidated>("user@example.com")
if let validEmail = unvalidatedEmail.validated() {
    sendEmail(to: validEmail)  // Compiles
}

// sendEmail(to: unvalidatedEmail)  // Compile error!
```

---

## Architectural Patterns

### MVVM (Model-View-ViewModel)

**SwiftUI's natural pattern**
```swift
// Model
struct User: Codable {
    let id: String
    let name: String
    let email: String
}

// Service
protocol UserServiceProtocol {
    func fetchUsers() async throws -> [User]
}

// ViewModel
@MainActor
class UsersViewModel: ObservableObject {
    @Published var users: [User] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let userService: UserServiceProtocol

    init(userService: UserServiceProtocol) {
        self.userService = userService
    }

    func loadUsers() async {
        isLoading = true
        errorMessage = nil

        do {
            users = try await userService.fetchUsers()
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}

// View
struct UsersView: View {
    @StateObject private var viewModel: UsersViewModel

    init(viewModel: UsersViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        List(viewModel.users, id: \.id) { user in
            Text(user.name)
        }
        .task {
            await viewModel.loadUsers()
        }
    }
}
```

### Repository Pattern

**Abstract data access**
```swift
protocol UserRepositoryProtocol {
    func getUser(id: String) async throws -> User
    func getUsers() async throws -> [User]
    func saveUser(_ user: User) async throws
    func deleteUser(id: String) async throws
}

class UserRepository: UserRepositoryProtocol {
    private let networkService: NetworkServiceProtocol
    private let cacheService: CacheServiceProtocol

    init(networkService: NetworkServiceProtocol, cacheService: CacheServiceProtocol) {
        self.networkService = networkService
        self.cacheService = cacheService
    }

    func getUser(id: String) async throws -> User {
        // Try cache first
        if let cachedUser = try? await cacheService.getUser(id: id) {
            return cachedUser
        }

        // Fetch from network
        let user = try await networkService.fetchUser(id: id)

        // Update cache
        try? await cacheService.saveUser(user)

        return user
    }

    func getUsers() async throws -> [User] {
        try await networkService.fetchUsers()
    }

    func saveUser(_ user: User) async throws {
        try await networkService.updateUser(user)
        try? await cacheService.saveUser(user)
    }

    func deleteUser(id: String) async throws {
        try await networkService.deleteUser(id: id)
        try? await cacheService.deleteUser(id: id)
    }
}
```

### Coordinator Pattern

**Manage navigation flow**
```swift
protocol Coordinator {
    var navigationController: UINavigationController { get }
    func start()
}

class AppCoordinator: Coordinator {
    let navigationController: UINavigationController

    init(navigationController: UINavigationController) {
        self.navigationController = navigationController
    }

    func start() {
        showLogin()
    }

    private func showLogin() {
        let loginVC = LoginViewController()
        loginVC.onLoginSuccess = { [weak self] in
            self?.showMain()
        }
        navigationController.pushViewController(loginVC, animated: true)
    }

    private func showMain() {
        let mainVC = MainViewController()
        mainVC.onLogout = { [weak self] in
            self?.showLogin()
        }
        navigationController.setViewControllers([mainVC], animated: true)
    }
}
```

---

## Dependency Injection

### Constructor Injection

**Preferred method in Swift**
```swift
protocol NetworkServiceProtocol {
    func fetchData() async throws -> Data
}

protocol CacheServiceProtocol {
    func get(key: String) -> Data?
    func set(key: String, data: Data)
}

class DataRepository {
    private let networkService: NetworkServiceProtocol
    private let cacheService: CacheServiceProtocol

    init(
        networkService: NetworkServiceProtocol,
        cacheService: CacheServiceProtocol
    ) {
        self.networkService = networkService
        self.cacheService = cacheService
    }

    func fetchData(key: String) async throws -> Data {
        if let cached = cacheService.get(key: key) {
            return cached
        }

        let data = try await networkService.fetchData()
        cacheService.set(key: key, data: data)
        return data
    }
}
```

### Environment-Based Injection (SwiftUI)

**Use Environment for dependency injection**
```swift
// Define environment key
private struct UserServiceKey: EnvironmentKey {
    static let defaultValue: UserServiceProtocol = RealUserService()
}

extension EnvironmentValues {
    var userService: UserServiceProtocol {
        get { self[UserServiceKey.self] }
        set { self[UserServiceKey.self] = newValue }
    }
}

// Provide dependency
@main
struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.userService, RealUserService())
        }
    }
}

// Consume dependency
struct ContentView: View {
    @Environment(\.userService) private var userService

    var body: some View {
        // Use userService
    }
}
```

---

## Result Builders

**Custom DSL syntax**
```swift
@resultBuilder
struct HTMLBuilder {
    static func buildBlock(_ components: String...) -> String {
        components.joined(separator: "\n")
    }

    static func buildOptional(_ component: String?) -> String {
        component ?? ""
    }

    static func buildEither(first component: String) -> String {
        component
    }

    static func buildEither(second component: String) -> String {
        component
    }
}

func html(@HTMLBuilder content: () -> String) -> String {
    "<html>\n\(content())\n</html>"
}

func body(@HTMLBuilder content: () -> String) -> String {
    "<body>\n\(content())\n</body>"
}

func h1(_ text: String) -> String {
    "<h1>\(text)</h1>"
}

func p(_ text: String) -> String {
    "<p>\(text)</p>"
}

// Usage
let page = html {
    body {
        h1("Welcome")
        p("This is a paragraph")
    }
}
```
