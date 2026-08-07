import Foundation
import Observation

public struct HistoryEntry: Codable, Identifiable, Equatable {
    public let id: UUID
    public let date: Date
    public let fileName: String
    public let originalSize: Int64
    public let compressedSize: Int64
    public let isMovie: Bool
    public let relativePath: String // Relative to App Group container URL
    
    public var savingsBytes: Int64 {
        max(0, originalSize - compressedSize)
    }
}

@Observable
public final class HistoryManager {
    public static let shared = HistoryManager()
    
    public var entries: [HistoryEntry] = []
    
    private let groupSuiteName = "group.com.kwh.dropsize"
    private var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupSuiteName)
    }
    
    private var historyJsonURL: URL? {
        containerURL?.appendingPathComponent("history.json")
    }
    
    private var historyFolderURL: URL? {
        containerURL?.appendingPathComponent("History")
    }
    
    private init() {
        loadHistory()
    }
    
    public var totalBytesSaved: Int64 {
        entries.reduce(0) { $0 + $1.savingsBytes }
    }
    
    public var totalCompressionsCount: Int {
        entries.count
    }
    
    public func loadHistory() {
        guard let url = historyJsonURL, FileManager.default.fileExists(atPath: url.path) else {
            self.entries = []
            return
        }
        
        do {
            let data = try Data(contentsOf: url)
            let decoded = try JSONDecoder().decode([HistoryEntry].self, from: data)
            // Sort history by date descending
            self.entries = decoded.sorted(by: { $0.date > $1.date })
        } catch {
            print("HistoryManager: Failed to load history: \(error.localizedDescription)")
            self.entries = []
        }
    }
    
    public func addEntry(name: String, originalSize: Int64, compressedURL: URL, isMovie: Bool) {
        guard let folder = historyFolderURL else { return }
        
        // Create History folder if needed
        if !FileManager.default.fileExists(atPath: folder.path) {
            try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        }
        
        let fileExtension = isMovie ? "mp4" : "jpg"
        let uniqueName = "\(UUID().uuidString).\(fileExtension)"
        let destinationURL = folder.appendingPathComponent(uniqueName)
        
        do {
            // Copy file to App Group History folder
            try FileManager.default.copyItem(at: compressedURL, to: destinationURL)
            
            // Get final size of copied file
            let finalSize = try FileManager.default.attributesOfItem(atPath: destinationURL.path)[.size] as? Int64 ?? 0
            
            let relativePath = "History/\(uniqueName)"
            let entry = HistoryEntry(
                id: UUID(),
                date: Date(),
                fileName: name,
                originalSize: originalSize,
                compressedSize: finalSize,
                isMovie: isMovie,
                relativePath: relativePath
            )
            
            self.entries.insert(entry, at: 0)
            saveHistory()
        } catch {
            print("HistoryManager: Failed to add history item: \(error.localizedDescription)")
        }
    }
    
    public func deleteEntry(at indexSet: IndexSet) {
        guard let container = containerURL else { return }
        
        for index in indexSet {
            let entry = entries[index]
            let fileURL = container.appendingPathComponent(entry.relativePath)
            try? FileManager.default.removeItem(at: fileURL)
        }
        
        entries.remove(atOffsets: indexSet)
        saveHistory()
    }
    
    public func clearAll() {
        guard let folder = historyFolderURL else { return }
        
        // Delete all files in History folder
        try? FileManager.default.removeItem(at: folder)
        
        entries.removeAll()
        saveHistory()
    }
    
    private func saveHistory() {
        guard let url = historyJsonURL else { return }
        
        do {
            let data = try JSONEncoder().encode(entries)
            try data.write(to: url, options: .atomic)
        } catch {
            print("HistoryManager: Failed to save history: \(error.localizedDescription)")
        }
    }
}
