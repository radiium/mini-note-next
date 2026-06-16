import SwiftUI

// MARK: - ToolbarIcon

/// Image stylisée pour les barres de contrôle (header / footer).
/// Utilisable à l'intérieur d'un Button ou d'un ShareLink.
struct ToolbarIcon: View {
    let name: String
    var foreground: Color = .secondary
    
    var body: some View {
        Image(systemName: name)
            .font(.system(size: 14))
            .foregroundStyle(foreground)
            .frame(width: Layout.controlHeight, height: Layout.controlHeight)
            .contentShape(Rectangle())
    }
}

// MARK: - ToolbarButton

/// Bouton icône standard des barres de contrôle.
struct ToolbarButton: View {
    let icon: String
    let label: LocalizedStringKey
    var foreground: Color = .secondary
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            ToolbarIcon(name: icon, foreground: foreground)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .help(label)
        .hoverBackground()
    }
}

// MARK: - ToolbarLeadingControls

/// Boutons pin et mode fenêtre, partagés entre NoteListView et NoteEditorView.
struct ToolbarLeadingControls: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.toggleWindowMode) private var toggleWindowMode

    var body: some View {
        Group {
            ToolbarButton(
                icon: appState.isPinned ? "pin.fill" : "pin",
                label: appState.isPinned ? "action.unpin" : "action.pin",
                foreground: .primary
            ) { appState.isPinned.toggle() }
                .activeBackground(appState.isPinned)

            ToolbarButton(
                icon: appState.isWindowMode ? "macwindow.on.rectangle" : "macwindow",
                label: appState.isWindowMode ? "action.collapse_to_menubar" : "action.open_as_window",
                foreground: .primary
            ) { toggleWindowMode() }
                .activeBackground(appState.isWindowMode)
        }
    }
}

// MARK: - Previews

#Preview {
    HStack(spacing: 4) {
        ToolbarButton(icon: "plus", label: "Nouveau") {}
        ToolbarButton(icon: "gearshape", label: "Préférences") {}
        ToolbarButton(icon: "star.fill", label: "Favori", foreground: .yellow) {}
        ToolbarButton(icon: "trash", label: "Supprimer") {}
    }
    .padding()
}
