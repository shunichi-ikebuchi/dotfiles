# watchOS Architecture Patterns

Architectural patterns and best practices for Apple Watch applications.

---

## Simple MVVM for watchOS

### Overview

Keep watchOS apps simple. The MVVM pattern works well, but avoid over-engineering.

**Components**:
- **Model**: Shared data models (often from iPhone app)
- **View**: SwiftUI views optimized for small screen
- **ViewModel**: Minimal presentation logic

### Example

```swift
// Model (shared with iPhone app)
struct Activity: Identifiable, Codable {
    let id: String
    let name: String
    let duration: TimeInterval
    let calories: Double
}

// ViewModel
@MainActor
class ActivityViewModel: ObservableObject {
    @Published var activities: [Activity] = []
    @Published var isLoading = false

    private let connectivityManager = WatchConnectivityManager.shared

    func loadActivities() {
        isLoading = true

        // Request from iPhone
        connectivityManager.sendMessage(["action": "getActivities"]) { [weak self] response in
            if let activitiesData = response["activities"] as? Data {
                let decoder = JSONDecoder()
                if let activities = try? decoder.decode([Activity].self, from: activitiesData) {
                    DispatchQueue.main.async {
                        self?.activities = activities
                        self?.isLoading = false
                    }
                }
            }
        }
    }
}

// View
struct ActivityListView: View {
    @StateObject private var viewModel = ActivityViewModel()

    var body: some View {
        List {
            if viewModel.isLoading {
                ProgressView()
            } else {
                ForEach(viewModel.activities) { activity in
                    ActivityRow(activity: activity)
                }
            }
        }
        .onAppear {
            viewModel.loadActivities()
        }
    }
}

struct ActivityRow: View {
    let activity: Activity

    var body: some View {
        VStack(alignment: .leading) {
            Text(activity.name)
                .font(.headline)
            Text("\(Int(activity.duration / 60)) min • \(Int(activity.calories)) cal")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}
```

---

## Shared Business Logic

### Code Sharing with iPhone App

Organize code to share business logic between iPhone and Watch apps:

```
MyApp/
├── Shared/
│   ├── Models/
│   │   ├── Activity.swift
│   │   ├── User.swift
│   │   └── Workout.swift
│   ├── Services/
│   │   ├── HealthKitService.swift
│   │   └── StorageService.swift
│   └── Utilities/
│       └── DateFormatter+Extensions.swift
├── iOS/
│   ├── Views/
│   ├── ViewModels/
│   └── Services/
│       └── NetworkService.swift
└── watchOS/
    ├── Views/
    ├── ViewModels/
    └── Complications/
```

### Shared Data Models

```swift
// Shared/Models/Workout.swift
struct Workout: Identifiable, Codable {
    let id: String
    let type: WorkoutType
    let startDate: Date
    let endDate: Date
    let distance: Double
    let calories: Double

    enum WorkoutType: String, Codable {
        case running
        case cycling
        case walking
    }
}

// Used in both iPhone and Watch apps
```

---

## Watch Connectivity Architecture

### Centralized Communication Manager

```swift
import WatchConnectivity

protocol WatchConnectivityDelegate: AnyObject {
    func didReceiveData(_ data: [String: Any])
    func didReceiveUserInfo(_ userInfo: [String: Any])
}

class WatchConnectivityManager: NSObject, ObservableObject {
    static let shared = WatchConnectivityManager()

    @Published var isReachable = false
    @Published var isPaired = false
    @Published var isWatchAppInstalled = false

    weak var delegate: WatchConnectivityDelegate?

    private override init() {
        super.init()

        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self
            session.activate()
        }
    }

    // MARK: - Send Data

    func sendMessage(_ message: [String: Any], replyHandler: (([String: Any]) -> Void)? = nil) {
        guard WCSession.default.isReachable else {
            print("Session not reachable")
            transferUserInfo(message)  // Fallback to background transfer
            return
        }

        WCSession.default.sendMessage(message, replyHandler: replyHandler) { error in
            print("Error: \(error)")
        }
    }

    func transferUserInfo(_ userInfo: [String: Any]) {
        WCSession.default.transferUserInfo(userInfo)
    }

    func updateApplicationContext(_ context: [String: Any]) {
        do {
            try WCSession.default.updateApplicationContext(context)
        } catch {
            print("Error updating context: \(error)")
        }
    }
}

extension WatchConnectivityManager: WCSessionDelegate {
    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        DispatchQueue.main.async {
            self.isReachable = session.isReachable
            self.isPaired = session.isPaired
            self.isWatchAppInstalled = session.isWatchAppInstalled
        }
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isReachable = session.isReachable
        }
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        delegate?.didReceiveData(message)
    }

    func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any],
        replyHandler: @escaping ([String: Any]) -> Void
    ) {
        // Handle message and send reply
        handleMessage(message, replyHandler: replyHandler)
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        delegate?.didReceiveUserInfo(userInfo)
    }

    private func handleMessage(
        _ message: [String: Any],
        replyHandler: @escaping ([String: Any]) -> Void
    ) {
        // Process message
        delegate?.didReceiveData(message)

        // Send reply
        replyHandler(["status": "received"])
    }

    #if os(iOS)
    func sessionDidBecomeInactive(_ session: WCSession) {
        print("Session became inactive")
    }

    func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
    #endif
}
```

---

## Background Refresh

### Scheduling Background Tasks

```swift
import ClockKit

class BackgroundRefreshManager {
    static func scheduleBackgroundRefresh() {
        let targetDate = Date().addingTimeInterval(15 * 60) // 15 minutes
        WKApplication.shared().scheduleBackgroundRefresh(
            withPreferredDate: targetDate,
            userInfo: nil
        ) { error in
            if let error = error {
                print("Error scheduling background refresh: \(error)")
            }
        }
    }

    static func handleBackgroundTasks(_ task: WKRefreshBackgroundTask) {
        switch task {
        case let backgroundTask as WKApplicationRefreshBackgroundTask:
            // Fetch new data
            Task {
                await fetchNewData()
                backgroundTask.setTaskCompletedWithSnapshot(true)
                scheduleBackgroundRefresh()  // Schedule next refresh
            }

        case let snapshotTask as WKSnapshotRefreshBackgroundTask:
            // Update UI for snapshot
            snapshotTask.setTaskCompleted(
                restoredDefaultState: true,
                estimatedSnapshotExpiration: Date().addingTimeInterval(60 * 60),
                userInfo: nil
            )

        case let connectivityTask as WKWatchConnectivityRefreshBackgroundTask:
            // Handle Watch Connectivity update
            connectivityTask.setTaskCompletedWithSnapshot(false)

        case let urlSessionTask as WKURLSessionRefreshBackgroundTask:
            // Handle URL session completion
            urlSessionTask.setTaskCompletedWithSnapshot(false)

        default:
            task.setTaskCompletedWithSnapshot(false)
        }
    }

    private static func fetchNewData() async {
        // Fetch new data from iPhone or network
    }
}

// In ExtensionDelegate
func handle(_ backgroundTasks: Set<WKRefreshBackgroundTask>) {
    for task in backgroundTasks {
        BackgroundRefreshManager.handleBackgroundTasks(task)
    }
}
```

---

## Workout Architecture

### Workout Manager

```swift
import HealthKit

class WorkoutManager: NSObject, ObservableObject {
    @Published var isActive = false
    @Published var heartRate: Double = 0
    @Published var activeEnergy: Double = 0
    @Published var distance: Double = 0
    @Published var elapsedTime: TimeInterval = 0

    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?
    private let healthStore = HKHealthStore()
    private var timer: Timer?
    private var startDate: Date?

    // MARK: - Control

    func start() {
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .running
        configuration.locationType = .outdoor

        do {
            session = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
            builder = session?.associatedWorkoutBuilder()

            builder?.dataSource = HKLiveWorkoutDataSource(
                healthStore: healthStore,
                workoutConfiguration: configuration
            )

            session?.delegate = self
            builder?.delegate = self

            startDate = Date()
            session?.startActivity(with: startDate!)
            builder?.beginCollection(withStart: startDate!) { success, error in
                if success {
                    DispatchQueue.main.async {
                        self.isActive = true
                        self.startTimer()
                    }
                }
            }
        } catch {
            print("Error starting workout: \(error)")
        }
    }

    func pause() {
        session?.pause()
        stopTimer()
    }

    func resume() {
        session?.resume()
        startTimer()
    }

    func end() {
        session?.end()
        stopTimer()
    }

    // MARK: - Timer

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self = self, let startDate = self.startDate else { return }
            self.elapsedTime = Date().timeIntervalSince(startDate)
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}

extension WorkoutManager: HKWorkoutSessionDelegate {
    func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didChangeTo toState: HKWorkoutSessionState,
        from fromState: HKWorkoutSessionState,
        date: Date
    ) {
        DispatchQueue.main.async {
            switch toState {
            case .running:
                self.isActive = true
            case .paused:
                break
            case .ended:
                self.isActive = false
                self.builder?.endCollection(withEnd: date) { success, error in
                    self.builder?.finishWorkout { workout, error in
                        // Workout saved
                    }
                }
            default:
                break
            }
        }
    }

    func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        print("Workout error: \(error)")
    }
}

extension WorkoutManager: HKLiveWorkoutBuilderDelegate {
    func workoutBuilder(
        _ workoutBuilder: HKLiveWorkoutBuilder,
        didCollectDataOf collectedTypes: Set<HKSampleType>
    ) {
        for type in collectedTypes {
            guard let quantityType = type as? HKQuantityType else { continue }
            let statistics = workoutBuilder.statistics(for: quantityType)

            updateMetrics(for: quantityType, statistics: statistics)
        }
    }

    func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}

    private func updateMetrics(for type: HKQuantityType, statistics: HKStatistics?) {
        DispatchQueue.main.async {
            switch type {
            case HKQuantityType.quantityType(forIdentifier: .heartRate):
                let unit = HKUnit.count().unitDivided(by: .minute())
                self.heartRate = statistics?.mostRecentQuantity()?.doubleValue(for: unit) ?? 0

            case HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned):
                let unit = HKUnit.kilocalorie()
                self.activeEnergy = statistics?.sumQuantity()?.doubleValue(for: unit) ?? 0

            case HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning):
                let unit = HKUnit.meter()
                self.distance = statistics?.sumQuantity()?.doubleValue(for: unit) ?? 0

            default:
                break
            }
        }
    }
}
```

---

## Data Persistence

### User Defaults (Simple Preferences)

```swift
extension UserDefaults {
    var lastSyncDate: Date? {
        get { object(forKey: "lastSyncDate") as? Date }
        set { set(newValue, forKey: "lastSyncDate") }
    }

    var workoutGoal: Int {
        get { integer(forKey: "workoutGoal") }
        set { set(newValue, forKey: "workoutGoal") }
    }
}
```

### Avoid Heavy Persistence

- ❌ Don't use Core Data on watchOS (performance issues)
- ✅ Store simple data in UserDefaults
- ✅ Sync data from iPhone via Watch Connectivity
- ✅ Use HealthKit for health/fitness data

---

## Testing watchOS Apps

### Unit Tests

```swift
import XCTest
@testable import MyWatchApp

class WorkoutManagerTests: XCTestCase {
    var sut: WorkoutManager!

    override func setUp() {
        super.setUp()
        sut = WorkoutManager()
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    func testInitialState() {
        XCTAssertFalse(sut.isActive)
        XCTAssertEqual(sut.heartRate, 0)
        XCTAssertEqual(sut.elapsedTime, 0)
    }
}
```

### Integration Tests with Watch Connectivity

```swift
class WatchConnectivityTests: XCTestCase {
    var sut: WatchConnectivityManager!

    override func setUp() {
        super.setUp()
        sut = WatchConnectivityManager.shared
    }

    func testSendMessage() {
        let expectation = expectation(description: "Message sent")

        sut.sendMessage(["test": "data"]) { response in
            XCTAssertNotNil(response)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 5)
    }
}
```

---

## Best Practices

### Architecture
- ✅ Keep it simple (avoid over-engineering)
- ✅ Share business logic with iPhone app
- ✅ Use Watch Connectivity for data sync
- ✅ Minimize local data storage
- ❌ Avoid complex state management

### Performance
- ✅ Optimize for battery life
- ✅ Minimize background refresh frequency
- ✅ Use efficient data structures
- ✅ Batch network requests
- ❌ Don't poll for updates constantly

### User Experience
- ✅ Design for glanceability
- ✅ Keep interactions quick
- ✅ Use haptic feedback
- ✅ Support Always-On display
- ❌ Avoid multi-step workflows

---

## Integration with General Principles

watchOS architecture should follow:
- **[Code Quality Principles](../../general/code-quality.md)**: Simplicity, clarity
- **[Unix Philosophy](../../../../principles/unix-philosophy.md)**: Do one thing well
- **[Testing Strategy](../../../../testing/strategy.md)**: Focus on business logic tests
