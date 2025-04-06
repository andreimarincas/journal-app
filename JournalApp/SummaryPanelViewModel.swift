//
//  SummaryPanelViewModel.swift
//  JournalApp
//
//  Created by Andrei Marincas on 06.04.2025.
//

import Foundation

class SummaryPanelViewModel: ObservableObject {
    @Published var summaryText: String = ""
    @Published var isSummarizing: Bool = false
    private let gptClient: GPTClient
    private var entry: JournalEntry
    private var lastSummarizedEntryID: UUID?
    private var debounceWorkItem: DispatchWorkItem?

    init(entry: JournalEntry, gptClient: GPTClient = GPTClientProvider.shared) {
        self.gptClient = gptClient
        self.entry = entry
    }

    func summarizeNotes() {
        isSummarizing = true
        Task {
            do {
                let notesText = entry.notes.map { $0.text }.joined(separator: "\n\n")
                let summary = try await gptClient.summarizeEntry(notes: notesText)
                await MainActor.run {
                    self.summaryText = summary
                    self.lastSummarizedEntryID = entry.id
                    self.isSummarizing = false
                }
            } catch {
                await MainActor.run {
                    self.summaryText = "⚠️ Error generating summary: \(error.localizedDescription)"
                    self.isSummarizing = false
                }
            }
        }
    }

    func updateEntry(_ newEntry: JournalEntry) {
        self.entry = newEntry
    }

    func maybeSummarize() {
        guard entry.id != lastSummarizedEntryID else { return }

        debounceWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.summarizeNotes()
        }
        debounceWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: workItem)
    }
}
