# iOS Platform Guidelines

iOS-specific instructions for AI coding agents working on iPhone and iPad applications.

**Philosophy**: Build native, high-quality iOS applications that feel natural on iPhone and iPad, following Apple's design principles and leveraging platform-specific features.

---

## Quick Reference

### Core Principles
- ✅ Follow iOS Human Interface Guidelines
- ✅ Use native frameworks (SwiftUI, UIKit)
- ✅ Support different device sizes (iPhone, iPad)
- ✅ Support multiple orientations (portrait, landscape)
- ✅ Design for touch interactions and gestures
- ✅ Support Dark Mode and Dynamic Type
- ✅ Handle app lifecycle properly
- ❌ Avoid desktop-style UI patterns
- ❌ Avoid hardcoding UI dimensions

### UI Framework Selection
- ✅ SwiftUI for modern iOS apps (iOS 15+)
- ✅ UIKit for complex custom UI or legacy support
- ✅ Combine SwiftUI + UIKit when needed
- ✅ Use UIViewRepresentable for bridging UIKit to SwiftUI

### iOS-Specific Features
- ✅ Widgets (Home Screen, Lock Screen)
- ✅ App Shortcuts and Siri integration
- ✅ Live Activities (iOS 16+)
- ✅ Focus Filters
- ✅ SharePlay
- ✅ Continuity (Handoff, Universal Clipboard)
- ✅ Push notifications
- ✅ Background tasks

### Architecture Patterns
- ✅ MVVM for SwiftUI applications
- ✅ MVC or MVVM for UIKit applications
- ✅ Coordinator pattern for navigation
- ✅ Clean Architecture for complex apps
- ❌ Avoid massive view controllers

---

## Detailed Guidelines

For comprehensive iOS best practices, see:
- **[Architecture Patterns](./architecture.md)**: MVVM, Clean Architecture, Coordinator
- **[Security & Privacy](./security.md)**: Keychain, permissions, App Transport Security

---

## Framework Selection Guide

### UI Frameworks
| Framework | Use Case | iOS Version | Notes |
|-----------|----------|-------------|-------|
| **SwiftUI** | Modern apps | iOS 13+ | Declarative, cross-platform |
| **UIKit** | Complex custom UI | iOS 2+ | Full control, mature |
| **UIKit + SwiftUI** | Hybrid approach | iOS 13+ | Best of both worlds |

### Data & Persistence
| Framework | Use Case | iOS Version | Notes |
|-----------|----------|-------------|-------|
| **SwiftData** | Modern data modeling | iOS 17+ | Swift-native, type-safe |
| **Core Data** | Complex data models | iOS 3+ | Mature, powerful |
| **UserDefaults** | Simple preferences | iOS 2+ | Key-value storage |
| **Keychain** | Sensitive data | iOS 2+ | Secure storage |
| **CloudKit** | iCloud sync | iOS 7+ | Apple ecosystem sync |

---

## SwiftUI for iOS

### Navigation

```swift
// iOS 16+ NavigationStack
struct ContentView: View {
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            List(items) { item in
                NavigationLink(item.title, value: item)
            }
            .navigationTitle("Items")
            .navigationDestination(for: Item.self) { item in
                ItemDetailView(item: item)
            }
        }
    }
}

// Legacy NavigationView (iOS 13-15)
struct ContentView: View {
    var body: some View {
        NavigationView {
            List(items) { item in
                NavigationLink(destination: ItemDetailView(item: item)) {
                    ItemRow(item: item)
                }
            }
            .navigationTitle("Items")
        }
        .navigationViewStyle(.stack)  // Important for iPhone
    }
}
```

### Sheets and Modals

```swift
struct ContentView: View {
    @State private var showingSheet = false
    @State private var showingFullScreen = false

    var body: some View {
        VStack {
            Button("Show Sheet") {
                showingSheet = true
            }
            .sheet(isPresented: $showingSheet) {
                SheetView()
            }

            Button("Show Full Screen") {
                showingFullScreen = true
            }
            .fullScreenCover(isPresented: $showingFullScreen) {
                FullScreenView()
            }
        }
    }
}

// Detent support (iOS 16+)
.sheet(isPresented: $showingSheet) {
    SheetView()
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
}
```

### Responsive Layout

```swift
struct ResponsiveView: View {
    @Environment(\.horizontalSizeClass) var horizontalSizeClass

    var body: some View {
        if horizontalSizeClass == .compact {
            // iPhone portrait
            VStack {
                HeaderView()
                ContentView()
            }
        } else {
            // iPhone landscape or iPad
            HStack {
                SidebarView()
                ContentView()
            }
        }
    }
}
```

---

## UIKit Patterns

### UIViewController Lifecycle

```swift
class ItemViewController: UIViewController {
    private let viewModel: ItemViewModel

    init(viewModel: ItemViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupConstraints()
        bindViewModel()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        viewModel.refresh()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        trackScreenView()
    }

    private func setupUI() {
        view.backgroundColor = .systemBackground
        // Setup UI components
    }

    private func setupConstraints() {
        // Setup Auto Layout
    }

    private func bindViewModel() {
        // Bind to ViewModel
    }
}
```

### UITableView with Diffable Data Source

```swift
class ItemListViewController: UIViewController {
    enum Section {
        case main
    }

    private var tableView: UITableView!
    private var dataSource: UITableViewDiffableDataSource<Section, Item>!

    override func viewDidLoad() {
        super.viewDidLoad()

        setupTableView()
        configureDataSource()
        applySnapshot()
    }

    private func setupTableView() {
        tableView = UITableView(frame: view.bounds, style: .insetGrouped)
        tableView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        tableView.register(ItemCell.self, forCellReuseIdentifier: "ItemCell")
        view.addSubview(tableView)
    }

    private func configureDataSource() {
        dataSource = UITableViewDiffableDataSource<Section, Item>(
            tableView: tableView
        ) { tableView, indexPath, item in
            let cell = tableView.dequeueReusableCell(
                withIdentifier: "ItemCell",
                for: indexPath
            ) as! ItemCell
            cell.configure(with: item)
            return cell
        }
    }

    private func applySnapshot(with items: [Item] = []) {
        var snapshot = NSDiffableDataSourceSnapshot<Section, Item>()
        snapshot.appendSections([.main])
        snapshot.appendItems(items)
        dataSource.apply(snapshot, animatingDifferences: true)
    }
}
```

### UICollectionView with Compositional Layout

```swift
class GridViewController: UIViewController {
    private var collectionView: UICollectionView!

    override func viewDidLoad() {
        super.viewDidLoad()
        setupCollectionView()
    }

    private func setupCollectionView() {
        let layout = createLayout()
        collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: layout)
        collectionView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        collectionView.register(ItemCell.self, forCellWithReuseIdentifier: "ItemCell")
        view.addSubview(collectionView)
    }

    private func createLayout() -> UICollectionViewLayout {
        let itemSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(0.5),
            heightDimension: .fractionalHeight(1.0)
        )
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        item.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8)

        let groupSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .fractionalWidth(0.5)
        )
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])

        let section = NSCollectionLayoutSection(group: group)
        section.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8)

        return UICollectionViewCompositionalLayout(section: section)
    }
}
```

---

## Widgets

### Home Screen Widget

```swift
import WidgetKit
import SwiftUI

struct ItemWidget: Widget {
    let kind: String = "ItemWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            ItemWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("My Items")
        .description("Shows your items.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), item: Item.placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        let entry = SimpleEntry(date: Date(), item: Item.sample)
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        Task {
            let items = try await fetchItems()
            let entries = items.enumerated().map { index, item in
                let date = Calendar.current.date(byAdding: .hour, value: index, to: Date())!
                return SimpleEntry(date: date, item: item)
            }

            let timeline = Timeline(entries: entries, policy: .atEnd)
            completion(timeline)
        }
    }
}

struct ItemWidgetEntryView: View {
    var entry: Provider.Entry

    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(item: entry.item)
        case .systemMedium:
            MediumWidgetView(item: entry.item)
        case .systemLarge:
            LargeWidgetView(item: entry.item)
        default:
            EmptyView()
        }
    }
}
```

### Lock Screen Widget (iOS 16+)

```swift
struct LockScreenWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "LockScreenWidget", provider: Provider()) { entry in
            LockScreenWidgetView(entry: entry)
        }
        .configurationDisplayName("Quick Status")
        .description("Shows status on lock screen")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

struct LockScreenWidgetView: View {
    var entry: Provider.Entry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .accessoryCircular:
            Gauge(value: entry.progress) {
                Text("\(Int(entry.progress * 100))%")
            }
            .gaugeStyle(.accessoryCircular)

        case .accessoryRectangular:
            VStack(alignment: .leading) {
                Text(entry.title)
                    .font(.headline)
                Text(entry.subtitle)
                    .font(.caption)
            }

        case .accessoryInline:
            Text(entry.title)

        default:
            EmptyView()
        }
    }
}
```

---

## Live Activities (iOS 16+)

```swift
import ActivityKit

struct OrderAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var status: String
        var estimatedDeliveryTime: Date
    }

    var orderNumber: String
}

// Start Live Activity
func startLiveActivity() {
    let attributes = OrderAttributes(orderNumber: "12345")
    let initialState = OrderAttributes.ContentState(
        status: "Preparing",
        estimatedDeliveryTime: Date().addingTimeInterval(3600)
    )

    do {
        let activity = try Activity<OrderAttributes>.request(
            attributes: attributes,
            contentState: initialState,
            pushType: nil
        )
        print("Live Activity started: \(activity.id)")
    } catch {
        print("Error starting Live Activity: \(error)")
    }
}

// Update Live Activity
func updateLiveActivity(activity: Activity<OrderAttributes>) {
    Task {
        let updatedState = OrderAttributes.ContentState(
            status: "Out for delivery",
            estimatedDeliveryTime: Date().addingTimeInterval(1800)
        )

        await activity.update(using: updatedState)
    }
}

// End Live Activity
func endLiveActivity(activity: Activity<OrderAttributes>) {
    Task {
        await activity.end(dismissalPolicy: .immediate)
    }
}
```

---

## Push Notifications

### Request Permission

```swift
import UserNotifications

class NotificationManager {
    static let shared = NotificationManager()

    func requestAuthorization() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
            return granted
        } catch {
            print("Error requesting notification permission: \(error)")
            return false
        }
    }

    func registerForRemoteNotifications() {
        DispatchQueue.main.async {
            UIApplication.shared.registerForRemoteNotifications()
        }
    }
}

// In AppDelegate
func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
) {
    let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
    print("Device token: \(token)")
    // Send token to server
}

func application(
    _ application: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
) {
    print("Failed to register for remote notifications: \(error)")
}
```

### Handle Notifications

```swift
extension AppDelegate: UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Handle foreground notification
        completionHandler([.banner, .sound, .badge])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        // Handle notification tap
        let userInfo = response.notification.request.content.userInfo

        if let itemID = userInfo["itemID"] as? String {
            // Navigate to item
        }

        completionHandler()
    }
}
```

---

## Background Tasks

### Background App Refresh

```swift
import BackgroundTasks

class BackgroundTaskManager {
    static let taskIdentifier = "com.example.app.refresh"

    static func register() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: taskIdentifier,
            using: nil
        ) { task in
            handleAppRefresh(task: task as! BGAppRefreshTask)
        }
    }

    static func scheduleAppRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: taskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60) // 15 minutes

        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("Could not schedule app refresh: \(error)")
        }
    }

    private static func handleAppRefresh(task: BGAppRefreshTask) {
        scheduleAppRefresh() // Schedule next refresh

        Task {
            do {
                try await performBackgroundWork()
                task.setTaskCompleted(success: true)
            } catch {
                task.setTaskCompleted(success: false)
            }
        }

        task.expirationHandler = {
            // Clean up
        }
    }

    private static func performBackgroundWork() async throws {
        // Fetch new data, sync, etc.
    }
}

// In Info.plist
// <key>BGTaskSchedulerPermittedIdentifiers</key>
// <array>
//     <string>com.example.app.refresh</string>
// </array>

// In AppDelegate
func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
) -> Bool {
    BackgroundTaskManager.register()
    return true
}
```

---

## iPad-Specific Features

### Multitasking and Split View

```swift
// Support all multitasking modes in Info.plist
// <key>UIRequiresFullScreen</key>
// <false/>

// Adaptive layout for iPad
struct ContentView: View {
    @Environment(\.horizontalSizeClass) var horizontalSizeClass

    var body: some View {
        if horizontalSizeClass == .regular {
            // iPad or iPhone landscape
            NavigationSplitView {
                SidebarView()
            } detail: {
                DetailView()
            }
        } else {
            // iPhone portrait
            NavigationStack {
                ListView()
            }
        }
    }
}
```

### Drag and Drop

```swift
// SwiftUI
struct ContentView: View {
    @State private var items: [String] = ["Item 1", "Item 2", "Item 3"]

    var body: some View {
        List {
            ForEach(items, id: \.self) { item in
                Text(item)
                    .onDrag {
                        NSItemProvider(object: item as NSString)
                    }
            }
            .onInsert(of: [.text]) { index, providers in
                for provider in providers {
                    provider.loadObject(ofClass: String.self) { string, _ in
                        if let string = string {
                            items.insert(string, at: index)
                        }
                    }
                }
            }
        }
    }
}
```

---

## Common Anti-Patterns

### ❌ Not Supporting iPad

```swift
// Bad: iPhone-only layout
VStack {
    // Fixed layout
}

// Good: Adaptive layout
if horizontalSizeClass == .regular {
    HStack { /* iPad layout */ }
} else {
    VStack { /* iPhone layout */ }
}
```

### ❌ Ignoring Safe Areas

```swift
// Bad: Content under notch/home indicator
VStack {
    // Content
}

// Good: Respect safe areas
VStack {
    // Content
}
.edgesIgnoringSafeArea(.bottom)  // Only when intentional
```

---

## Integration with General Principles

iOS code should follow:
- **[Code Quality Principles](../../general/code-quality.md)**: Explicitness, locality, fail-fast
- **[Unix Philosophy](../../../../principles/unix-philosophy.md)**: Single responsibility, composability
- **[Testing Strategy](../../../../testing/strategy.md)**: Unit tests, UI tests

---

## When to Escalate

Consult human developers for:
- **App Store submission**: Review guidelines, rejection handling
- **Privacy compliance**: iOS 14+ privacy features, App Tracking Transparency
- **Performance optimization**: Instruments profiling, memory issues
- **Complex animations**: Custom transitions, UIKit Dynamics
- **Platform version support**: Minimum deployment target decisions
- **Third-party SDK integration**: Analytics, crash reporting, A/B testing
