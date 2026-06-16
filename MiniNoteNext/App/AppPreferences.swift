import SwiftUI

// MARK: - Color scheme

enum AppColorScheme: String, CaseIterable {
    case auto, light, dark
    
    var label: LocalizedStringKey {
        switch self {
        case .auto:  return "theme.auto"
        case .light: return "theme.light"
        case .dark:  return "theme.dark"
        }
    }
    
    var colorScheme: ColorScheme? {
        switch self {
        case .auto:  return nil
        case .light: return .light
        case .dark:  return .dark
        }
    }
}

// MARK: - Font family

enum EditorFontFamily: String, CaseIterable {
    case system, monospace, serif
    
    var label: LocalizedStringKey {
        switch self {
        case .system:    return "font.system"
        case .monospace: return "font.monospace"
        case .serif:     return "font.serif"
        }
    }
    
    func font(size: Double) -> Font {
        switch self {
        case .system:    return .system(size: size, design: .default)
        case .monospace: return .system(size: size, design: .monospaced)
        case .serif:     return .system(size: size, design: .serif)
        }
    }
}

// MARK: - Supported languages

enum SupportedLanguage: String, CaseIterable {
    case system  = ""
    case english = "en"
    case french  = "fr"
    
    var label: LocalizedStringKey {
        switch self {
        case .system:  return "language.system"
        case .english: return "language.english"
        case .french:  return "language.french"
        }
    }
}

// MARK: - Panel size preset

enum PanelSizePreset: String, CaseIterable {
    case medium, large
    
    var label: LocalizedStringKey {
        switch self {
        case .medium: return "panel.size.medium"
        case .large:  return "panel.size.large"
        }
    }
    
    var size: NSSize {
        switch self {
        case .medium: return NSSize(width: 320, height: 420)
        case .large:  return NSSize(width: 400, height: 520)
        }
    }
    
    static var preferred: NSSize {
        let raw = UserDefaults.standard.string(forKey: PreferenceKey.panelSize) ?? ""
        return (PanelSizePreset(rawValue: raw) ?? .medium).size
    }
}

// MARK: - Preference keys

enum PreferenceKey {
    static let appColorScheme      = "appColorScheme"
    static let editorFontFamily    = "editorFontFamily"
    static let editorFontSize      = "editorFontSize"
    static let editorLineHeight    = "editorLineHeight"
    static let editorLetterSpacing = "editorLetterSpacing"
    static let hotKeyEnabled       = "hotKeyEnabled"
    static let appLanguage         = "appLanguage"
    static let isPinned            = "isPinned"
    static let panelSize           = "panelSize"
}

// MARK: - Notification names

extension Notification.Name {
    static let openSettings = Notification.Name("openSettings")
}

// MARK: - Layout constants

enum Layout {
    static let controlHeight:  CGFloat = 28
    static let controlRadius:  CGFloat = 8
    static let panelRadius:    CGFloat = 12
    static let padding:        CGFloat = 8
    static let spacing:        CGFloat = 6
    static let subtleOpacity:  CGFloat = 0.06
    static let controlOpacity: CGFloat = 0.1
    static let activeOpacity:  CGFloat = 0.15
}
