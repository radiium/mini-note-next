import AppKit
import SwiftUI
import SwiftData
import os

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let appState = AppState()
    private var panelController: PanelController!
    private var statusItem: NSStatusItem!
    private var hotKeyObserver: (any NSObjectProtocol)?
    private let hotKeyManager = HotKeyManager()
    
    private lazy var modelContainer: ModelContainer = {
        let schema = Schema([Note.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            let alert = NSAlert()
            alert.messageText = String(localized: "error.db.open.title")
            alert.informativeText = error.localizedDescription
            alert.addButton(withTitle: String(localized: "action.quit"))
            os_log(.fault, "SwiftData ModelContainer init failed: %{public}@", error.localizedDescription)
            alert.runModal()
            NSApp.terminate(nil)
            fatalError("Unreachable — satisfies the compiler: NSApp.terminate does not return but is not marked @noreturn")
        }
    }()
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Skip all app setup when running under XCTest / Swift Testing to avoid
        // enforceSingleInstance() terminating the parallel test subprocesses.
        guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil else { return }
        enforceSingleInstance()
        NSApp.setActivationPolicy(.accessory)
        setupMainMenu()
        setupStatusItem()
        panelController = PanelController(
            appState: appState,
            statusItem: statusItem,
            modelContainer: modelContainer,
            onVisibilityChanged: { [weak self] isOpen in self?.updateStatusIcon(isOpen: isOpen) }
        )
        setupHotKey()
        hotKeyObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: nil,
            queue: .main
            // MainActor.assumeIsolated: queue .main guarantees execution on the main thread at runtime,
            // but the compiler cannot verify this statically from a nonisolated closure.
        ) { [weak self] _ in MainActor.assumeIsolated {
            self?.updateHotKey()
            self?.panelController.updatePanelSize()
        } }
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        if let o = hotKeyObserver { NotificationCenter.default.removeObserver(o); hotKeyObserver = nil }
        panelController.invalidate()
        cleanupEmptyNotes()
    }
    
    // MARK: - Main menu
    
    private func setupMainMenu() {
        let mainMenu = NSMenu()
        
        // App menu (index 0 is always the app name menu on macOS)
        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(NSMenuItem(title: String(localized: "menu.quit_app"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)
        
        // Edit menu — standard items routed through the responder chain to NSTextView
        let editMenuItem = NSMenuItem()
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Undo",       action: Selector(("undo:")),                 keyEquivalent: "z")
        editMenu.addItem(withTitle: "Redo",       action: Selector(("redo:")),                 keyEquivalent: "Z")
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: "Cut",        action: #selector(NSText.cut(_:)),           keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy",       action: #selector(NSText.copy(_:)),          keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste",      action: #selector(NSText.paste(_:)),         keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)),     keyEquivalent: "a")
        editMenu.addItem(.separator())
        
        // Find submenu — key equivalents displayed in the menu bar for discoverability;
        // actual handling is done by the per-view local monitors so they work regardless of focus.
        let findSubmenuItem = NSMenuItem(title: "Find", action: nil, keyEquivalent: "")
        let findMenu = NSMenu(title: "Find")
        let findShowItem = findMenu.addItem(withTitle: "Find…",         action: #selector(NSTextView.performFindPanelAction(_:)), keyEquivalent: "f")
        findShowItem.tag = 1
        let findNextItem = findMenu.addItem(withTitle: "Find Next",     action: #selector(NSTextView.performFindPanelAction(_:)), keyEquivalent: "g")
        findNextItem.tag = 2
        let findPrevItem = findMenu.addItem(withTitle: "Find Previous", action: #selector(NSTextView.performFindPanelAction(_:)), keyEquivalent: "G")
        findPrevItem.tag = 3
        findSubmenuItem.submenu = findMenu
        editMenu.addItem(findSubmenuItem)
        
        editMenuItem.submenu = editMenu
        mainMenu.addItem(editMenuItem)
        
        NSApp.mainMenu = mainMenu
    }
    
    // MARK: - Global hotkey
    
    private func setupHotKey() {
        hotKeyManager.action = { [weak self] in self?.panelController.toggle() }
        updateHotKey()
    }
    
    private func updateHotKey() {
        let enabled = UserDefaults.standard.object(forKey: PreferenceKey.hotKeyEnabled) as? Bool ?? false
        enabled ? hotKeyManager.register() : hotKeyManager.unregister()
    }
    
    // MARK: - Single instance
    
    private func enforceSingleInstance() {
        guard let bundleID = Bundle.main.bundleIdentifier else { return }
        let isAlreadyRunning = NSRunningApplication
            .runningApplications(withBundleIdentifier: bundleID)
            .contains { $0 != .current }
        // Quit the new instance rather than killing the existing one,
        // so the running instance keeps its SwiftData store open safely.
        if isAlreadyRunning { NSApp.terminate(nil) }
    }
    
    // MARK: - Cleanup
    
    private func cleanupEmptyNotes() {
        let context = modelContainer.mainContext
        guard let notes = try? context.fetch(FetchDescriptor<Note>()) else { return }
        for note in notes where note.isEmpty {
            context.delete(note)
        }
        do {
            try context.save()
        } catch {
            os_log(.error, "cleanupEmptyNotes save failed: %{public}@", error.localizedDescription)
        }
    }
    
    // MARK: - Status item
    
    private static let statusIconConfig = NSImage.SymbolConfiguration(pointSize: 14, weight: .semibold)
    
    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.imageScaling = .scaleNone
        statusItem.button?.target = self
        statusItem.button?.action = #selector(handleStatusItemClick)
        statusItem.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        statusItem.button?.setAccessibilityLabel(String(localized: "status.item.accessibility"))
        updateStatusIcon(isOpen: false)
    }
    
    private func updateStatusIcon(isOpen: Bool) {
        let name = isOpen ? "long.text.page.and.pencil.fill" : "long.text.page.and.pencil"
        statusItem.button?.image = NSImage(systemSymbolName: name, accessibilityDescription: nil)?
            .withSymbolConfiguration(Self.statusIconConfig)
    }
    
    @objc private func handleStatusItemClick() {
        guard let event = NSApp.currentEvent else { return }
        if event.type == .rightMouseUp {
            showContextMenu()
        } else {
            panelController.toggle()
        }
    }
    
    private func showContextMenu() {
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: String(localized: "menu.about"), action: #selector(showAboutPanel), keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: String(localized: "menu.preferences"), action: #selector(openSettings), keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: String(localized: "menu.export_notes"), action: #selector(exportNotes), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: String(localized: "menu.import_notes"), action: #selector(importNotes), keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: String(localized: "menu.quit_app"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: ""))
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }
    
    @objc private func showAboutPanel() {
        NSApp.activate()
        NSApp.orderFrontStandardAboutPanel(nil)
    }
    
    @objc private func exportNotes() {
        let notes = (try? modelContainer.mainContext.fetch(FetchDescriptor<Note>())) ?? []
        NoteIOService.exportNotes(notes)
    }
    
    @objc private func importNotes() {
        NoteIOService.importNotes(into: modelContainer.mainContext)
    }
    
    @objc private func openSettings() {
        // AppDelegate has no access to SwiftUI's @Environment(\.openWindow).
        // NotificationCenter is used to delegate window opening to ContentView, which has the environment.
        NotificationCenter.default.post(name: .openSettings, object: nil)
        NSApp.activate()
    }
}
