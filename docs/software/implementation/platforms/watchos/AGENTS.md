# watchOS Platform Guidelines

watchOS-specific instructions for AI coding agents working on Apple Watch applications.

**Philosophy**: Build glanceable, actionable watchOS apps optimized for the unique constraints and capabilities of Apple Watch. Focus on quick interactions and essential information.

---

## Quick Reference

### Core Principles
- ✅ Design for glanceability (quick, at-a-glance information)
- ✅ Keep interactions simple and brief
- ✅ Use SwiftUI for watchOS 7+
- ✅ Support complications for watch faces
- ✅ Optimize for small screen sizes
- ✅ Leverage Digital Crown, haptics, and gestures
- ✅ Support Always-On display (Series 5+)
- ❌ Avoid complex multi-step workflows
- ❌ Avoid text-heavy interfaces
- ❌ Avoid small tap targets

### watchOS-Specific Features
- ✅ Complications (watch face widgets)
- ✅ Notifications (rich, actionable)
- ✅ Workout tracking
- ✅ Health data integration
- ✅ Background refresh
- ✅ Handoff with iPhone
- ✅ Digital Crown navigation
- ✅ Haptic feedback

### UI Guidelines
- ✅ Use large, clear text
- ✅ Prioritize visual hierarchy
- ✅ Use system colors and SF Symbols
- ✅ Design for both watch sizes (40mm, 44mm, 45mm, 49mm)
- ✅ Support Always-On display
- ❌ Avoid horizontal scrolling
- ❌ Avoid tiny touch targets (minimum 44pt)

### Architecture Patterns
- ✅ MVVM for SwiftUI applications
- ✅ Shared business logic with iOS app
- ✅ Watch Connectivity for iPhone communication
- ❌ Avoid complex architectures (keep it simple)

---

## Detailed Guidelines

For comprehensive watchOS best practices, see:
- **[Architecture Patterns](./architecture.md)**: MVVM, Shared logic, Watch Connectivity
- **[Security & Privacy](./security.md)**: Health data, permissions, Keychain

---

## Framework Selection Guide

### UI Frameworks
| Framework | Use Case | watchOS Version | Notes |
|-----------|----------|----------------|-------|
| **SwiftUI** | Modern watch apps | watchOS 7+ | Recommended |
| **WatchKit** | Legacy apps | watchOS 2-6 | Deprecated, avoid |

### watchOS-Specific APIs
| API | Use Case | Notes |
|-----|----------|-------|
| **WatchConnectivity** | iPhone communication | Sync data, trigger actions |
| **HealthKit** | Health data | Heart rate, workouts, etc. |
| **ClockKit** | Complications | Watch face widgets |
| **WorkoutKit** | Workout tracking | GPS, heart rate monitoring |
| **CoreLocation** | Location services | GPS on GPS+Cellular models |

---

## SwiftUI for watchOS

### Basic Watch App Structure

```swift
@main
struct MyWatchApp: App {
    @StateObject private var workoutManager = WorkoutManager()

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                ContentView()
            }
            .environmentObject(workoutManager)
        }
    }
}

struct ContentView: View {
    var body: some View {
        List {
            NavigationLink("Start Workout") {
                WorkoutView()
            }

            NavigationLink("Settings") {
                SettingsView()
            }
        }
        .navigationTitle("My Watch App")
    }
}
```

### Navigation

```swift
// Tab-based navigation (watchOS 7+)
struct ContentView: View {
    var body: some View {
        TabView {
            ActivityView()
                .tabItem {
                    Label("Activity", systemImage: "figure.walk")
                }

            WorkoutView()
                .tabItem {
                    Label("Workout", systemImage: "figure.run")
                }

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
        }
    }
}

// Paging navigation
struct PagingView: View {
    var body: some View {
        TabView {
            Page1View()
            Page2View()
            Page3View()
        }
        .tabViewStyle(.page)
    }
}
```

### Digital Crown Support

```swift
struct DigitalCrownView: View {
    @State private var scrollAmount = 0.0

    var body: some View {
        VStack {
            Text("Value: \(scrollAmount, specifier: "%.2f")")
                .font(.title2)

            Circle()
                .fill(Color.blue)
                .frame(width: scrollAmount * 100, height: scrollAmount * 100)
        }
        .focusable()
        .digitalCrownRotation($scrollAmount, from: 0, through: 1, by: 0.01, sensitivity: .medium)
    }
}

// Digital Crown with haptic feedback
struct HapticCrownView: View {
    @State private var value = 0.0

    var body: some View {
        VStack {
            Text("\(Int(value))")
                .font(.title)
        }
        .focusable()
        .digitalCrownRotation(
            $value,
            from: 0,
            through: 10,
            by: 1,
            sensitivity: .medium,
            isContinuous: false,
            isHapticFeedbackEnabled: true
        )
    }
}
```

---

## Complications

### Complication Provider

```swift
import ClockKit

class ComplicationController: NSObject, CLKComplicationDataSource {
    // MARK: - Complication Configuration

    func getComplicationDescriptors(handler: @escaping ([CLKComplicationDescriptor]) -> Void) {
        let descriptors = [
            CLKComplicationDescriptor(
                identifier: "complication",
                displayName: "My Complication",
                supportedFamilies: [
                    .modularSmall,
                    .modularLarge,
                    .utilitarianSmall,
                    .utilitarianLarge,
                    .circularSmall,
                    .graphicCorner,
                    .graphicCircular,
                    .graphicRectangular
                ]
            )
        ]
        handler(descriptors)
    }

    // MARK: - Timeline Configuration

    func getTimelineEndDate(
        for complication: CLKComplication,
        withHandler handler: @escaping (Date?) -> Void
    ) {
        // Return end date for timeline (e.g., 24 hours from now)
        handler(Date().addingTimeInterval(24 * 60 * 60))
    }

    func getPrivacyBehavior(
        for complication: CLKComplication,
        withHandler handler: @escaping (CLKComplicationPrivacyBehavior) -> Void
    ) {
        handler(.showOnLockScreen)
    }

    // MARK: - Timeline Population

    func getCurrentTimelineEntry(
        for complication: CLKComplication,
        withHandler handler: @escaping (CLKComplicationTimelineEntry?) -> Void
    ) {
        let template = makeTemplate(for: complication.family)
        let entry = CLKComplicationTimelineEntry(date: Date(), complicationTemplate: template)
        handler(entry)
    }

    func getTimelineEntries(
        for complication: CLKComplication,
        after date: Date,
        limit: Int,
        withHandler handler: @escaping ([CLKComplicationTimelineEntry]?) -> Void
    ) {
        var entries: [CLKComplicationTimelineEntry] = []

        for hour in 1...limit {
            let entryDate = date.addingTimeInterval(TimeInterval(hour * 60 * 60))
            let template = makeTemplate(for: complication.family)
            entries.append(CLKComplicationTimelineEntry(date: entryDate, complicationTemplate: template))
        }

        handler(entries)
    }

    // MARK: - Template Creation

    private func makeTemplate(for family: CLKComplicationFamily) -> CLKComplicationTemplate {
        switch family {
        case .modularSmall:
            return CLKComplicationTemplateModularSmallSimpleText(
                textProvider: CLKSimpleTextProvider(text: "42")
            )

        case .graphicCircular:
            return CLKComplicationTemplateGraphicCircularStackText(
                line1TextProvider: CLKSimpleTextProvider(text: "Steps"),
                line2TextProvider: CLKSimpleTextProvider(text: "8,432")
            )

        case .graphicRectangular:
            return CLKComplicationTemplateGraphicRectangularStandardBody(
                headerTextProvider: CLKSimpleTextProvider(text: "Activity"),
                body1TextProvider: CLKSimpleTextProvider(text: "8,432 steps"),
                body2TextProvider: CLKSimpleTextProvider(text: "3.2 miles")
            )

        default:
            return CLKComplicationTemplateModularSmallSimpleText(
                textProvider: CLKSimpleTextProvider(text: "N/A")
            )
        }
    }
}

// Update complications
func updateComplications() {
    let server = CLKComplicationServer.sharedInstance()
    for complication in server.activeComplications ?? [] {
        server.reloadTimeline(for: complication)
    }
}
```

### SwiftUI Complication (watchOS 9+)

```swift
import WidgetKit
import SwiftUI

@main
struct MyWatchWidget: Widget {
    let kind: String = "MyWatchWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            ComplicationView(entry: entry)
        }
        .configurationDisplayName("My Complication")
        .description("Shows your activity")
        .supportedFamilies([
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline
        ])
    }
}

struct ComplicationView: View {
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
                Text("Steps")
                    .font(.headline)
                Text("\(entry.steps)")
                    .font(.title2)
            }

        case .accessoryInline:
            Text("\(entry.steps) steps")

        default:
            EmptyView()
        }
    }
}
```

---

## Watch Connectivity

### Communication with iPhone

```swift
import WatchConnectivity

class WatchConnectivityManager: NSObject, ObservableObject {
    static let shared = WatchConnectivityManager()

    @Published var receivedMessage: [String: Any] = [:]

    private override init() {
        super.init()

        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self
            session.activate()
        }
    }

    // Send message to iPhone (immediate)
    func sendMessage(_ message: [String: Any], replyHandler: (([String: Any]) -> Void)? = nil) {
        guard WCSession.default.isReachable else {
            print("iPhone not reachable")
            return
        }

        WCSession.default.sendMessage(message, replyHandler: replyHandler) { error in
            print("Error sending message: \(error)")
        }
    }

    // Transfer user info (background, guaranteed delivery)
    func transferUserInfo(_ userInfo: [String: Any]) {
        WCSession.default.transferUserInfo(userInfo)
    }

    // Update application context (latest state)
    func updateApplicationContext(_ context: [String: Any]) {
        do {
            try WCSession.default.updateApplicationContext(context)
        } catch {
            print("Error updating context: \(error)")
        }
    }

    // Transfer file
    func transferFile(at url: URL, metadata: [String: Any]? = nil) {
        WCSession.default.transferFile(url, metadata: metadata)
    }
}

extension WatchConnectivityManager: WCSessionDelegate {
    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        if let error = error {
            print("Activation error: \(error)")
        }
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        DispatchQueue.main.async {
            self.receivedMessage = message
        }
    }

    func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any],
        replyHandler: @escaping ([String: Any]) -> Void
    ) {
        // Process message and send reply
        replyHandler(["status": "received"])
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        DispatchQueue.main.async {
            self.receivedMessage = userInfo
        }
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        DispatchQueue.main.async {
            self.receivedMessage = applicationContext
        }
    }
}
```

---

## HealthKit Integration

### Request Health Permissions

```swift
import HealthKit

class HealthKitManager {
    static let shared = HealthKitManager()
    private let healthStore = HKHealthStore()

    func requestAuthorization() async throws {
        let readTypes: Set<HKObjectType> = [
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)!,
            HKObjectType.workoutType()
        ]

        let writeTypes: Set<HKSampleType> = [
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKObjectType.workoutType()
        ]

        try await healthStore.requestAuthorization(toShare: writeTypes, read: readTypes)
    }

    func fetchHeartRate(completion: @escaping (Double?) -> Void) {
        guard let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate) else {
            completion(nil)
            return
        }

        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        let query = HKSampleQuery(
            sampleType: heartRateType,
            predicate: nil,
            limit: 1,
            sortDescriptors: [sortDescriptor]
        ) { query, samples, error in
            guard let sample = samples?.first as? HKQuantitySample else {
                completion(nil)
                return
            }

            let heartRate = sample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
            completion(heartRate)
        }

        healthStore.execute(query)
    }
}
```

---

## Workout Tracking

### Workout Session

```swift
import HealthKit

class WorkoutManager: NSObject, ObservableObject {
    @Published var isActive = false
    @Published var heartRate: Double = 0
    @Published var activeEnergy: Double = 0
    @Published var distance: Double = 0

    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?
    private let healthStore = HKHealthStore()

    func startWorkout() {
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

            session?.startActivity(with: Date())
            builder?.beginCollection(withStart: Date()) { success, error in
                if success {
                    DispatchQueue.main.async {
                        self.isActive = true
                    }
                }
            }
        } catch {
            print("Error starting workout: \(error)")
        }
    }

    func endWorkout() {
        session?.end()
        builder?.endCollection(withEnd: Date()) { success, error in
            self.builder?.finishWorkout { workout, error in
                DispatchQueue.main.async {
                    self.isActive = false
                }
            }
        }
    }
}

extension WorkoutManager: HKWorkoutSessionDelegate {
    func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didChangeTo toState: HKWorkoutSessionState,
        from fromState: HKWorkoutSessionState,
        date: Date
    ) {
        // Handle state changes
    }

    func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        print("Workout session error: \(error)")
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

            DispatchQueue.main.async {
                switch quantityType {
                case HKQuantityType.quantityType(forIdentifier: .heartRate):
                    let heartRateUnit = HKUnit.count().unitDivided(by: .minute())
                    self.heartRate = statistics?.mostRecentQuantity()?.doubleValue(for: heartRateUnit) ?? 0

                case HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned):
                    let energyUnit = HKUnit.kilocalorie()
                    self.activeEnergy = statistics?.sumQuantity()?.doubleValue(for: energyUnit) ?? 0

                case HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning):
                    let distanceUnit = HKUnit.meter()
                    self.distance = statistics?.sumQuantity()?.doubleValue(for: distanceUnit) ?? 0

                default:
                    break
                }
            }
        }
    }

    func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {
        // Handle workout events
    }
}
```

---

## Notifications

### Rich Notifications

```swift
import UserNotifications

// Create notification with actions
func scheduleNotification() {
    let content = UNMutableNotificationContent()
    content.title = "Workout Reminder"
    content.body = "Time for your daily workout!"
    content.sound = .default
    content.categoryIdentifier = "WORKOUT_REMINDER"

    let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 60, repeats: false)
    let request = UNNotificationRequest(identifier: "workout", content: content, trigger: trigger)

    UNUserNotificationCenter.current().add(request) { error in
        if let error = error {
            print("Error scheduling notification: \(error)")
        }
    }
}

// Define notification categories and actions
func setupNotificationCategories() {
    let startAction = UNNotificationAction(
        identifier: "START_ACTION",
        title: "Start Workout",
        options: [.foreground]
    )

    let snoozeAction = UNNotificationAction(
        identifier: "SNOOZE_ACTION",
        title: "Remind Later",
        options: []
    )

    let category = UNNotificationCategory(
        identifier: "WORKOUT_REMINDER",
        actions: [startAction, snoozeAction],
        intentIdentifiers: [],
        options: []
    )

    UNUserNotificationCenter.current().setNotificationCategories([category])
}

// Handle notification actions
extension NotificationDelegate: UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        switch response.actionIdentifier {
        case "START_ACTION":
            // Start workout
            break

        case "SNOOZE_ACTION":
            // Snooze reminder
            break

        default:
            break
        }

        completionHandler()
    }
}
```

---

## Always-On Display

### Optimizing for Always-On

```swift
struct AlwaysOnView: View {
    @Environment(\.isLuminanceReduced) var isLuminanceReduced

    var body: some View {
        VStack {
            if isLuminanceReduced {
                // Always-On display (dimmed state)
                Text("12:34")
                    .font(.system(size: 60, weight: .ultraLight))
                    .foregroundColor(.white)
            } else {
                // Active display
                VStack {
                    Text("12:34:56")
                        .font(.system(size: 50, weight: .semibold))

                    HStack {
                        Text("Heart Rate")
                        Spacer()
                        Text("72 BPM")
                    }
                    .font(.caption)
                }
            }
        }
    }
}
```

---

## Common Anti-Patterns

### ❌ Complex Multi-Step Workflows

```swift
// Bad: Too many steps on watch
NavigationStack {
    Step1View()
        → Step2View()
            → Step3View()
                → Step4View()
}

// Good: Keep it simple, delegate complexity to iPhone
NavigationStack {
    QuickActionView()  // One or two taps maximum
}
```

### ❌ Text-Heavy Interfaces

```swift
// Bad: Too much text
Text("This is a very long description that users will have to scroll through on their tiny watch screen...")

// Good: Concise, visual
VStack {
    Image(systemName: "checkmark.circle.fill")
        .font(.largeTitle)
        .foregroundColor(.green)
    Text("Complete")
}
```

---

## Performance Optimization

### Battery Efficiency

- ✅ Minimize background refresh frequency
- ✅ Use efficient data structures
- ✅ Batch network requests
- ✅ Avoid continuous animations
- ✅ Use Always-On display optimizations
- ❌ Don't poll for updates constantly
- ❌ Don't keep location services running unnecessarily

---

## Integration with General Principles

watchOS code should follow:
- **[Code Quality Principles](../../general/code-quality.md)**: Explicitness, locality, fail-fast
- **[Unix Philosophy](../../../../principles/unix-philosophy.md)**: Single responsibility, composability
- **[Testing Strategy](../../../../testing/strategy.md)**: Unit tests for business logic

---

## When to Escalate

Consult human developers for:
- **Health & Fitness compliance**: HealthKit restrictions, medical device classification
- **Battery optimization**: Complex power management scenarios
- **Complication design**: Intricate complication families and layouts
- **Workout tracking accuracy**: GPS, heart rate sensor calibration
- **Watch Connectivity**: Complex sync patterns between watch and iPhone
- **Performance issues**: Profiling watch-specific bottlenecks
