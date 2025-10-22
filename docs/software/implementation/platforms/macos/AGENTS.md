# macOS Platform Guidelines

macOS-specific instructions for AI coding agents working on Mac desktop applications.

**Philosophy**: Build native, high-quality Mac applications that feel at home on macOS, leveraging the platform's unique features while maintaining clean architecture.

---

## Quick Reference

### Core Principles
- ✅ Follow macOS Human Interface Guidelines
- ✅ Use native frameworks (SwiftUI, AppKit)
- ✅ Support macOS-specific features (menu bar, Touch Bar, keyboard shortcuts)
- ✅ Design for window management and multiple displays
- ✅ Support Dark Mode and system appearance
- ✅ Implement proper app lifecycle and state restoration
- ❌ Avoid iOS-style navigation patterns
- ❌ Avoid hardcoding UI dimensions

### UI Framework Selection
- ✅ SwiftUI for modern Mac apps (macOS 11+)
- ✅ AppKit for complex, traditional Mac apps
- ✅ Combine SwiftUI + AppKit when needed
- ✅ Use NSViewRepresentable for bridging AppKit to SwiftUI

### macOS-Specific Features
- ✅ Menu bar with keyboard shortcuts
- ✅ Touch Bar support (if applicable)
- ✅ Toolbar customization
- ✅ Multiple windows and tabs
- ✅ Split views and popovers
- ✅ Document-based apps
- ✅ System integration (Spotlight, Quick Look, Services)

### Architecture Patterns
- ✅ MVVM for SwiftUI applications
- ✅ MVC or MVVM for AppKit applications
- ✅ Coordinator pattern for complex navigation
- ✅ Document architecture for document-based apps
- ❌ Avoid massive view controllers

---

## Detailed Guidelines

For comprehensive macOS best practices, see:
- **[Architecture Patterns](./architecture.md)**: MVVM, Document architecture, Coordinator
- **[Security & Privacy](./security.md)**: Sandboxing, Keychain, Code signing

---

## Framework Selection Guide

### UI Frameworks
| Framework | Use Case | macOS Version | Notes |
|-----------|----------|---------------|-------|
| **SwiftUI** | Modern Mac apps | macOS 11+ | Declarative, cross-platform |
| **AppKit** | Traditional Mac apps | All versions | Full control, mature |
| **Catalyst** | iPad → Mac | macOS 10.15+ | Quick port, limited features |

### macOS-Specific APIs
| API | Use Case | Notes |
|-----|----------|-------|
| **NSMenu** | Menu bar menus | Essential for Mac apps |
| **NSToolbar** | Window toolbars | Customizable by users |
| **NSTouchBar** | Touch Bar support | MacBook Pro with Touch Bar |
| **NSDocument** | Document-based apps | File management, undo/redo |
| **NSWindowController** | Window management | Multiple windows |
| **NSViewController** | View management | Container for views |

---

## SwiftUI for macOS

### Window Management

```swift
@main
struct MyMacApp: App {
    var body: some Scene {
        // Main window
        WindowGroup {
            ContentView()
        }
        .commands {
            // Custom menu commands
            CommandMenu("My Menu") {
                Button("Do Something") {
                    doSomething()
                }
                .keyboardShortcut("D", modifiers: [.command, .shift])
            }
        }

        // Settings window
        Settings {
            SettingsView()
        }

        // Additional window
        WindowGroup("Inspector") {
            InspectorView()
        }
        .defaultSize(width: 300, height: 500)
    }
}
```

### Menu Bar Commands

```swift
struct ContentView: View {
    var body: some View {
        Text("Hello, Mac!")
            .frame(minWidth: 400, minHeight: 300)
            .toolbar {
                ToolbarItem(placement: .navigation) {
                    Button(action: goBack) {
                        Label("Back", systemImage: "chevron.left")
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    Button(action: performAction) {
                        Label("Action", systemImage: "star")
                    }
                }
            }
    }
}

// Custom commands
struct MyCommands: Commands {
    var body: some Commands {
        CommandMenu("Edit") {
            Button("Copy") {
                // Copy action
            }
            .keyboardShortcut("c")

            Button("Paste") {
                // Paste action
            }
            .keyboardShortcut("v")
        }

        CommandGroup(replacing: .newItem) {
            Button("New Document") {
                // Create new document
            }
            .keyboardShortcut("n")
        }
    }
}
```

---

## AppKit Patterns

### NSViewController

```swift
class MainViewController: NSViewController {
    private let viewModel: MainViewModel

    init(viewModel: MainViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = NSView()
        view.wantsLayer = true
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        bindViewModel()
    }

    private func setupUI() {
        // Setup UI components
    }

    private func bindViewModel() {
        // Bind to ViewModel
    }
}
```

### NSWindowController

```swift
class MainWindowController: NSWindowController {
    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.title = "My Mac App"

        self.init(window: window)

        let viewController = MainViewController(viewModel: MainViewModel())
        window.contentViewController = viewController
    }

    override func windowDidLoad() {
        super.windowDidLoad()

        // Configure window
        window?.minSize = NSSize(width: 400, height: 300)
        window?.setFrameAutosaveName("MainWindow")
    }
}
```

### NSMenu

```swift
class MenuManager {
    static func createMainMenu() -> NSMenu {
        let mainMenu = NSMenu()

        // App menu
        let appMenu = NSMenuItem()
        appMenu.submenu = NSMenu()
        appMenu.submenu?.addItem(NSMenuItem(
            title: "About MyApp",
            action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)),
            keyEquivalent: ""
        ))
        appMenu.submenu?.addItem(NSMenuItem.separator())
        appMenu.submenu?.addItem(NSMenuItem(
            title: "Quit MyApp",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        ))
        mainMenu.addItem(appMenu)

        // File menu
        let fileMenu = NSMenuItem()
        fileMenu.submenu = NSMenu(title: "File")
        fileMenu.submenu?.addItem(NSMenuItem(
            title: "New",
            action: #selector(NSDocumentController.newDocument(_:)),
            keyEquivalent: "n"
        ))
        fileMenu.submenu?.addItem(NSMenuItem(
            title: "Open...",
            action: #selector(NSDocumentController.openDocument(_:)),
            keyEquivalent: "o"
        ))
        mainMenu.addItem(fileMenu)

        return mainMenu
    }
}

// In AppDelegate
func applicationDidFinishLaunching(_ notification: Notification) {
    NSApp.mainMenu = MenuManager.createMainMenu()
}
```

---

## Document-Based Applications

### NSDocument

```swift
class MyDocument: NSDocument {
    var content: String = ""

    override class var autosavesInPlace: Bool {
        return true
    }

    override func makeWindowControllers() {
        let storyboard = NSStoryboard(name: "Main", bundle: nil)
        if let windowController = storyboard.instantiateController(
            withIdentifier: "Document Window Controller"
        ) as? NSWindowController {
            addWindowController(windowController)

            if let viewController = windowController.contentViewController as? DocumentViewController {
                viewController.document = self
            }
        }
    }

    override func data(ofType typeName: String) throws -> Data {
        guard let data = content.data(using: .utf8) else {
            throw NSError(domain: NSOSStatusErrorDomain, code: unimpErr, userInfo: nil)
        }
        return data
    }

    override func read(from data: Data, ofType typeName: String) throws {
        guard let string = String(data: data, encoding: .utf8) else {
            throw NSError(domain: NSOSStatusErrorDomain, code: unimpErr, userInfo: nil)
        }
        content = string
    }
}
```

---

## Toolbar

### NSToolbar

```swift
class MainWindowController: NSWindowController, NSToolbarDelegate {
    private let toolbarIdentifier = NSToolbar.Identifier("MainToolbar")
    private let sidebarItemIdentifier = NSToolbarItem.Identifier("SidebarItem")
    private let addItemIdentifier = NSToolbarItem.Identifier("AddItem")

    override func windowDidLoad() {
        super.windowDidLoad()

        let toolbar = NSToolbar(identifier: toolbarIdentifier)
        toolbar.delegate = self
        toolbar.displayMode = .iconOnly
        window?.toolbar = toolbar
    }

    func toolbar(
        _ toolbar: NSToolbar,
        itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier,
        willBeInsertedIntoToolbar flag: Bool
    ) -> NSToolbarItem? {
        switch itemIdentifier {
        case sidebarItemIdentifier:
            let item = NSToolbarItem(itemIdentifier: itemIdentifier)
            item.label = "Sidebar"
            item.image = NSImage(systemSymbolName: "sidebar.left", accessibilityDescription: "Toggle Sidebar")
            item.action = #selector(toggleSidebar)
            return item

        case addItemIdentifier:
            let item = NSToolbarItem(itemIdentifier: itemIdentifier)
            item.label = "Add"
            item.image = NSImage(systemSymbolName: "plus", accessibilityDescription: "Add Item")
            item.action = #selector(addItem)
            return item

        default:
            return nil
        }
    }

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [sidebarItemIdentifier, addItemIdentifier, .flexibleSpace, .space]
    }

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [sidebarItemIdentifier, .flexibleSpace, addItemIdentifier]
    }

    @objc func toggleSidebar() {
        // Toggle sidebar
    }

    @objc func addItem() {
        // Add item
    }
}
```

---

## Split View

### NSSplitViewController

```swift
class MainSplitViewController: NSSplitViewController {
    private let sidebarViewController = SidebarViewController()
    private let contentViewController = ContentViewController()

    override func viewDidLoad() {
        super.viewDidLoad()

        // Sidebar
        let sidebarItem = NSSplitViewItem(viewController: sidebarViewController)
        sidebarItem.canCollapse = true
        sidebarItem.minimumThickness = 200
        sidebarItem.maximumThickness = 300
        addSplitViewItem(sidebarItem)

        // Content
        let contentItem = NSSplitViewItem(viewController: contentViewController)
        addSplitViewItem(contentItem)
    }
}
```

---

## App Sandbox

### Entitlements

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <!-- Enable App Sandbox -->
    <key>com.apple.security.app-sandbox</key>
    <true/>

    <!-- Network access -->
    <key>com.apple.security.network.client</key>
    <true/>

    <!-- File access (user selected) -->
    <key>com.apple.security.files.user-selected.read-write</key>
    <true/>

    <!-- Downloads folder -->
    <key>com.apple.security.files.downloads.read-write</key>
    <true/>

    <!-- Camera -->
    <key>com.apple.security.device.camera</key>
    <true/>

    <!-- Microphone -->
    <key>com.apple.security.device.audio-input</key>
    <true/>
</dict>
</plist>
```

---

## System Integration

### Spotlight Integration

```swift
// Make content searchable
import CoreSpotlight
import MobileCoreServices

func indexItem(title: String, description: String, uniqueIdentifier: String) {
    let attributeSet = CSSearchableItemAttributeSet(contentType: .text)
    attributeSet.title = title
    attributeSet.contentDescription = description

    let item = CSSearchableItem(
        uniqueIdentifier: uniqueIdentifier,
        domainIdentifier: "com.example.myapp",
        attributeSet: attributeSet
    )

    CSSearchableIndex.default().indexSearchableItems([item]) { error in
        if let error = error {
            print("Indexing error: \(error)")
        }
    }
}
```

### Quick Look Support

```swift
import Quartz

class PreviewProvider: QLPreviewProvider, QLPreviewingController {
    func providePreview(for request: QLFilePreviewRequest) async throws -> QLPreviewReply {
        let contentType = UTType.plainText
        let reply = QLPreviewReply(
            dataOfContentType: contentType,
            contentSize: CGSize(width: 800, height: 600)
        ) { (replyToUpdate) in
            let data = try Data(contentsOf: request.fileURL)
            replyToUpdate.stringEncoding = .utf8
            return data
        }
        return reply
    }
}
```

---

## macOS-Specific UI Patterns

### Preferences Window

```swift
struct PreferencesView: View {
    var body: some View {
        TabView {
            GeneralPreferencesView()
                .tabItem {
                    Label("General", systemImage: "gearshape")
                }

            AdvancedPreferencesView()
                .tabItem {
                    Label("Advanced", systemImage: "slider.horizontal.3")
                }
        }
        .frame(width: 500, height: 400)
    }
}
```

### Popover

```swift
class PopoverManager {
    private var popover: NSPopover?

    func show(from button: NSButton) {
        let popover = NSPopover()
        popover.contentViewController = NSHostingController(rootView: PopoverContentView())
        popover.behavior = .transient
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        self.popover = popover
    }
}
```

---

## Keyboard Shortcuts

### Custom Keyboard Shortcuts

```swift
// SwiftUI
struct ContentView: View {
    var body: some View {
        Text("Hello, Mac!")
            .onAppear {
                NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                    if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "k" {
                        // Handle Command+K
                        return nil  // Event handled
                    }
                    return event
                }
            }
    }
}

// AppKit
override func keyDown(with event: NSEvent) {
    if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "k" {
        // Handle Command+K
        return
    }
    super.keyDown(with: event)
}
```

---

## Common Anti-Patterns

### ❌ iOS-Style Navigation

```swift
// Bad: iOS navigation on Mac
NavigationView {
    List {
        NavigationLink("Item 1", destination: DetailView())
    }
}

// Good: Mac-style split view
HSplitView {
    SidebarView()
    DetailView()
}
```

### ❌ Ignoring Menu Bar

```swift
// Bad: No menu bar integration

// Good: Full menu bar with shortcuts
.commands {
    CommandMenu("Edit") {
        Button("Copy") { copy() }
            .keyboardShortcut("c")
        Button("Paste") { paste() }
            .keyboardShortcut("v")
    }
}
```

---

## Integration with General Principles

macOS code should follow:
- **[Code Quality Principles](../../general/code-quality.md)**: Explicitness, locality, fail-fast
- **[Unix Philosophy](../../../../principles/unix-philosophy.md)**: Single responsibility, composability
- **[Testing Strategy](../../../../testing/strategy.md)**: Unit tests, UI tests

---

## When to Escalate

Consult human developers for:
- **Mac App Store submission**: Review guidelines, sandboxing requirements
- **Code signing complexity**: Developer ID, notarization
- **Performance optimization**: Instruments profiling on macOS
- **Cross-platform decisions**: Mac-specific vs iOS-shared code
- **System integration**: Deep system features, private APIs
- **Accessibility**: VoiceOver optimization for macOS
