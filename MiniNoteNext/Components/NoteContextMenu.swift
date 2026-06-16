import SwiftUI
import SwiftData

struct NoteContextMenu: View {
    @Environment(\.modelContext) private var modelContext
    let note: Note
    let onSelectNote: (Note) -> Void
    @Binding var noteToDelete: Note?
    
    var body: some View {
        Button {
            note.toggleFavorite()
        } label: {
            Label(
                note.isFavorite ? "action.unfavorite" : "action.favorite",
                systemImage: note.isFavorite ? "star.slash" : "star"
            )
        }
        
        Button {
            let copy = Note(content: note.content, isFavorite: note.isFavorite)
            modelContext.insert(copy)
            try? modelContext.save()
            onSelectNote(copy)
        } label: {
            Label("action.duplicate", systemImage: "doc.on.doc")
        }
        
        Button {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(note.content, forType: .string)
        } label: {
            Label("action.copy_content", systemImage: "doc.on.clipboard")
        }
        
        ShareLink(item: note.content) {
            Label("action.share", systemImage: "square.and.arrow.up")
        }
        
        Button(role: .destructive) {
            noteToDelete = note
        } label: {
            Label("action.delete", systemImage: "trash")
        }
    }
}
