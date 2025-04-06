//
//  SummaryPanelViewModel.swift
//  JournalApp
//
//  Created by Andrei Marincas on 06.04.2025.
//

import Foundation

class SummaryPanelViewModel: ObservableObject {
    @Published var summaryText: String = "Loading summary..."
    private let gptClient: GPTClient
    private var entry: JournalEntry
    private var lastSummarizedEntryID: UUID?

    init(entry: JournalEntry, gptClient: GPTClient = GPTClientProvider.shared) {
        self.gptClient = gptClient
        self.entry = entry
    }

    func summarizeNotes() {
        Task {
            do {
                let notesText = entry.notes.map { $0.text }.joined(separator: "\n\n")
                let summary = try await gptClient.summarizeEntry(notes: notesText)
                await MainActor.run {
                    self.summaryText = summary
                    self.lastSummarizedEntryID = entry.id
                }
            } catch {
                await MainActor.run {
                    self.summaryText = "⚠️ Error generating summary: \(error.localizedDescription)"
                }
            }
        }
    }

    func updateEntry(_ newEntry: JournalEntry) {
        self.entry = newEntry
    }

    func maybeSummarize() {
        guard entry.id != lastSummarizedEntryID else { return }
        summarizeNotes()
    }
}
