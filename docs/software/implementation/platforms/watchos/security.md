# watchOS Security & Privacy

Security and privacy best practices for Apple Watch applications.

---

## Keychain Access

### Secure Storage

```swift
import Security

class WatchKeychainManager {
    static let shared = WatchKeychainManager()

    func save(_ value: String, forKey key: String) throws {
        guard let data = value.data(using: .utf8) else {
            throw KeychainError.invalidData
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]

        SecItemDelete(query as CFDictionary)  // Delete existing
        let status = SecItemAdd(query as CFDictionary, nil)

        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status)
        }
    }

    func retrieve(forKey key: String) throws -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8) else {
            throw KeychainError.retrieveFailed(status)
        }

        return value
    }

    func delete(forKey key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]

        let status = SecItemDelete(query as CFDictionary)

        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.deleteFailed(status)
        }
    }
}

enum KeychainError: Error {
    case invalidData
    case saveFailed(OSStatus)
    case retrieveFailed(OSStatus)
    case deleteFailed(OSStatus)
}

// Usage
let keychain = WatchKeychainManager.shared
try keychain.save("myToken", forKey: "authToken")
let token = try keychain.retrieve(forKey: "authToken")
```

### Syncing with iPhone Keychain

**Note**: Keychain items are NOT automatically synced between iPhone and Watch. Use Watch Connectivity to transfer sensitive data securely when needed.

```swift
// On iPhone: Save and transfer to watch
func saveTokenAndSyncToWatch(_ token: String) {
    // Save to iPhone Keychain
    try? iPhoneKeychainManager.save(token, forKey: "authToken")

    // Transfer to Watch securely
    WatchConnectivityManager.shared.sendMessage(["authToken": token]) { response in
        print("Token sent to watch")
    }
}

// On Watch: Receive and save to Watch Keychain
func handleMessage(_ message: [String: Any]) {
    if let token = message["authToken"] as? String {
        try? WatchKeychainManager.shared.save(token, forKey: "authToken")
    }
}
```

---

## HealthKit Privacy

### Request Permissions

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
            HKObjectType.quantityType(forIdentifier: .stepCount)!,
            HKObjectType.workoutType()
        ]

        let writeTypes: Set<HKSampleType> = [
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKObjectType.workoutType()
        ]

        try await healthStore.requestAuthorization(toShare: writeTypes, read: readTypes)
    }
}

// In Info.plist
// <key>NSHealthShareUsageDescription</key>
// <string>We need access to your health data to track your workouts.</string>
// <key>NSHealthUpdateUsageDescription</key>
// <string>We need permission to save your workout data.</string>
```

### Handle Health Data Securely

```swift
// Good: Query only necessary data
func fetchRecentHeartRate() async throws -> Double? {
    guard let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) else {
        return nil
    }

    let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
    let query = HKSampleQuery(
        sampleType: heartRateType,
        predicate: nil,
        limit: 1,
        sortDescriptors: [sortDescriptor]
    ) { query, samples, error in
        // Handle result
    }

    healthStore.execute(query)
    // ...
}

// Bad: Don't store health data in UserDefaults or transmit without encryption
```

---

## Network Security

### HTTPS Only

```swift
// watchOS enforces App Transport Security (ATS)
func fetchData() async throws -> Data {
    let url = URL(string: "https://api.example.com/data")!  // HTTPS required

    let (data, response) = try await URLSession.shared.data(from: url)

    guard let httpResponse = response as? HTTPURLResponse,
          (200...299).contains(httpResponse.statusCode) else {
        throw NetworkError.invalidResponse
    }

    return data
}

enum NetworkError: Error {
    case invalidResponse
}
```

### Secure Token Transmission via Watch Connectivity

```swift
// Encrypt sensitive data before sending via Watch Connectivity
import CryptoKit

class SecureWatchCommunication {
    static let shared = SecureWatchCommunication()

    private let encryptionKey = SymmetricKey(size: .bits256)

    func sendSecureMessage(_ message: [String: String]) {
        do {
            let jsonData = try JSONEncoder().encode(message)
            let encryptedData = try encrypt(jsonData)

            WatchConnectivityManager.shared.sendMessage([
                "encrypted": encryptedData.base64EncodedString()
            ])
        } catch {
            print("Encryption error: \(error)")
        }
    }

    func receiveSecureMessage(_ message: [String: Any]) -> [String: String]? {
        guard let encryptedString = message["encrypted"] as? String,
              let encryptedData = Data(base64Encoded: encryptedString) else {
            return nil
        }

        do {
            let decryptedData = try decrypt(encryptedData)
            return try JSONDecoder().decode([String: String].self, from: decryptedData)
        } catch {
            print("Decryption error: \(error)")
            return nil
        }
    }

    private func encrypt(_ data: Data) throws -> Data {
        let sealedBox = try AES.GCM.seal(data, using: encryptionKey)
        return sealedBox.combined!
    }

    private func decrypt(_ data: Data) throws -> Data {
        let sealedBox = try AES.GCM.SealedBox(combined: data)
        return try AES.GCM.open(sealedBox, using: encryptionKey)
    }
}
```

---

## Location Privacy

### Request Location Permission

```swift
import CoreLocation

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()

    override init() {
        super.init()
        locationManager.delegate = self
    }

    func requestAuthorization() {
        locationManager.requestWhenInUseAuthorization()
    }

    func startTracking() {
        locationManager.startUpdatingLocation()
    }

    func stopTracking() {
        locationManager.stopUpdatingLocation()
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            // Permission granted
            break
        case .denied, .restricted:
            // Permission denied
            break
        case .notDetermined:
            break
        @unknown default:
            break
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        // Handle location updates
    }
}

// In Info.plist
// <key>NSLocationWhenInUseUsageDescription</key>
// <string>We need your location to track your outdoor workouts.</string>
```

### Minimize Location Tracking

```swift
// Good: Only track during workouts
class WorkoutLocationManager {
    private let locationManager = CLLocationManager()
    private var isWorkoutActive = false

    func startWorkout() {
        isWorkoutActive = true
        locationManager.startUpdatingLocation()
    }

    func endWorkout() {
        isWorkoutActive = false
        locationManager.stopUpdatingLocation()  // Stop when not needed
    }
}

// Bad: Always tracking location
```

---

## Notification Privacy

### Secure Notification Content

```swift
import UserNotifications

// Good: Don't include sensitive data in notifications
func sendNotification(title: String, body: String) {
    let content = UNMutableNotificationContent()
    content.title = title
    content.body = body  // Avoid including passwords, tokens, etc.
    content.sound = .default

    let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
    let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)

    UNUserNotificationCenter.current().add(request)
}

// Bad: Including sensitive data
func badNotification() {
    let content = UNMutableNotificationContent()
    content.title = "Login Successful"
    content.body = "Token: abc123xyz"  // Don't do this!
}
```

---

## Data Minimization

### Store Only Necessary Data

```swift
// Good: Minimal data storage
struct WorkoutSummary {
    let duration: TimeInterval
    let calories: Double
    let date: Date

    // Don't store: GPS coordinates, heart rate history, etc.
    // Those are in HealthKit, which is more secure
}

// Bad: Storing everything locally
struct BadWorkoutData {
    let gpsCoordinates: [CLLocation]  // Heavy, privacy-sensitive
    let heartRateHistory: [Double]     // Should be in HealthKit
    // ...
}
```

---

## Watch Connectivity Security

### Validate Received Data

```swift
extension WatchConnectivityManager {
    func handleReceivedMessage(_ message: [String: Any]) {
        // Validate message format
        guard let action = message["action"] as? String else {
            print("Invalid message format")
            return
        }

        // Validate action
        guard ["getWorkouts", "syncData", "updateSettings"].contains(action) else {
            print("Unknown action: \(action)")
            return
        }

        // Process valid message
        processMessage(action: action, data: message)
    }

    private func processMessage(action: String, data: [String: Any]) {
        switch action {
        case "getWorkouts":
            // Handle workout request
            break
        case "syncData":
            // Handle data sync
            break
        case "updateSettings":
            // Handle settings update
            break
        default:
            break
        }
    }
}
```

---

## Passcode and Authentication

### Check Device Passcode

```swift
import LocalAuthentication

class SecurityManager {
    func isDeviceSecure() -> Bool {
        let context = LAContext()
        return context.canEvaluatePolicy(.deviceOwnerAuthentication, error: nil)
    }

    func requireAuthentication() async -> Bool {
        let context = LAContext()
        context.localizedCancelTitle = "Cancel"

        do {
            let authenticated = try await context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: "Authenticate to access sensitive data"
            )
            return authenticated
        } catch {
            print("Authentication error: \(error)")
            return false
        }
    }
}

// Usage
let securityManager = SecurityManager()

if !securityManager.isDeviceSecure() {
    // Warn user that device is not secure
    print("Please set up a passcode on your Apple Watch")
}

// Before accessing sensitive data
if await securityManager.requireAuthentication() {
    // Access sensitive data
}
```

---

## Secure Coding Practices

### Input Validation

```swift
// Good: Validate all inputs
func updateUserGoal(_ goal: Int) {
    guard goal > 0 && goal <= 10000 else {
        print("Invalid goal value")
        return
    }

    UserDefaults.standard.set(goal, forKey: "dailyGoal")
}

// Bad: No validation
func badUpdateUserGoal(_ goal: Int) {
    UserDefaults.standard.set(goal, forKey: "dailyGoal")  // Could be negative or huge
}
```

### Avoid Hardcoded Secrets

```swift
// Bad: Hardcoded API key
let apiKey = "sk_live_abc123"  // Don't do this!

// Good: Load from configuration or Keychain
func getAPIKey() throws -> String {
    try WatchKeychainManager.shared.retrieve(forKey: "apiKey")
}
```

---

## Privacy Best Practices

### Transparency
- ✅ Clearly explain why you need health data
- ✅ Request only necessary permissions
- ✅ Provide privacy policy
- ✅ Allow users to delete their data

### Data Handling
- ✅ Store health data in HealthKit (not UserDefaults)
- ✅ Encrypt sensitive data at rest and in transit
- ✅ Minimize data collection
- ✅ Delete data when no longer needed

### Compliance
- ✅ Follow HIPAA if handling medical data
- ✅ Comply with GDPR for EU users
- ✅ Follow Apple's App Store guidelines
- ✅ Implement user data deletion

---

## Security Checklist

### Pre-Release
- [ ] All sensitive data stored in Keychain
- [ ] No hardcoded secrets
- [ ] HTTPS enforced for network requests
- [ ] Health data permissions requested properly
- [ ] Location tracking minimized
- [ ] Input validation implemented
- [ ] Authentication required for sensitive operations
- [ ] Privacy policy provided

### Health Data Specific
- [ ] HealthKit permissions requested with clear explanations
- [ ] Health data not stored outside HealthKit
- [ ] Workout data validated before saving
- [ ] User can delete health data

### Communication
- [ ] Watch Connectivity messages validated
- [ ] Sensitive data encrypted before transmission
- [ ] Message handlers check authentication
- [ ] Rate limiting implemented (if needed)

---

## Resources

- [Apple Watch App Security Guide](https://developer.apple.com/documentation/watchos-apps/keeping-your-watchos-content-secure)
- [HealthKit Privacy Guidelines](https://developer.apple.com/documentation/healthkit/protecting_user_privacy)
- [watchOS Security White Paper](https://support.apple.com/guide/security/welcome/web)
