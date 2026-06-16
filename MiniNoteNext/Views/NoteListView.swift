import SwiftUI
import SwiftData


struct NoteListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openWindow) private var openWindow
    @Query(sort: \Note.modifiedAt, order: .reverse) private var notes: [Note]
    @State private var searchText = ""
    @State private var focusedNoteID: Note.ID?
    @State private var noteToDelete: Note?
    @State private var hoveredNoteID: Note.ID?
    @FocusState private var isListFocused: Bool
    @FocusState private var isSearchFocused: Bool
    
    let onSelectNote: (Note) -> Void
    let onAddNote: () -> Void
    
    private var filteredNotes: [Note] {
        var result = notes.sorted { $0.isFavorite && !$1.isFavorite }
        if !searchText.isEmpty {
            result = result.filter {
                $0.title.localizedCaseInsensitiveContains(searchText) ||
                $0.content.localizedCaseInsensitiveContains(searchText)
            }
        }
        return result
    }
    
    private var deletionBinding: Binding<Bool> {
        Binding(
            get: { noteToDelete != nil },
            set: { if !$0 { noteToDelete = nil } }
        )
    }
    
    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: Layout.padding) {
                header
                searchBar
            }
            .padding(.vertical, Layout.padding)
            .padding(.horizontal, Layout.padding)
            
            Separator()
            noteList
            Separator()
            footer
        }
        .confirmationDialog(
            "alert.delete_note.title",
            isPresented: deletionBinding,
            titleVisibility: .visible
        ) {
            Button("action.delete", role: .destructive) {
                if let note = noteToDelete { modelContext.delete(note) }
                noteToDelete = nil
            }
        }
        .background {
            Button("") { isSearchFocused = true }
                .keyboardShortcut("f", modifiers: .command)
                .opacity(0)
                .allowsHitTesting(false)
        }
    }
    
    // MARK: - Header
    
    private var header: some View {
        HStack(alignment: .center, spacing: Layout.spacing) {
            ToolbarLeadingControls()
            Spacer()
            ToolbarButton(icon: "plus", label: "action.new_note", action: onAddNote)
                .keyboardShortcut("n", modifiers: .command)
                .activeBackground()
        }
    }
    
    // MARK: - Search bar
    
    private var searchBar: some View {
        HStack(spacing: Layout.spacing) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .font(.caption)
            TextField("search.placeholder", text: $searchText)
                .textFieldStyle(.plain)
                .focused($isSearchFocused)
                .onKeyPress(.escape) {
                    if !searchText.isEmpty { searchText = "" }
                    return .handled
                }
            if !searchText.isEmpty {
                Button { searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(height: Layout.controlHeight)
        .padding(.horizontal, Layout.padding)
        .background(Color.primary.opacity(Layout.subtleOpacity), in: RoundedRectangle(cornerRadius: Layout.controlRadius))
    }
    
    // MARK: - Note list
    
    @ViewBuilder
    private var noteList: some View {
        if filteredNotes.isEmpty {
            Spacer()
            if !searchText.isEmpty {
                Text("search.no_results \(searchText)")
                    .foregroundStyle(.secondary)
                    .font(.callout)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
            } else {
                Text("list.empty.notes")
                    .foregroundStyle(.secondary)
                    .font(.callout)
                Button("action.create_note", action: onAddNote)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .padding(.top, 20)
            }
            Spacer()
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(filteredNotes) { note in
                            NoteRowView(
                                note: note,
                                isKeyboardSelected: focusedNoteID == note.id,
                                isHovered: hoveredNoteID == note.id
                            )
                            .id(note.id)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                hoveredNoteID = nil
                                onSelectNote(note)
                            }
                            .contextMenu { NoteContextMenu(note: note, onSelectNote: onSelectNote, noteToDelete: $noteToDelete) }
                            .onHover { hoveredNoteID = $0 ? note.id : nil }
                        }
                    }
                    .padding(.vertical, Layout.padding)
                    .padding(.horizontal, Layout.padding)
                }
                .focusable()
                .focused($isListFocused)
                .focusEffectDisabled()
                .onKeyPress(.upArrow)   { move(-1, proxy: proxy) }
                .onKeyPress(.downArrow) { move(+1, proxy: proxy) }
                .onKeyPress(.return) {
                    guard let id = focusedNoteID,
                          let note = filteredNotes.first(where: { $0.id == id })
                    else { return .ignored }
                    onSelectNote(note)
                    return .handled
                }
                .onKeyPress(.escape) { focusedNoteID = nil; return .ignored }
                .onAppear { isListFocused = true }
                .onChange(of: searchText) { focusedNoteID = nil }
            }
        }
    }
    
    // MARK: - Footer
    
    private var footer: some View {
        HStack(alignment: .center, spacing: Layout.spacing) {
            Group {
                if !searchText.isEmpty {
                    Text("\(filteredNotes.count) / ") + Text("note.count \(notes.count)")
                } else {
                    Text("note.count \(notes.count)")
                }
            }
            .foregroundStyle(.secondary)
            .font(.subheadline)
            .padding(.leading, Layout.padding)
            
            Spacer()
            
            ToolbarButton(
                icon: "gearshape",
                label: "label.preferences"
            ) {
                // NSApp.activate() is required: openWindow from a floating NSPanel does not automatically
                // bring the app to the foreground, unlike a call from a standard SwiftUI window.
                openWindow(id: "settings")
                NSApp.activate()
            }
        }
        .buttonStyle(.plain)
        .padding(Layout.padding)
    }
    
    // MARK: - Keyboard navigation
    
    private func move(_ delta: Int, proxy: ScrollViewProxy) -> KeyPress.Result {
        let ids = filteredNotes.map(\.id)
        guard !ids.isEmpty else { return .ignored }
        
        if let current = focusedNoteID, let idx = ids.firstIndex(of: current) {
            let newIdx = max(0, min(ids.count - 1, idx + delta))
            focusedNoteID = ids[newIdx]
        } else {
            focusedNoteID = delta > 0 ? ids.first : ids.last
        }
        
        if let id = focusedNoteID {
            withAnimation(.easeInOut(duration: 0.1)) { proxy.scrollTo(id, anchor: nil) }
        }
        return .handled
    }
}

#Preview("With notes", traits: .sizeThatFitsLayout)  {
    let container: ModelContainer = {
        let c = try! ModelContainer(for: Note.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        c.mainContext.insert(Note(content: "Réunion client\nPréparer la démo pour jeudi", isFavorite: true))
        c.mainContext.insert(Note(content: "Liste de courses\nPain, lait, oeufs"))
        c.mainContext.insert(Note(content: "Idée app\nUne app de notes minimaliste"))
        return c
    }()
    return NoteListView(onSelectNote: { _ in }, onAddNote: {})
        .environmentObject(AppState())
        .modelContainer(container)
        .frame(width: PanelSizePreset.preferred.width, height: PanelSizePreset.preferred.height)
}

#Preview("Without notes", traits: .sizeThatFitsLayout)  {
    let container: ModelContainer = {
        let c = try! ModelContainer(for: Note.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        return c
    }()
    
    return NoteListView(onSelectNote: { _ in }, onAddNote: {})
        .environmentObject(AppState())
        .modelContainer(container)
        .frame(width: PanelSizePreset.preferred.width, height: PanelSizePreset.preferred.height)
}

