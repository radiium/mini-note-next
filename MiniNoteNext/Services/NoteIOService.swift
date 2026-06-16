import AppKit
import os
import SwiftData
import UniformTypeIdentifiers

@MainActor
struct NoteIOService {
    
    // MARK: - Export
    
    static func exportNotes(_ notes: [Note]) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = String(localized: "action.export")
        guard panel.runModal() == .OK, let folder = panel.url else { return }
        
        var exported = 0
        var failed = 0
        for note in notes {
            let url = destinationURL(for: note, in: folder)
            do {
                try note.content.write(to: url, atomically: true, encoding: .utf8)
                exported += 1
            } catch {
                failed += 1
            }
        }
        
        if failed == 0 {
            showAlert(
                title: String(localized: "export.success.title"),
                message: String(localized: "export.success.message \(exported)")
            )
        } else {
            showAlert(
                title: String(localized: "export.partial.title"),
                message: String(localized: "export.partial.message \(exported) \(failed)")
            )
        }
    }
    
    // MARK: - Import
    
    static func importNotes(into context: ModelContext) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        panel.allowedContentTypes = importTypes
        panel.prompt = String(localized: "action.import")
        guard panel.runModal() == .OK else { return }
        
        let maxBytes = 1 * 1024 * 1024 // 1 MB
        var imported = 0
        for url in panel.urls {
            guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
                  let size = attrs[.size] as? Int, size <= maxBytes else { continue }
            guard let content = try? String(contentsOf: url, encoding: .utf8) else { continue }
            context.insert(Note(content: content))
            imported += 1
        }
        do {
            try context.save()
        } catch {
            os_log(.error, "importNotes save failed: %{public}@", error.localizedDescription)
        }
        
        showAlert(
            title: String(localized: "import.success.title"),
            message: String(localized: "import.success.message \(imported)")
        )
    }
    
    // MARK: - Private
    
    private static let importTypes: [UTType] = [.plainText]
    
    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
    
    private static func showAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    private static func destinationURL(for note: Note, in folder: URL) -> URL {
        let firstLine = note.content
            .split(separator: "\n", omittingEmptySubsequences: true)
            .first
            .map(String.init) ?? "note"
        let safeTitle = firstLine
            .components(separatedBy: CharacterSet(charactersIn: "/:\\*?\"<>|"))
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let base = "\(safeTitle.isEmpty ? "note" : safeTitle)-\(dateFormatter.string(from: note.modifiedAt))"
        
        var url = folder.appendingPathComponent(base).appendingPathExtension("txt")
        var counter = 2
        while FileManager.default.fileExists(atPath: url.path) {
            url = folder.appendingPathComponent("\(base)-\(counter)").appendingPathExtension("txt")
            counter += 1
        }
        return url
    }
}
