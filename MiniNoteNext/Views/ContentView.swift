import SwiftUI
import SwiftData

struct ContentView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.openWindow) private var openWindow
    @AppStorage(PreferenceKey.appColorScheme) private var colorSchemeRaw = AppColorScheme.auto.rawValue
    @AppStorage(PreferenceKey.appLanguage)    private var languageCode    = ""
    @AppStorage(PreferenceKey.panelSize)      private var panelSizeRaw    = PanelSizePreset.medium.rawValue
    
    private var panelSize: NSSize {
        (PanelSizePreset(rawValue: panelSizeRaw) ?? .medium).size
    }
    
    private var currentLocale: Locale {
        languageCode.isEmpty ? .current : Locale(identifier: languageCode)
    }
    
    @State private var selectedNote: Note? = nil
    
    private var contentStack: some View {
        Group {
            if let note = selectedNote {
                NoteEditorView(note: note, onBack: { selectedNote = nil })
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing),
                        removal: .move(edge: .trailing)
                    ))
            } else {
                NoteListView(onSelectNote: { selectedNote = $0 }, onAddNote: {
                    let note = Note()
                    // Not inserted yet — NoteEditorView inserts it on the first keystroke (lazy creation).
                    selectedNote = note
                })
                .transition(.asymmetric(
                    insertion: .move(edge: .leading),
                    removal: .move(edge: .leading)
                ))
            }
        }
        .animation(.spring(duration: 0.3), value: selectedNote == nil)
        .preferredColorScheme(AppColorScheme(rawValue: colorSchemeRaw)?.colorScheme)
        .environment(\.locale, currentLocale)
        .onReceive(NotificationCenter.default.publisher(for: .openSettings)) { _ in
            // AppDelegate cannot call openWindow directly (requires @Environment, unavailable in AppKit).
            // NotificationCenter bridges the call so ContentView can invoke the SwiftUI scene API.
            openWindow(id: "settings")
        }
    }
    
    var body: some View {
        // if/else produces two distinct view trees. SwiftUI resets @State (selectedNote) when
        // switching branches — intentional trade-off for an infrequent mode change.
        if appState.isWindowMode {
            contentStack
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            contentStack
                .frame(width: panelSize.width, height: panelSize.height)
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: Layout.panelRadius))
                .overlay(RoundedRectangle(cornerRadius: Layout.panelRadius)
                    .stroke(Color(.separatorColor), lineWidth: 0.5)
                )
        }
    }
}
