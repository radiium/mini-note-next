import SwiftUI
import SwiftData

struct NoteRowView: View {
    @Bindable var note: Note
    var isKeyboardSelected: Bool = false
    var isHovered: Bool = false
    
    var body: some View {
        HStack(spacing: Layout.padding) {
            Button {
                note.toggleFavorite()
            } label: {
                Image(systemName: note.isFavorite ? "star.fill" : "star")
                    .font(.title3)
                    .foregroundStyle(note.isFavorite ? Color.yellow : Color.secondary.opacity(0.4))
                    .frame(width: 24)
                    .frame(maxHeight: .infinity)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(note.isFavorite ? String(localized: "action.unfavorite") : String(localized: "action.favorite"))
            
            HStack(alignment: .center, spacing: 3) {
                Text(note.title)
                    .font(.title3)
                    .fontWeight(.medium)
                    .lineLimit(1)
                
                Spacer()
                
                Text(note.modifiedAt.formattedRelative)
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, Layout.padding)
        .padding(.leading, Layout.padding)
        .padding(.trailing, 16)
        .background(
            RoundedRectangle(cornerRadius: Layout.controlRadius)
                .fill(
                    isKeyboardSelected ? Color.accentColor.opacity(Layout.activeOpacity) :
                        isHovered          ? Color.primary.opacity(Layout.subtleOpacity) :
                        Color.clear
                )
        )
        .help(note.tooltipContent())
    }
}

#Preview("Row normale") {
    let note = Note(content: "Titre de la note\nLigne de preview du contenu")
    return NoteRowView(note: note)
        .modelContainer(for: Note.self, inMemory: true)
        .padding(.horizontal, 8)
        .frame(width: PanelSizePreset.preferred.width)
}

#Preview("Row favorite") {
    let note = Note(content: "Note importante\nAvec du contenu supplémentaire", isFavorite: true)
    return NoteRowView(note: note)
        .modelContainer(for: Note.self, inMemory: true)
        .padding(.horizontal, 8)
        .frame(width: PanelSizePreset.preferred.width)
}
