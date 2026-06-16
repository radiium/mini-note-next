import SwiftUI

@main
struct MiniNoteNextApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        // Window is used instead of Settings because the Settings scene does not support resizable
        // windows, and SettingsLink is incompatible with a SwiftUI hierarchy hosted inside an AppKit
        // NSPanel (outside of any standard SwiftUI scene).
        Window("window.preferences", id: "settings") {
            SettingsView()
        }
        .windowResizability(.contentSize)
        .defaultLaunchBehavior(.suppressed)
    }
}
