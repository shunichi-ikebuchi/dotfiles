# Apple Platform Architecture Patterns

Architectural patterns and best practices for macOS and iOS applications.

---

## MVVM (Model-View-ViewModel)

### Overview

MVVM is the recommended architecture pattern for SwiftUI applications and works well with UIKit too.

**Components**:
- **Model**: Data and business logic
- **View**: UI declaration (SwiftUI) or UI management (UIKit)
- **ViewModel**: Presentation logic, state management, mediates between Model and View

### SwiftUI Example

```swift
// Model
struct User: Identifiable, Codable {
    let id: String
    let name: String
    let email: String
    let avatarURL: URL?
}

enum LoadingState<T> {
    case idle
    case loading
    case success(T)
    case failure(Error)
}

// Service Layer
protocol UserServiceProtocol {
    func fetchUsers() async throws -> [User]
    func fetchUser(id: String) async throws -> User
}

class UserService: UserServiceProtocol {
    func fetchUsers() async throws -> [User] {
        let url = URL(string: "https://api.example.com/users")!
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode([User].self, from: data)
    }

    func fetchUser(id: String) async throws -> User {
        let url = URL(string: "https://api.example.com/users/\(id)")!
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode(User.self, from: data)
    }
}

// ViewModel
@MainActor
class UserListViewModel: ObservableObject {
    @Published private(set) var state: LoadingState<[User]> = .idle

    private let userService: UserServiceProtocol

    init(userService: UserServiceProtocol = UserService()) {
        self.userService = userService
    }

    func loadUsers() async {
        state = .loading

        do {
            let users = try await userService.fetchUsers()
            state = .success(users)
        } catch {
            state = .failure(error)
        }
    }

    func refresh() async {
        await loadUsers()
    }
}

// View
struct UserListView: View {
    @StateObject private var viewModel = UserListViewModel()

    var body: some View {
        NavigationView {
            Group {
                switch viewModel.state {
                case .idle:
                    Color.clear.onAppear {
                        Task { await viewModel.loadUsers() }
                    }

                case .loading:
                    ProgressView("Loading users...")

                case .success(let users):
                    List(users) { user in
                        NavigationLink(destination: UserDetailView(userID: user.id)) {
                            UserRow(user: user)
                        }
                    }
                    .refreshable {
                        await viewModel.refresh()
                    }

                case .failure(let error):
                    ErrorView(error: error) {
                        Task { await viewModel.loadUsers() }
                    }
                }
            }
            .navigationTitle("Users")
        }
    }
}

struct UserRow: View {
    let user: User

    var body: some View {
        HStack {
            AsyncImage(url: user.avatarURL) { image in
                image.resizable()
            } placeholder: {
                Color.gray
            }
            .frame(width: 50, height: 50)
            .clipShape(Circle())

            VStack(alignment: .leading) {
                Text(user.name)
                    .font(.headline)
                Text(user.email)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct ErrorView: View {
    let error: Error
    let retry: () -> Void

    var body: some View {
        VStack {
            Text("Error")
                .font(.title)
            Text(error.localizedDescription)
                .foregroundColor(.secondary)
            Button("Retry", action: retry)
                .buttonStyle(.borderedProminent)
        }
    }
}
```

### UIKit Example

```swift
// ViewModel for UIKit
class UserListViewModel {
    // Outputs
    var onStateChange: ((LoadingState<[User]>) -> Void)?

    private(set) var state: LoadingState<[User]> = .idle {
        didSet {
            onStateChange?(state)
        }
    }

    private let userService: UserServiceProtocol

    init(userService: UserServiceProtocol = UserService()) {
        self.userService = userService
    }

    func loadUsers() {
        state = .loading

        Task { @MainActor in
            do {
                let users = try await userService.fetchUsers()
                state = .success(users)
            } catch {
                state = .failure(error)
            }
        }
    }
}

// UIKit View Controller
class UserListViewController: UIViewController {
    private let viewModel: UserListViewModel
    private let tableView = UITableView()
    private var users: [User] = []

    init(viewModel: UserListViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        bindViewModel()
        viewModel.loadUsers()
    }

    private func setupUI() {
        view.addSubview(tableView)
        tableView.frame = view.bounds
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(UserCell.self, forCellReuseIdentifier: "UserCell")
    }

    private func bindViewModel() {
        viewModel.onStateChange = { [weak self] state in
            self?.handleStateChange(state)
        }
    }

    private func handleStateChange(_ state: LoadingState<[User]>) {
        switch state {
        case .idle:
            break

        case .loading:
            showLoadingIndicator()

        case .success(let users):
            hideLoadingIndicator()
            self.users = users
            tableView.reloadData()

        case .failure(let error):
            hideLoadingIndicator()
            showError(error)
        }
    }

    private func showLoadingIndicator() {
        // Show loading spinner
    }

    private func hideLoadingIndicator() {
        // Hide loading spinner
    }

    private func showError(_ error: Error) {
        let alert = UIAlertController(
            title: "Error",
            message: error.localizedDescription,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Retry", style: .default) { [weak self] _ in
            self?.viewModel.loadUsers()
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }
}

extension UserListViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        users.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "UserCell", for: indexPath) as! UserCell
        cell.configure(with: users[indexPath.row])
        return cell
    }
}
```

---

## Clean Architecture

### Overview

Clean Architecture separates concerns into distinct layers with clear dependency rules.

**Layers**:
1. **Domain Layer**: Entities, Use Cases (business logic)
2. **Data Layer**: Repositories, Data Sources (API, Database)
3. **Presentation Layer**: ViewModels, Views

### Directory Structure

```
MyApp/
├── Domain/
│   ├── Entities/
│   │   └── User.swift
│   ├── UseCases/
│   │   ├── FetchUsersUseCase.swift
│   │   └── UpdateUserUseCase.swift
│   └── Repositories/
│       └── UserRepositoryProtocol.swift
├── Data/
│   ├── Repositories/
│   │   └── UserRepository.swift
│   ├── DataSources/
│   │   ├── RemoteDataSource.swift
│   │   └── LocalDataSource.swift
│   └── DTOs/
│       └── UserDTO.swift
└── Presentation/
    ├── UserList/
    │   ├── UserListViewModel.swift
    │   └── UserListView.swift
    └── UserDetail/
        ├── UserDetailViewModel.swift
        └── UserDetailView.swift
```

### Implementation

```swift
// Domain Layer

// Entity
struct User {
    let id: String
    let name: String
    let email: String
}

// Repository Protocol (interface)
protocol UserRepositoryProtocol {
    func fetchUsers() async throws -> [User]
    func fetchUser(id: String) async throws -> User
    func updateUser(_ user: User) async throws
}

// Use Case
protocol FetchUsersUseCaseProtocol {
    func execute() async throws -> [User]
}

class FetchUsersUseCase: FetchUsersUseCaseProtocol {
    private let repository: UserRepositoryProtocol

    init(repository: UserRepositoryProtocol) {
        self.repository = repository
    }

    func execute() async throws -> [User] {
        try await repository.fetchUsers()
    }
}

// Data Layer

// DTO (Data Transfer Object)
struct UserDTO: Codable {
    let id: String
    let name: String
    let email: String
    let createdAt: String

    func toDomain() -> User {
        User(id: id, name: name, email: email)
    }
}

// Data Sources
protocol RemoteDataSourceProtocol {
    func fetchUsers() async throws -> [UserDTO]
}

class RemoteDataSource: RemoteDataSourceProtocol {
    func fetchUsers() async throws -> [UserDTO] {
        let url = URL(string: "https://api.example.com/users")!
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode([UserDTO].self, from: data)
    }
}

// Repository Implementation
class UserRepository: UserRepositoryProtocol {
    private let remoteDataSource: RemoteDataSourceProtocol

    init(remoteDataSource: RemoteDataSourceProtocol) {
        self.remoteDataSource = remoteDataSource
    }

    func fetchUsers() async throws -> [User] {
        let dtos = try await remoteDataSource.fetchUsers()
        return dtos.map { $0.toDomain() }
    }

    func fetchUser(id: String) async throws -> User {
        // Implementation
        fatalError("Not implemented")
    }

    func updateUser(_ user: User) async throws {
        // Implementation
    }
}

// Presentation Layer

@MainActor
class UserListViewModel: ObservableObject {
    @Published private(set) var users: [User] = []
    @Published private(set) var isLoading = false
    @Published private(set) var error: Error?

    private let fetchUsersUseCase: FetchUsersUseCaseProtocol

    init(fetchUsersUseCase: FetchUsersUseCaseProtocol) {
        self.fetchUsersUseCase = fetchUsersUseCase
    }

    func loadUsers() async {
        isLoading = true
        error = nil

        do {
            users = try await fetchUsersUseCase.execute()
        } catch {
            self.error = error
        }

        isLoading = false
    }
}
```

---

## Coordinator Pattern

### Overview

Coordinator pattern handles navigation flow, separating navigation logic from view controllers.

### Implementation

```swift
// Coordinator Protocol
protocol Coordinator: AnyObject {
    var navigationController: UINavigationController { get }
    var childCoordinators: [Coordinator] { get set }

    func start()
}

// App Coordinator
class AppCoordinator: Coordinator {
    let navigationController: UINavigationController
    var childCoordinators: [Coordinator] = []

    init(navigationController: UINavigationController) {
        self.navigationController = navigationController
    }

    func start() {
        showUserList()
    }

    private func showUserList() {
        let viewModel = UserListViewModel()
        viewModel.onUserSelected = { [weak self] user in
            self?.showUserDetail(user: user)
        }

        let viewController = UserListViewController(viewModel: viewModel)
        navigationController.pushViewController(viewController, animated: true)
    }

    private func showUserDetail(user: User) {
        let coordinator = UserDetailCoordinator(
            navigationController: navigationController,
            user: user
        )
        coordinator.start()
        childCoordinators.append(coordinator)
    }
}

// User Detail Coordinator
class UserDetailCoordinator: Coordinator {
    let navigationController: UINavigationController
    var childCoordinators: [Coordinator] = []
    let user: User

    init(navigationController: UINavigationController, user: User) {
        self.navigationController = navigationController
        self.user = user
    }

    func start() {
        let viewModel = UserDetailViewModel(user: user)
        let viewController = UserDetailViewController(viewModel: viewModel)
        navigationController.pushViewController(viewController, animated: true)
    }
}

// Usage in AppDelegate or SceneDelegate
class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    var appCoordinator: AppCoordinator?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = (scene as? UIWindowScene) else { return }

        let navigationController = UINavigationController()
        appCoordinator = AppCoordinator(navigationController: navigationController)
        appCoordinator?.start()

        window = UIWindow(windowScene: windowScene)
        window?.rootViewController = navigationController
        window?.makeKeyAndVisible()
    }
}
```

---

## Repository Pattern

### Overview

Repository pattern abstracts data access, providing a clean API for data operations.

### Implementation

```swift
// Repository Protocol
protocol UserRepositoryProtocol {
    func getUsers() async throws -> [User]
    func getUser(id: String) async throws -> User
    func saveUser(_ user: User) async throws
    func deleteUser(id: String) async throws
}

// Implementation with caching
class UserRepository: UserRepositoryProtocol {
    private let networkService: NetworkServiceProtocol
    private let cacheService: CacheServiceProtocol

    init(
        networkService: NetworkServiceProtocol,
        cacheService: CacheServiceProtocol
    ) {
        self.networkService = networkService
        self.cacheService = cacheService
    }

    func getUsers() async throws -> [User] {
        // Try cache first
        if let cachedUsers = try? await cacheService.getUsers(),
           !cachedUsers.isEmpty {
            return cachedUsers
        }

        // Fetch from network
        let users = try await networkService.fetchUsers()

        // Update cache
        try? await cacheService.saveUsers(users)

        return users
    }

    func getUser(id: String) async throws -> User {
        // Try cache
        if let cached = try? await cacheService.getUser(id: id) {
            return cached
        }

        // Fetch from network
        let user = try await networkService.fetchUser(id: id)

        // Cache it
        try? await cacheService.saveUser(user)

        return user
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

---

## SwiftUI Navigation Patterns

### NavigationStack (iOS 16+)

```swift
struct ContentView: View {
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            UserListView()
                .navigationDestination(for: User.self) { user in
                    UserDetailView(user: user)
                }
                .navigationDestination(for: Post.self) { post in
                    PostDetailView(post: post)
                }
        }
    }
}
```

### Programmatic Navigation

```swift
@MainActor
class NavigationCoordinator: ObservableObject {
    @Published var path = NavigationPath()

    func showUser(_ user: User) {
        path.append(user)
    }

    func showPost(_ post: Post) {
        path.append(post)
    }

    func popToRoot() {
        path.removeLast(path.count)
    }
}

struct ContentView: View {
    @StateObject private var coordinator = NavigationCoordinator()

    var body: some View {
        NavigationStack(path: $coordinator.path) {
            UserListView()
                .navigationDestination(for: User.self) { user in
                    UserDetailView(user: user)
                }
        }
        .environmentObject(coordinator)
    }
}
```

---

## Modular Architecture

### Feature Modules

Organize code by features rather than layers:

```
MyApp/
├── Features/
│   ├── UserList/
│   │   ├── Views/
│   │   ├── ViewModels/
│   │   ├── Models/
│   │   └── Services/
│   ├── UserDetail/
│   │   ├── Views/
│   │   ├── ViewModels/
│   │   └── Models/
│   └── Settings/
│       └── ...
├── Core/
│   ├── Networking/
│   ├── Storage/
│   └── Extensions/
└── Shared/
    ├── UI/
    └── Models/
```

### Benefits
- Clear feature boundaries
- Easier to navigate
- Can extract features into packages
- Better testability

---

## Dependency Injection

### Constructor Injection (Recommended)

```swift
class UserViewModel {
    private let userService: UserServiceProtocol
    private let analytics: AnalyticsProtocol

    init(
        userService: UserServiceProtocol,
        analytics: AnalyticsProtocol
    ) {
        self.userService = userService
        self.analytics = analytics
    }
}
```

### Environment-Based DI (SwiftUI)

```swift
// Define environment key
private struct UserServiceKey: EnvironmentKey {
    static let defaultValue: UserServiceProtocol = UserService()
}

extension EnvironmentValues {
    var userService: UserServiceProtocol {
        get { self[UserServiceKey.self] }
        set { self[UserServiceKey.self] = newValue }
    }
}

// Provide
ContentView()
    .environment(\.userService, MockUserService())

// Consume
struct UserListView: View {
    @Environment(\.userService) private var userService
}
```
