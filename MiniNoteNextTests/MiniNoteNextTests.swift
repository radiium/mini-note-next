import Testing
import SwiftData
import SwiftUI
@testable import MiniNoteNext

// MARK: - Note model

@Suite("Note model")
struct NoteModelTests {
    
    @Suite("init")
    struct InitTests {
        @Test func defaultsAreCorrect() {
            let note = Note()
            #expect(note.content == "")
            #expect(note.isFavorite == false)
        }
        
        @Test func createdAtIsApproximatelyNow() {
            let before = Date.now
            let note = Note()
            let after = Date.now
            #expect(note.createdAt >= before && note.createdAt <= after)
        }
        
        @Test func modifiedAtIsApproximatelyNow() {
            let before = Date.now
            let note = Note()
            let after = Date.now
            #expect(note.modifiedAt >= before && note.modifiedAt <= after)
        }
        
        @Test func customValuesAreStored() {
            let date = Date(timeIntervalSinceReferenceDate: 1_000_000)
            let note = Note(content: "Hello", createdAt: date, modifiedAt: date, isFavorite: true)
            #expect(note.content == "Hello")
            #expect(note.createdAt == date)
            #expect(note.modifiedAt == date)
            #expect(note.isFavorite == true)
        }
    }
    
    @Suite("title")
    struct TitleTests {
        @Test func singleLine() {
            #expect(Note(content: "My note").title == "My note")
        }
        
        @Test func returnsFirstLine() {
            #expect(Note(content: "First\nSecond").title == "First")
        }
        
        @Test func skipsLeadingEmptyLines() {
            #expect(Note(content: "\n\nActual title\nBody").title == "Actual title")
        }
        
        @Test func skipsWhitespaceOnlyLines() {
            #expect(Note(content: "   \n\t\nActual title").title == "Actual title")
        }
        
        @Test func preservesLineContentVerbatim() {
            // Whitespace check skips the line but the raw Substring is returned as title.
            #expect(Note(content: "  Indented  \nSecond").title == "  Indented  ")
        }
        
        @Test func emptyContentReturnsFallback() {
            #expect(!Note(content: "").title.isEmpty)
        }
        
        @Test func whitespaceOnlyContentReturnsFallback() {
            #expect(!Note(content: "   \n\n\t  ").title.isEmpty)
        }
    }
}

// MARK: - Note.tooltipContent

@Suite("Note.tooltipContent")
struct NoteTooltipTests {
    
    @Test func shortContentReturnedVerbatim() {
        #expect(Note(content: "Short").tooltipContent() == "Short")
    }
    
    @Test func contentAtExactMaxLengthNotTruncated() {
        let content = String(repeating: "a", count: 200)
        #expect(Note(content: content).tooltipContent() == content)
    }
    
    @Test func contentAboveMaxLengthTruncatedWithEllipsis() {
        let result = Note(content: String(repeating: "a", count: 300)).tooltipContent()
        #expect(result.hasSuffix("…"))
        #expect(result.count == 201) // 200 chars + U+2026 (single character)
    }
    
    @Test func leadingAndTrailingWhitespaceIsTrimmed() {
        #expect(Note(content: "\n\n  trimmed  \n\n").tooltipContent() == "trimmed")
    }
    
    @Test func emptyContentReturnsEmptyString() {
        #expect(Note(content: "").tooltipContent() == "")
    }
    
    @Test func customMaxLength() {
        #expect(Note(content: "Hello World").tooltipContent(maxLength: 5) == "Hello…")
    }
    
    @Test func multilineContentPreservesInternalNewlines() {
        let content = "Line 1\nLine 2\nLine 3"
        #expect(Note(content: content).tooltipContent() == content)
    }
}

// MARK: - AppColorScheme

@Suite("AppColorScheme")
struct AppColorSchemeTests {
    
    @Test func colorSchemeMapping() {
        #expect(AppColorScheme.auto.colorScheme  == nil)
        #expect(AppColorScheme.light.colorScheme == .light)
        #expect(AppColorScheme.dark.colorScheme  == .dark)
    }
    
    @Test func rawValueRoundtrips() throws {
        for scheme in AppColorScheme.allCases {
            let result = try #require(AppColorScheme(rawValue: scheme.rawValue))
            #expect(result == scheme)
        }
    }
    
    @Test func invalidRawValueReturnsNil() {
        #expect(AppColorScheme(rawValue: "invalid") == nil)
    }
}

// MARK: - EditorFontFamily

@Suite("EditorFontFamily")
struct EditorFontFamilyTests {
    
    @Test func rawValueRoundtrips() throws {
        for family in EditorFontFamily.allCases {
            let result = try #require(EditorFontFamily(rawValue: family.rawValue))
            #expect(result == family)
        }
    }
    
    @Test func invalidRawValueReturnsNil() {
        #expect(EditorFontFamily(rawValue: "cursive") == nil)
    }
    
    @Test func exactlyThreeCases() {
        #expect(EditorFontFamily.allCases.count == 3)
    }
}

// MARK: - SwiftData integration

@Suite("SwiftData integration")
struct NoteSwiftDataTests {
    
    // ModelContext(container) avoids the @MainActor isolation required by
    // container.mainContext, which caused EXC_BREAKPOINT in Swift Testing's
    // parallel struct-suite execution model.
    private func makeContext() throws -> ModelContext {
        let schema = Schema([Note.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        return ModelContext(container)
    }
    
    @Test func insertAndFetch() throws {
        let ctx = try makeContext()
        ctx.insert(Note(content: "Persisted note"))
        try ctx.save()
        
        let fetched = try ctx.fetch(FetchDescriptor<Note>())
        #expect(fetched.count == 1)
        #expect(fetched.first?.content == "Persisted note")
    }
    
    @Test func deleteNote() throws {
        let ctx = try makeContext()
        let note = Note(content: "To be deleted")
        ctx.insert(note)
        try ctx.save()
        
        ctx.delete(note)
        try ctx.save()
        
        #expect(try ctx.fetch(FetchDescriptor<Note>()).isEmpty)
    }
    
    @Test func sortsByModifiedAtDescending() throws {
        let ctx = try makeContext()
        ctx.insert(Note(content: "Oldest", modifiedAt: Date(timeIntervalSinceNow: -200)))
        ctx.insert(Note(content: "Newest", modifiedAt: Date(timeIntervalSinceNow:  -10)))
        ctx.insert(Note(content: "Middle", modifiedAt: Date(timeIntervalSinceNow: -100)))
        try ctx.save()
        
        let descriptor = FetchDescriptor<Note>(sortBy: [SortDescriptor(\Note.modifiedAt, order: .reverse)])
        let fetched = try ctx.fetch(descriptor)
        #expect(fetched.map(\.content) == ["Newest", "Middle", "Oldest"])
    }
    
    @Test func draftNoteHasNoContext() {
        #expect(Note(content: "Not inserted").modelContext == nil)
    }
    
    @Test func insertedNoteHasContext() throws {
        let ctx = try makeContext()
        let note = Note(content: "Draft becomes real")
        #expect(note.modelContext == nil)
        ctx.insert(note)
        #expect(note.modelContext != nil)
    }
    
    @Test func cleanupRemovesEmptyNotes() throws {
        let ctx = try makeContext()
        ctx.insert(Note(content: ""))
        ctx.insert(Note(content: "   "))
        ctx.insert(Note(content: "\n\n"))
        ctx.insert(Note(content: "Keep me"))
        try ctx.save()
        
        let all = try ctx.fetch(FetchDescriptor<Note>())
        for note in all where note.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            ctx.delete(note)
        }
        try ctx.save()
        
        let remaining = try ctx.fetch(FetchDescriptor<Note>())
        #expect(remaining.count == 1)
        #expect(remaining.first?.content == "Keep me")
    }
    
    @Test func favoritesFilterIsolatesCorrectNotes() throws {
        let ctx = try makeContext()
        ctx.insert(Note(content: "Regular 1"))
        ctx.insert(Note(content: "Starred",  isFavorite: true))
        ctx.insert(Note(content: "Regular 2"))
        try ctx.save()
        
        let favorites = try ctx.fetch(FetchDescriptor<Note>()).filter(\.isFavorite)
        #expect(favorites.count == 1)
        #expect(favorites.first?.content == "Starred")
    }
    
    @Test func favoritesFloatToTopInMixedSort() throws {
        let ctx = try makeContext()
        ctx.insert(Note(content: "Regular",  modifiedAt: Date(timeIntervalSinceNow:  -10)))
        ctx.insert(Note(content: "Favorite", modifiedAt: Date(timeIntervalSinceNow: -100), isFavorite: true))
        try ctx.save()
        
        let all = try ctx.fetch(FetchDescriptor<Note>(sortBy: [SortDescriptor(\Note.modifiedAt, order: .reverse)]))
        let sorted = all.sorted { $0.isFavorite && !$1.isFavorite }
        // Favorite appears first even though it was modified earlier.
        #expect(sorted.first?.content == "Favorite")
    }
    
    @Test func multipleNotesHaveDistinctIdentifiers() throws {
        let ctx = try makeContext()
        ctx.insert(Note(content: "Note A"))
        ctx.insert(Note(content: "Note B"))
        try ctx.save()
        
        let fetched = try ctx.fetch(FetchDescriptor<Note>())
        #expect(fetched[0].id != fetched[1].id)
    }
}
