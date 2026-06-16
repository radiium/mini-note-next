import Combine
import Foundation

final class AppState: ObservableObject {
    @Published var isPinned: Bool {
        didSet { UserDefaults.standard.set(isPinned, forKey: PreferenceKey.isPinned) }
    }
    // Read-only for SwiftUI; written exclusively via setWindowMode(_:) by PanelController.
    @Published private(set) var isWindowMode: Bool = false
    
    init() {
        isPinned = UserDefaults.standard.bool(forKey: PreferenceKey.isPinned)
        // isWindowMode is session-only: always false on launch.
    }
    
    func setWindowMode(_ value: Bool) {
        isWindowMode = value
    }
}
