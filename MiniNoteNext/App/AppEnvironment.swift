import SwiftUI

private struct ToggleWindowModeKey: EnvironmentKey {
    static let defaultValue: () -> Void = {}
}

extension EnvironmentValues {
    var toggleWindowMode: () -> Void {
        get { self[ToggleWindowModeKey.self] }
        set { self[ToggleWindowModeKey.self] = newValue }
    }
}
