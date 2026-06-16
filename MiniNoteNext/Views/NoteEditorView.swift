import SwiftUI
import SwiftData

struct NoteEditorView: View {
    @Environment(\.modelContext) private var modelContext
    
    @Bindable var note: Note
    let onBack: () -> Void
    
    @AppStorage(PreferenceKey.editorFontSize)      private var fontSize: Double = 14
    @AppStorage(PreferenceKey.editorFontFamily)    private var fontFamilyRaw = EditorFontFamily.system.rawValue
    @AppStorage(PreferenceKey.editorLineHeight)    private var lineHeight: Double = 1.3
    @AppStorage(PreferenceKey.editorLetterSpacing) private var letterSpacing: Double = 0.0
    private var fontFamily: EditorFontFamily { EditorFontFamily(rawValue: fontFamilyRaw) ?? .system }
    @State private var showDeleteConfirm = false
    @State private var debounceTask: Task<Void, Never>?
    @State private var keyMonitor: Any?
    
    private enum Key {
        static let escape: UInt16 = 53  // kVK_Escape
        static let delete: UInt16 = 51  // kVK_Delete
    }
    
    private func goBack() {
        guard note.modelContext != nil else {
            onBack()
            return
        }
        if note.isEmpty { modelContext.delete(note) }
        onBack()
    }
    
    var body: some View {
        VStack(spacing: 0) {
            header
            Separator()
            editor
            Separator()
            footer
        }
        .onChange(of: note.content) {
            if note.modelContext == nil,
               !note.isEmpty {
                modelContext.insert(note)
            }
            debounceTask?.cancel()
            debounceTask = Task {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled, note.modelContext != nil else { return }
                note.modifiedAt = .now
            }
        }
        .onAppear {
            keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                let mods = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
                let char = event.charactersIgnoringModifiers?.lowercased()
                
                if event.keyCode == Key.escape, mods.isEmpty {
                    guard !showDeleteConfirm else { return event }
                    goBack()
                    return nil
                }
                if char == "w", mods == .command { // Cmd+W → go back
                    guard !showDeleteConfirm else { return event }
                    goBack()
                    return nil
                }
                if event.keyCode == Key.delete, mods == .command {
                    showDeleteConfirm = true
                    return nil
                }
                return event
            }
        }
        .onDisappear {
            debounceTask?.cancel()
            debounceTask = nil
            if let m = keyMonitor { NSEvent.removeMonitor(m); keyMonitor = nil }
        }
        .alert("alert.delete_note.title", isPresented: $showDeleteConfirm) {
            Button("action.delete", role: .destructive) {
                if note.modelContext != nil { modelContext.delete(note) }
                onBack()
            }
            Button("action.cancel", role: .cancel) {}
        }
    }
    
    // MARK: - Header
    
    private var header: some View {
        HStack(spacing: Layout.spacing) {
            ToolbarLeadingControls()
            Spacer()
            ToolbarButton(
                icon: note.isFavorite ? "star.fill" : "star",
                label: note.isFavorite ? "action.unfavorite" : "action.favorite",
                foreground: note.isFavorite ? .yellow : .secondary
            ) { note.toggleFavorite() }
            ToolbarButton(icon: "xmark", label: "action.quit", foreground: .primary) { goBack() }
                .activeBackground()
        }
        .padding(Layout.padding)
    }
    
    // MARK: - Editor
    
    private var editor: some View {
        ZStack(alignment: .topLeading) {
            TextEditor(text: $note.content)
                .font(fontFamily.font(size: fontSize))
                .lineSpacing((lineHeight - 1.0) * fontSize)
                .tracking(letterSpacing)
                .scrollContentBackground(.hidden)
                .scrollClipDisabled()
            
            if note.content.isEmpty {
                Text("editor.placeholder")
                    .font(fontFamily.font(size: fontSize))
                    .lineSpacing((lineHeight - 1.0) * fontSize)
                    .tracking(letterSpacing)
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 5)
                    .allowsHitTesting(false)
            }
        }
        .padding(.vertical, Layout.padding)
        .padding(.horizontal, Layout.padding)
        //.background(Color(nsColor: .textBackgroundColor))
        // .clipped() creates masksToBounds on the CA layer, which contains the NSScrollView's
        // overflow (from .scrollClipDisabled) within the editor area, preventing it from
        // rendering over the header/footer. zIndex can't do this for AppKit-backed views.
        .clipped()
    }
    
    // MARK: - Footer
    
    private var footer: some View {
        HStack(alignment: .center, spacing: Layout.spacing) {
            Text(note.modifiedAt.formattedRelative)
                .foregroundStyle(.secondary)
                .font(.subheadline)
                .padding(.leading, Layout.padding)
            
            Spacer()
            
            ShareLink(item: note.content) {
                ToolbarIcon(name: "square.and.arrow.up")
                    .offset(y: -2)
            }
            .buttonStyle(.plain)
            .hoverBackground()
            
            ToolbarButton(icon: "trash", label: "action.delete_note") {
                showDeleteConfirm = true
            }
        }
        .buttonStyle(.plain)
        .padding(Layout.padding)
    }
}

#Preview("Avec contenu") {
    let container = try! ModelContainer(for: Note.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    let note = Note(content: "Réunion client\nPréparer la démo pour jeudi\nRelancer Thomas pour le contrat")
    container.mainContext.insert(note)
    return NoteEditorView(note: note, onBack: {})
        .environmentObject(AppState())
        .modelContainer(container)
        .frame(width: PanelSizePreset.preferred.width, height: PanelSizePreset.preferred.height)
}

#Preview("Avec contenu tres long") {
    let container = try! ModelContainer(for: Note.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    let note = Note(content: "Zasdf\nZasdf\nZasdf.\nZasdf ae az\ne\naze.\n aze\naze^pazoepôazepô\naze. \naz e az e azeakjqskdjfhqskjdfhkqsdjfhqskdjfhqskjdfhkqsjdfhkqsjhdfkjqshdfkqjshdfkjqshdfkjqhsdfkhqsdkjfhqskdfjhqskdjfhkqsjdfhkqsjdfhkqsdhfkjqshdfkjqshfdkjqhsdfkjhqsdfkjhqskdfjhqskdjfhqksjdhfkqjshdfkjqshdfkjqshfd sqdfqsdjkfhqkjsdfhkjsqdhfkjsqdhfkjsqdfhkjq dfhkjsqdfhkjqshdfkjshqdfkjqshdfkjqshdfdfhkjsqdfhkjqshdfkjshqdfkjqshdfkjqshdfdfhkjsqdfhkjqshdfkjshqdfkjqshdfkjqshdfdfhkjsqdfhkjqshdfkjshqdfkjqshdfkjqshdfdfhkjsqdfhkjqshdfkjshqdfkjqshdfkjqshdfdfhkjsqdfhkjqshdfkjshqdfkjqshdfkjqshdfdfhkjsqdfhkjqshdfkjshqdfkjqshdfkjqshdfdfhkjsqdfhkjqshdfkjshqdfkjqshdfkjqshdfdfhkjsqdfhkjqshdfkjshqdfkjqshdfkjqshdfdfhkjsqdfhkjqshdfkjshqdfkjqshdfkjqshdfdfhkjsqdfhkjqshdfkjshqdfkjqshdfkjqshdfjhqsdkfjhqskdjfhkqsdjfhkjqsdhfkjqsdfhkqsdhfkjqshd")
    container.mainContext.insert(note)
    return NoteEditorView(note: note, onBack: {})
        .environmentObject(AppState())
        .modelContainer(container)
        .frame(width: PanelSizePreset.preferred.width, height: PanelSizePreset.preferred.height)
}


#Preview("Vide") {
    let container = try! ModelContainer(for: Note.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    let note = Note(content: "")
    container.mainContext.insert(note)
    return NoteEditorView(note: note, onBack: {})
        .environmentObject(AppState())
        .modelContainer(container)
        .frame(width: PanelSizePreset.preferred.width, height: PanelSizePreset.preferred.height)
}

#Preview("Favori") {
    let container = try! ModelContainer(for: Note.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    let note = Note(content: "Note importante\nÀ ne pas oublier", isFavorite: true)
    container.mainContext.insert(note)
    return NoteEditorView(note: note, onBack: {})
        .environmentObject(AppState())
        .modelContainer(container)
        .frame(width: PanelSizePreset.preferred.width, height: PanelSizePreset.preferred.height)
}
