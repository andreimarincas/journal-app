//
//  JournalEntryViewModel.swift
//  JournalApp
//
//  Created by Andrei Marincas on 06.04.2025.
//

import Foundation

class JournalEntryViewModel: ObservableObject {
    @Published var entry: JournalEntry
    private let gptClient = GPTClientProvider.shared
    private var generateTitleTask: Task<Void, Never>?

    init(entry: JournalEntry) {
        self.entry = entry
    }
    
    func updateEntry(_ newEntry: JournalEntry) {
        self.entry = newEntry
    }

    func generateTitle() {
        generateTitleTask?.cancel()
        generateTitleTask = Task { [entry] in
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second debounce
            let fullText = entry.notes.map(\.text).joined(separator: "\n\n")
            do {
                let rawTitle = try await gptClient.generateTitle(for: fullText)
                let strippedTitle = rawTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                    .trimmingCharacters(in: CharacterSet(charactersIn: "\"“”"))
                await MainActor.run {
                    self.entry.title = strippedTitle
                }
            } catch {
                print("Failed to generate title: \(error)")
            }
        }
    }
}
