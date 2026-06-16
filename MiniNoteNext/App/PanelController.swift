import AppKit
import Combine
import SwiftUI
import SwiftData

// Borderless NSPanels cannot become key by default, which blocks all keyboard input.
// canBecomeMain is dynamic so it can be enabled when the panel acts as a regular window.
private final class KeyablePanel: NSPanel {
    weak var appState: AppState?
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { appState?.isWindowMode ?? false }
    
    // SwiftUI's NSHostingView does not propagate standard text-editing key equivalents
    // (copy/paste/cut/select-all/undo) through the AppKit responder chain when hosted
    // inside a borderless panel. Intercept them here and forward directly to the focused
    // NSText. Uses charactersIgnoringModifiers (not keyCode) for keyboard-layout independence
    // (e.g. AZERTY Cmd+Z has keyCode 13 which is the QWERTY W position).
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        let mods = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard (mods == .command || mods == [.command, .shift]),
              event.type == .keyDown else {
            return super.performKeyEquivalent(with: event)
        }
        let target: NSText? = (firstResponder as? NSText)
        ?? contentView?.firstDescendant(ofType: NSText.self)
        guard let target,
              let char = event.charactersIgnoringModifiers?.lowercased() else {
            return super.performKeyEquivalent(with: event)
        }
        if mods == .command {
            switch char {
            case "c":  target.copy(nil);              return true
            case "v":  target.paste(nil);             return true
            case "x":  target.cut(nil);               return true
            case "a":  target.selectAll(nil);         return true
            case "z":  target.undoManager?.undo();    return true
            default:   return super.performKeyEquivalent(with: event)
            }
        }
        if mods == [.command, .shift], char == "z" {
            target.undoManager?.redo()
            return true
        }
        return super.performKeyEquivalent(with: event)
    }
}

private extension NSView {
    func firstDescendant<T: NSView>(ofType type: T.Type) -> T? {
        if let found = self as? T { return found }
        for sub in subviews {
            if let found = sub.firstDescendant(ofType: type) { return found }
        }
        return nil
    }
}

@MainActor
final class PanelController: NSObject, NSWindowDelegate {
    private let appState: AppState
    private let statusItem: NSStatusItem
    private let onVisibilityChanged: (Bool) -> Void
    private let panel: KeyablePanel
    private var eventMonitor: Any?
    private var cancellables: Set<AnyCancellable> = []
    
    init(
        appState: AppState,
        statusItem: NSStatusItem,
        modelContainer: ModelContainer,
        onVisibilityChanged: @escaping (Bool) -> Void
    ) {
        self.appState = appState
        self.statusItem = statusItem
        self.onVisibilityChanged = onVisibilityChanged
        
        let initialSize = PanelSizePreset.preferred
        let p = KeyablePanel(
            contentRect: NSRect(x: 0, y: 0, width: initialSize.width, height: initialSize.height),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        p.appState = appState
        p.level = .floating
        p.hidesOnDeactivate = false
        p.isReleasedWhenClosed = false
        p.hasShadow = true
        p.backgroundColor = .clear
        p.isOpaque = false
        // ignoresCycle: excludes the panel from Command-Tab to avoid disrupting the app switcher.
        // canJoinAllSpaces: keeps the panel visible across Space changes (Spaces / Mission Control).
        p.collectionBehavior = [.canJoinAllSpaces, .ignoresCycle]
        self.panel = p
        
        super.init()
        
        // Content view is set after super.init() so self can be captured in the toggleWindowMode closure.
        let root = ContentView()
            .environmentObject(appState)
            .environment(\.toggleWindowMode, { [weak self] in self?.toggleWindowMode() })
            .modelContainer(modelContainer)
        panel.contentView = NSHostingView(rootView: root)
        panel.delegate = self
        observeAppState()
    }
    
    func toggle() {
        panel.isVisible ? closePanel() : openPanel()
    }
    
    func invalidate() {
        cancellables.removeAll()
        stopEventMonitor()
    }
    
    // MARK: - AppState observation
    
    private func observeAppState() {
        appState.$isPinned
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] pinned in self?.handlePinnedChange(pinned) }
            .store(in: &cancellables)
    }
    
    private func handlePinnedChange(_ pinned: Bool) {
        if pinned || appState.isWindowMode {
            stopEventMonitor()
        } else if panel.isVisible {
            startEventMonitor()
        }
        if appState.isWindowMode {
            panel.level = pinned ? .floating : .normal
        }
    }
    
    // MARK: - Panel lifecycle
    
    private func openPanel() {
        if !appState.isWindowMode { positionPanel() }
        NSApp.activate()
        panel.makeKeyAndOrderFront(nil)
        if !appState.isWindowMode && !appState.isPinned { startEventMonitor() }
        onVisibilityChanged(true)
    }
    
    private func closePanel() {
        stopEventMonitor()
        panel.orderOut(nil)
        onVisibilityChanged(false)
    }
    
    // MARK: - Window mode
    
    private func toggleWindowMode() {
        applyWindowMode(!appState.isWindowMode)
    }
    
    private func applyWindowMode(_ windowMode: Bool, openAfter: Bool = true) {
        let wasVisible = panel.isVisible
        stopEventMonitor()
        
        if windowMode {
            panel.styleMask = [.titled, .closable, .miniaturizable, .resizable]
            panel.title = "MiniNote"
            panel.level = appState.isPinned ? .floating : .normal
            panel.collectionBehavior = []
            panel.backgroundColor = .windowBackgroundColor
            panel.isOpaque = true
            NSApp.setActivationPolicy(.regular)
            if !wasVisible { panel.center() }
            NSApp.activate()
            panel.makeKeyAndOrderFront(nil)
            onVisibilityChanged(true)
        } else {
            panel.styleMask = [.borderless]
            panel.level = .floating
            panel.collectionBehavior = [.canJoinAllSpaces, .ignoresCycle]
            panel.backgroundColor = .clear
            panel.isOpaque = false
            panel.setContentSize(preferredPanelSize)
            NSApp.setActivationPolicy(.accessory)
            if openAfter {
                positionPanel()
                NSApp.activate()
                panel.makeKeyAndOrderFront(nil)
                if !appState.isPinned { startEventMonitor() }
                onVisibilityChanged(true)
            } else {
                onVisibilityChanged(false)
            }
        }
        appState.setWindowMode(windowMode)
    }
    
    // MARK: - Panel size
    
    private var preferredPanelSize: NSSize { PanelSizePreset.preferred }
    
    func updatePanelSize() {
        guard !appState.isWindowMode else { return }
        let s = preferredPanelSize
        panel.setContentSize(s)
        if panel.isVisible { positionPanel() }
    }
    
    // MARK: - Click-outside monitor
    
    private func startEventMonitor() {
        guard eventMonitor == nil else { return }
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            guard let self, self.panel.isVisible else { return }
            if !self.panel.frame.contains(NSEvent.mouseLocation) {
                self.closePanel()
            }
        }
    }
    
    private func stopEventMonitor() {
        if let m = eventMonitor {
            NSEvent.removeMonitor(m)
            eventMonitor = nil
        }
    }
    
    // MARK: - Positioning
    
    private func positionPanel() {
        guard let button = statusItem.button,
              let buttonWindow = button.window else { return }
        let buttonRect = buttonWindow.convertToScreen(button.frame)
        var x = buttonRect.midX - panel.frame.width / 2
        var y = buttonRect.minY - panel.frame.height - 6
        
        let targetScreen = NSScreen.screens.first(where: { $0.frame.contains(buttonRect.origin) })
        ?? NSScreen.main
        ?? NSScreen.screens.first
        if let screen = targetScreen {
            let minX = screen.visibleFrame.minX
            let maxX = screen.visibleFrame.maxX - panel.frame.width
            x = min(max(x, minX), maxX)
            y = max(y, screen.visibleFrame.minY)
        }
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }
    
    // MARK: - NSWindowDelegate
    
    func windowDidBecomeKey(_ notification: Notification) {
        NSApp.activate()
    }
    
    func windowWillClose(_ notification: Notification) {
        guard appState.isWindowMode else { return }
        // Closed via × button in window mode: reset to popup without reopening.
        applyWindowMode(false, openAfter: false)
    }
}
