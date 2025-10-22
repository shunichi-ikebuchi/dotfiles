# Apple Platform Security & Privacy

Security and privacy best practices for macOS and iOS applications.

---

## Data Protection

### Keychain

**Secure storage for sensitive data**

```swift
import Security

enum KeychainError: Error {
    case duplicateItem
    case itemNotFound
    case invalidData
    case unknown(OSStatus)
}

class KeychainManager {
    static let shared = KeychainManager()

    private init() {}

    // MARK: - Save

    func save(_ data: Data, for key: String, accessible: CFString = kSecAttrAccessibleWhenUnlocked) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: accessible
        ]

        let status = SecItemAdd(query as CFDictionary, nil)

        if status == errSecDuplicateItem {
            // Update existing item
            try update(data, for: key)
        } else if status != errSecSuccess {
            throw KeychainError.unknown(status)
        }
    }

    func save(_ string: String, for key: String) throws {
        guard let data = string.data(using: .utf8) else {
            throw KeychainError.invalidData
        }
        try save(data, for: key)
    }

    // MARK: - Retrieve

    func retrieve(for key: String) throws -> Data {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess else {
            if status == errSecItemNotFound {
                throw KeychainError.itemNotFound
            }
            throw KeychainError.unknown(status)
        }

        guard let data = result as? Data else {
            throw KeychainError.invalidData
        }

        return data
    }

    func retrieveString(for key: String) throws -> String {
        let data = try retrieve(for: key)
        guard let string = String(data: data, encoding: .utf8) else {
            throw KeychainError.invalidData
        }
        return string
    }

    // MARK: - Update

    private func update(_ data: Data, for key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]

        let attributes: [String: Any] = [
            kSecValueData as String: data
        ]

        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)

        guard status == errSecSuccess else {
            throw KeychainError.unknown(status)
        }
    }

    // MARK: - Delete

    func delete(for key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]

        let status = SecItemDelete(query as CFDictionary)

        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unknown(status)
        }
    }

    // MARK: - Delete All

    func deleteAll() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword
        ]

        let status = SecItemDelete(query as CFDictionary)

        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unknown(status)
        }
    }
}

// Usage
let keychain = KeychainManager.shared

// Save
try keychain.save("mySecretToken", for: "authToken")

// Retrieve
let token = try keychain.retrieveString(for: "authToken")

// Delete
try keychain.delete(for: "authToken")
```

### Keychain Accessibility Options

```swift
// Available when device is unlocked (default)
kSecAttrAccessibleWhenUnlocked

// Available after first unlock (recommended for background tasks)
kSecAttrAccessibleAfterFirstUnlock

// Available when device is unlocked, not backed up to iCloud
kSecAttrAccessibleWhenUnlockedThisDeviceOnly

// Available when passcode is set (most secure)
kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly
```

---

## App Transport Security (ATS)

### Configuration

**Info.plist configuration**

```xml
<!-- Allow only HTTPS (recommended) -->
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <false/>
</dict>

<!-- Exception for specific domain (if needed) -->
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSExceptionDomains</key>
    <dict>
        <key>example.com</key>
        <dict>
            <key>NSExceptionAllowsInsecureHTTPLoads</key>
            <true/>
            <key>NSIncludesSubdomains</key>
            <true/>
        </dict>
    </dict>
</dict>

<!-- Local network (development only) -->
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsLocalNetworking</key>
    <true/>
</dict>
```

### Best Practices

- ✅ Use HTTPS for all network requests
- ✅ Use TLS 1.2 or higher
- ✅ Use forward secrecy ciphers
- ❌ Don't disable ATS in production
- ❌ Don't use `NSAllowsArbitraryLoads`

---

## Certificate Pinning

### Implementation

```swift
import Foundation

class CertificatePinningDelegate: NSObject, URLSessionDelegate {
    private let pinnedCertificates: [Data]

    init(pinnedCertificates: [Data]) {
        self.pinnedCertificates = pinnedCertificates
    }

    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        guard let serverTrust = challenge.protectionSpace.serverTrust else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        // Evaluate server trust
        var secResult = SecTrustResultType.invalid
        let status = SecTrustEvaluate(serverTrust, &secResult)

        guard status == errSecSuccess else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        // Get server certificate
        guard let serverCertificate = SecTrustGetCertificateAtIndex(serverTrust, 0) else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        let serverCertificateData = SecCertificateCopyData(serverCertificate) as Data

        // Check if certificate matches any pinned certificate
        for pinnedCertificate in pinnedCertificates {
            if serverCertificateData == pinnedCertificate {
                completionHandler(.useCredential, URLCredential(trust: serverTrust))
                return
            }
        }

        // Certificate not pinned
        completionHandler(.cancelAuthenticationChallenge, nil)
    }
}

// Usage
let certificateData = // Load certificate from bundle
let session = URLSession(
    configuration: .default,
    delegate: CertificatePinningDelegate(pinnedCertificates: [certificateData]),
    delegateQueue: nil
)
```

---

## Privacy Permissions

### Requesting Permissions

```swift
import AVFoundation
import Photos
import CoreLocation

// Camera
func requestCameraPermission() async -> Bool {
    await AVCaptureDevice.requestAccess(for: .video)
}

// Photo Library
func requestPhotoLibraryPermission() async -> PHAuthorizationStatus {
    await PHPhotoLibrary.requestAuthorization(for: .readWrite)
}

// Location
class LocationManager: NSObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()

    override init() {
        super.init()
        locationManager.delegate = self
    }

    func requestLocationPermission() {
        locationManager.requestWhenInUseAuthorization()
        // or
        locationManager.requestAlwaysAuthorization()
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
            // Not yet determined
            break
        @unknown default:
            break
        }
    }
}
```

### Info.plist Privacy Descriptions

```xml
<!-- Camera -->
<key>NSCameraUsageDescription</key>
<string>We need access to your camera to take photos.</string>

<!-- Photo Library -->
<key>NSPhotoLibraryUsageDescription</key>
<string>We need access to your photos to select images.</string>
<key>NSPhotoLibraryAddUsageDescription</key>
<string>We need permission to save photos.</string>

<!-- Location (When In Use) -->
<key>NSLocationWhenInUseUsageDescription</key>
<string>We need your location to show nearby places.</string>

<!-- Location (Always) -->
<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>We need your location to provide location-based notifications.</string>

<!-- Contacts -->
<key>NSContactsUsageDescription</key>
<string>We need access to your contacts to invite friends.</string>

<!-- Microphone -->
<key>NSMicrophoneUsageDescription</key>
<string>We need access to your microphone for voice recording.</string>

<!-- Bluetooth -->
<key>NSBluetoothAlwaysUsageDescription</key>
<string>We use Bluetooth to connect to nearby devices.</string>

<!-- Tracking (iOS 14.5+) -->
<key>NSUserTrackingUsageDescription</key>
<string>We use tracking to provide personalized ads.</string>
```

---

## Privacy Manifest (iOS 17+)

### PrivacyInfo.xcprivacy

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>NSPrivacyTracking</key>
    <false/>
    <key>NSPrivacyTrackingDomains</key>
    <array/>
    <key>NSPrivacyCollectedDataTypes</key>
    <array>
        <dict>
            <key>NSPrivacyCollectedDataType</key>
            <string>NSPrivacyCollectedDataTypeEmailAddress</string>
            <key>NSPrivacyCollectedDataTypeLinked</key>
            <true/>
            <key>NSPrivacyCollectedDataTypeTracking</key>
            <false/>
            <key>NSPrivacyCollectedDataTypePurposes</key>
            <array>
                <string>NSPrivacyCollectedDataTypePurposeAppFunctionality</string>
            </array>
        </dict>
    </array>
    <key>NSPrivacyAccessedAPITypes</key>
    <array>
        <dict>
            <key>NSPrivacyAccessedAPIType</key>
            <string>NSPrivacyAccessedAPICategoryUserDefaults</string>
            <key>NSPrivacyAccessedAPITypeReasons</key>
            <array>
                <string>CA92.1</string>
            </array>
        </dict>
    </array>
</dict>
</plist>
```

---

## Secure Coding Practices

### Input Validation

```swift
// Good: Validate user input
func validateEmail(_ email: String) -> Bool {
    let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
    let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
    return emailPredicate.evaluate(with: email)
}

func sanitizeUsername(_ username: String) -> String? {
    let allowed = CharacterSet.alphanumerics
    guard username.unicodeScalars.allSatisfy({ allowed.contains($0) }) else {
        return nil
    }
    return username
}
```

### SQL Injection Prevention

```swift
// Good: Use parameterized queries
func getUser(withID id: String) throws -> User? {
    let query = "SELECT * FROM users WHERE id = ?"
    let statement = try database.prepare(query)
    try statement.bind(id)
    return try statement.step()
}

// Bad: String interpolation (SQL injection risk)
func getUserBad(withID id: String) throws -> User? {
    let query = "SELECT * FROM users WHERE id = '\(id)'"  // Vulnerable!
    return try database.execute(query)
}
```

### Avoid Hardcoded Secrets

```swift
// Bad: Hardcoded API key
let apiKey = "sk_live_abc123xyz"  // Don't do this!

// Good: Load from configuration
struct APIConfig {
    static var apiKey: String {
        guard let key = Bundle.main.object(forInfoDictionaryKey: "API_KEY") as? String else {
            fatalError("API key not found in configuration")
        }
        return key
    }
}

// Better: Load from Keychain or remote config
func getAPIKey() async throws -> String {
    try KeychainManager.shared.retrieveString(for: "apiKey")
}
```

---

## Biometric Authentication

### Face ID / Touch ID

```swift
import LocalAuthentication

class BiometricAuthManager {
    func canUseBiometrics() -> Bool {
        let context = LAContext()
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }

    func authenticateWithBiometrics() async throws -> Bool {
        let context = LAContext()
        context.localizedCancelTitle = "Cancel"

        let reason = "Authenticate to access your account"

        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: reason
            )
            return success
        } catch let error as LAError {
            switch error.code {
            case .authenticationFailed:
                throw BiometricError.authenticationFailed
            case .userCancel:
                throw BiometricError.userCancelled
            case .userFallback:
                throw BiometricError.userFallback
            case .biometryNotAvailable:
                throw BiometricError.notAvailable
            case .biometryNotEnrolled:
                throw BiometricError.notEnrolled
            case .biometryLockout:
                throw BiometricError.lockout
            default:
                throw BiometricError.unknown
            }
        }
    }
}

enum BiometricError: Error {
    case authenticationFailed
    case userCancelled
    case userFallback
    case notAvailable
    case notEnrolled
    case lockout
    case unknown
}

// Info.plist entry
// <key>NSFaceIDUsageDescription</key>
// <string>We use Face ID to secure your account.</string>
```

---

## Data Encryption

### Encrypt Data at Rest

```swift
import CryptoKit

class EncryptionManager {
    // Generate encryption key
    static func generateKey() -> SymmetricKey {
        SymmetricKey(size: .bits256)
    }

    // Encrypt data
    static func encrypt(_ data: Data, using key: SymmetricKey) throws -> Data {
        let sealedBox = try AES.GCM.seal(data, using: key)
        return sealedBox.combined!
    }

    // Decrypt data
    static func decrypt(_ data: Data, using key: SymmetricKey) throws -> Data {
        let sealedBox = try AES.GCM.SealedBox(combined: data)
        return try AES.GCM.open(sealedBox, using: key)
    }
}

// Usage
let key = EncryptionManager.generateKey()
let plaintext = "Sensitive data".data(using: .utf8)!

// Encrypt
let encrypted = try EncryptionManager.encrypt(plaintext, using: key)

// Store key in Keychain
let keyData = key.withUnsafeBytes { Data($0) }
try KeychainManager.shared.save(keyData, for: "encryptionKey")

// Later: Retrieve and decrypt
let storedKeyData = try KeychainManager.shared.retrieve(for: "encryptionKey")
let storedKey = SymmetricKey(data: storedKeyData)
let decrypted = try EncryptionManager.decrypt(encrypted, using: storedKey)
```

---

## Secure Network Communication

### HTTPS Only

```swift
class SecureNetworkManager {
    private let session: URLSession

    init() {
        let configuration = URLSessionConfiguration.default
        configuration.tlsMinimumSupportedProtocolVersion = .TLSv12

        self.session = URLSession(configuration: configuration)
    }

    func fetch(from url: URL) async throws -> Data {
        // Ensure HTTPS
        guard url.scheme == "https" else {
            throw NetworkError.insecureConnection
        }

        let (data, _) = try await session.data(from: url)
        return data
    }
}

enum NetworkError: Error {
    case insecureConnection
}
```

---

## Code Signing & Provisioning

### Best Practices

- ✅ Use automatic code signing in development
- ✅ Use manual signing for production builds
- ✅ Protect provisioning profiles and certificates
- ✅ Rotate certificates before expiration
- ✅ Use App Store distribution certificate for releases
- ❌ Don't commit certificates/profiles to version control
- ❌ Don't share distribution certificates

---

## Jailbreak Detection (Optional)

**Note**: This is security through obscurity and can be bypassed.

```swift
class JailbreakDetector {
    static func isJailbroken() -> Bool {
        // Check for common jailbreak files
        let suspiciousFilePaths = [
            "/Applications/Cydia.app",
            "/Library/MobileSubstrate/MobileSubstrate.dylib",
            "/bin/bash",
            "/usr/sbin/sshd",
            "/etc/apt",
            "/private/var/lib/apt/"
        ]

        for path in suspiciousFilePaths {
            if FileManager.default.fileExists(atPath: path) {
                return true
            }
        }

        // Check if can write to system directory
        let testPath = "/private/jailbreak.txt"
        do {
            try "test".write(toFile: testPath, atomically: true, encoding: .utf8)
            try FileManager.default.removeItem(atPath: testPath)
            return true
        } catch {
            // Cannot write, not jailbroken
        }

        return false
    }
}
```

---

## Security Checklist

### Pre-Release
- [ ] All sensitive data stored in Keychain
- [ ] No hardcoded secrets in code
- [ ] HTTPS enforced for all network requests
- [ ] Certificate pinning implemented (if needed)
- [ ] Input validation on all user inputs
- [ ] Privacy permissions properly requested
- [ ] Privacy manifest created (iOS 17+)
- [ ] Code obfuscation applied (if needed)
- [ ] Third-party libraries audited for security
- [ ] Security testing performed

### Compliance
- [ ] GDPR compliance (if applicable)
- [ ] COPPA compliance (if targeting children)
- [ ] Privacy policy updated
- [ ] Terms of service updated
- [ ] Data retention policy defined
- [ ] User data deletion mechanism implemented

---

## Resources

- [Apple Security Guide](https://support.apple.com/guide/security/welcome/web)
- [App Store Review Guidelines - Privacy](https://developer.apple.com/app-store/review/guidelines/#privacy)
- [OWASP Mobile Security](https://owasp.org/www-project-mobile-security/)
