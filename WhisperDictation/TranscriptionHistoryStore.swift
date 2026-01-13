//
//  TranscriptionHistoryStore.swift
//  WhisperDictation
//
//  Lightweight transcription history storage.
//

import Foundation

final class TranscriptionHistoryStore: ObservableObject {
    struct Item: Identifiable, Codable, Equatable {
        let id: UUID
        let text: String
        let timestamp: Date
    }
    
    static let shared = TranscriptionHistoryStore()
    
    @Published private(set) var items: [Item] = []
    
    private let maxItems = 5
    private let fileURL: URL
    
    private init() {
        let applicationSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        let directory = applicationSupport?.appendingPathComponent("WhisperDictation", isDirectory: true)
        fileURL = directory?.appendingPathComponent("transcription_history.json") ??
        FileManager.default.temporaryDirectory.appendingPathComponent("transcription_history.json")
        load()
    }
    
    func add(text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        let newItem = Item(id: UUID(), text: trimmed, timestamp: Date())
        items.insert(newItem, at: 0)
        if items.count > maxItems {
            items = Array(items.prefix(maxItems))
        }
        save()
    }
    
    private func load() {
        do {
            let data = try Data(contentsOf: fileURL)
            let decoded = try JSONDecoder().decode([Item].self, from: data)
            items = Array(decoded.prefix(maxItems))
        } catch {
            items = []
        }
    }
    
    private func save() {
        do {
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(items)
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            print("[TranscriptionHistoryStore] Failed to save history: \(error)")
        }
    }
}
