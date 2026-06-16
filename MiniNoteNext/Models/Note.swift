import Foundation
import SwiftData

@Model
final class Note {
    var content: String
    var createdAt: Date
    var modifiedAt: Date
    var isFavorite: Bool
    
    var isEmpty: Bool {
        content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    var title: String {
        content.split(separator: "\n", omittingEmptySubsequences: false)
            .first { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            .map(String.init) ?? String(localized: "note.untitled")
    }
    
    init(content: String = "", createdAt: Date = .now, modifiedAt: Date = .now, isFavorite: Bool = false) {
        self.content = content
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.isFavorite = isFavorite
    }
    
    func toggleFavorite() {
        isFavorite.toggle()
        modifiedAt = .now
    }
    
    func tooltipContent(maxLength: Int = 200) -> String {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > maxLength else { return trimmed }
        return String(trimmed.prefix(maxLength)) + "…"
    }
}
