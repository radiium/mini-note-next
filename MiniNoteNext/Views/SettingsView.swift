import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @AppStorage(PreferenceKey.appColorScheme)      private var colorSchemeRaw    = AppColorScheme.auto.rawValue
    @AppStorage(PreferenceKey.editorFontFamily)    private var fontFamilyRaw     = EditorFontFamily.system.rawValue
    @AppStorage(PreferenceKey.editorFontSize)      private var fontSize: Double  = 14
    @AppStorage(PreferenceKey.editorLineHeight)    private var lineHeight: Double = 1.3
    @AppStorage(PreferenceKey.editorLetterSpacing) private var letterSpacing: Double = 0.0
    @AppStorage(PreferenceKey.hotKeyEnabled)       private var hotKeyEnabled     = false
    @AppStorage(PreferenceKey.appLanguage)         private var languageCode      = ""
    @AppStorage(PreferenceKey.panelSize)           private var panelSizeRaw      = PanelSizePreset.medium.rawValue
    
    @State private var launchAtLogin = false
    
    private var currentLocale: Locale {
        languageCode.isEmpty ? .current : Locale(identifier: languageCode)
    }
    
    private var currentFontFamily: EditorFontFamily {
        EditorFontFamily(rawValue: fontFamilyRaw) ?? .system
    }
    
    var body: some View {
        Form {
            Section("settings.section.appearance") {
                Picker("settings.theme", selection: $colorSchemeRaw) {
                    ForEach(AppColorScheme.allCases, id: \.rawValue) {
                        Text($0.label).tag($0.rawValue)
                    }
                }
                .pickerStyle(.segmented)
                
                Picker("settings.panel_size", selection: $panelSizeRaw) {
                    ForEach(PanelSizePreset.allCases, id: \.rawValue) {
                        Text($0.label).tag($0.rawValue)
                    }
                }
                .pickerStyle(.segmented)
            }
            
            Section("settings.section.editor") {
                Picker("settings.font", selection: $fontFamilyRaw) {
                    ForEach(EditorFontFamily.allCases, id: \.rawValue) {
                        Text($0.label).tag($0.rawValue)
                    }
                }
                .pickerStyle(.menu)
                
                LabeledContent("settings.font_size") {
                    HStack(spacing: Layout.spacing) {
                        Text(verbatim: "A").font(.system(size: 11)).foregroundStyle(.secondary)
                        Slider(value: $fontSize, in: 11...20, step: 1).frame(width: 120)
                        Text(verbatim: "A").font(.system(size: 20)).foregroundStyle(.secondary)
                    }
                }
                
                LabeledContent("settings.line_height") {
                    HStack(spacing: Layout.spacing) {
                        Image(systemName: "text.alignleft").foregroundStyle(.secondary).font(.caption)
                        Slider(value: $lineHeight, in: 1.0...2.0, step: 0.1).frame(width: 120)
                        Image(systemName: "text.alignleft").foregroundStyle(.secondary)
                    }
                }
                
                LabeledContent("settings.letter_spacing") {
                    HStack(spacing: Layout.spacing) {
                        Text(verbatim: "AV").font(.caption).foregroundStyle(.secondary)
                        Slider(value: $letterSpacing, in: 0...4, step: 0.5).frame(width: 120)
                        Text(verbatim: "A  V").font(.caption).foregroundStyle(.secondary)
                    }
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("settings.preview.label")
                    Text("settings.preview.sample")
                        .font(currentFontFamily.font(size: fontSize))
                        .lineSpacing((lineHeight - 1.0) * fontSize)
                        .tracking(letterSpacing)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: Layout.controlRadius)
                        .fill(.primary.opacity(0.05))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Layout.controlRadius)
                        .stroke(.separator, lineWidth: 1)
                )
            }
            
            Section("settings.section.general") {
                Picker("settings.language", selection: $languageCode) {
                    ForEach(SupportedLanguage.allCases, id: \.rawValue) {
                        Text($0.label).tag($0.rawValue)
                    }
                }
                
                Toggle("settings.launch_at_login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, enabled in
                        do {
                            if enabled { try SMAppService.mainApp.register() }
                            else       { try SMAppService.mainApp.unregister() }
                        } catch {
                            let actual = SMAppService.mainApp.status == .enabled
                            Task { @MainActor in launchAtLogin = actual }
                        }
                    }
                
                Toggle(isOn: $hotKeyEnabled) {
                    HStack(spacing: Layout.spacing) {
                        Text("settings.hotkey")
                        if hotKeyEnabled {
                            HStack(spacing: 2) {
                                ForEach(["⌥", "Space"], id: \.self) { key in
                                    Text(key)
                                        .font(.caption)
                                        .padding(.horizontal, 5)
                                        .padding(.vertical, 2)
                                        .background(Color.secondary.opacity(Layout.activeOpacity), in: RoundedRectangle(cornerRadius: 4))
                                }
                            }
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 380)
        .padding(.vertical, Layout.padding)
        .preferredColorScheme(AppColorScheme(rawValue: colorSchemeRaw)?.colorScheme)
        .environment(\.locale, currentLocale)
        .task { launchAtLogin = SMAppService.mainApp.status == .enabled }
    }
}

#Preview {
    SettingsView()
}
