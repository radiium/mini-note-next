// Carbon has been deprecated since macOS 10.12 but remains the only API for registering
// a global keyboard shortcut without requiring the Accessibility permission.
import Carbon.HIToolbox

final class HotKeyManager {
    var action: (() -> Void)?
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    
    func register() {
        unregister()
        
        var eventSpec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        // InstallEventHandler requires an opaque C pointer: self is passed unretained because
        // HotKeyManager is guaranteed to outlive the handler (AppDelegate owns the instance).
        let userData = Unmanaged.passUnretained(self).toOpaque()
        let installStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            hotKeyEventCallback,
            1, &eventSpec, userData, &eventHandlerRef
        )
        guard installStatus == noErr else {
            print("HotKeyManager: InstallEventHandler failed (\(installStatus))")
            return
        }
        
        let hkID = EventHotKeyID(signature: 0x4D4E5854, id: 1) // "MNXT"
        let registerStatus = RegisterEventHotKey(
            UInt32(kVK_Space),
            UInt32(optionKey),
            hkID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
        if registerStatus != noErr {
            print("HotKeyManager: RegisterEventHotKey failed (\(registerStatus))")
            if let ref = eventHandlerRef { RemoveEventHandler(ref); eventHandlerRef = nil }
        }
    }
    
    func unregister() {
        if let ref = hotKeyRef       { UnregisterEventHotKey(ref); hotKeyRef = nil }
        if let ref = eventHandlerRef { RemoveEventHandler(ref); eventHandlerRef = nil }
    }
}

// The Carbon API requires a free C function (not a Swift closure) as the event handler.
// The HotKeyManager is recovered from userData to dispatch back into Swift.
private func hotKeyEventCallback(
    _ nextHandler: EventHandlerCallRef?,
    _ event: EventRef?,
    _ userData: UnsafeMutableRawPointer?
) -> OSStatus {
    guard let userData else { return Darwin.noErr }
    let manager = Unmanaged<HotKeyManager>.fromOpaque(userData).takeUnretainedValue()
    DispatchQueue.main.async { manager.action?() }
    return Darwin.noErr
}
