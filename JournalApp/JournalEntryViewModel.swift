//
//  JournalEntryViewModel.swift
//  JournalApp
//
//  Created by Andrei Marincas on 06.04.2025.
//

import Foundation

class JournalEntryViewModel: ObservableObject {
    @Published private(set) var entry: JournalEntry
    private let gptClient = GPTClientProvider.shared
    private var generateTitleTask: Task<Void, Never>?
    private var enhanceNoteTasks: [UUID: Task<Void, Never>] = [:]

    init(entry: JournalEntry) {
        self.entry = entry
    }
    
    func updateEntry(_ newEntry: JournalEntry) {
        generateTitleTask?.cancel()
        enhanceNoteTasks.values.forEach { $0.cancel() }
        enhanceNoteTasks.removeAll()
        self.entry = newEntry
    }

    func generateTitle() {
        let currentEntryId = entry.id
        generateTitleTask?.cancel()
        generateTitleTask = Task { [entry] in
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second debounce
            let fullText = entry.notes.map(\.text).joined(separator: "\n\n")
            do {
                let rawTitle = try await gptClient.generateTitle(for: fullText)
                let strippedTitle = rawTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                    .trimmingCharacters(in: CharacterSet(charactersIn: "\"“”"))
                await MainActor.run { [weak self] in
                    guard let self = self, self.entry.id == currentEntryId else { return }
                    self.entry.title = strippedTitle
                }
            } catch {
                print("Failed to generate title: \(error)")
            }
        }
    }
    
    func enhance(note: JournalNote, completion: @escaping (String?) -> Void) {
        let currentEntryID = entry.id
        let noteID = note.id
        let noteText = note.text

        enhanceNoteTasks[noteID]?.cancel()

        let task = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second debounce

            do {
                let enhancedText = try await self?.gptClient.enhanceNote(noteText)
                await MainActor.run { [weak self] in
                    guard let self = self,
                          self.entry.id == currentEntryID,
                          let enhancedText = enhancedText,
                          let index = self.entry.notes.firstIndex(where: { $0.id == noteID }) else {
                        completion(nil)
                        return
                    }
                    self.entry.notes[index].text = enhancedText
                    completion(enhancedText)
                }
            } catch {
                print("Failed to enhance note: \(error)")
                await MainActor.run { completion(nil) }
            }
        }

        enhanceNoteTasks[noteID] = task
    }
}
