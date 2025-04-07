//
//  JournalEntryViewModel.swift
//  JournalApp
//
//  Created by Andrei Marincas on 06.04.2025.
//

import Foundation

class JournalEntryViewModel: ObservableObject {
    @Published private(set) var entry: JournalEntry
    @Published var isGeneratingAISuggestions: Bool = false
    private let gptClient = GPTClientProvider.shared
    private var generateTitleTask: Task<Void, Never>?
    private var enhanceNoteTasks: [UUID: Task<Void, Never>] = [:]
    
    @Published var latestAISuggestions: [AISuggestion] = []
    @Published var currentAISuggestionIndex: Int = 0

    var currentAISuggestion: AISuggestion? {
        latestAISuggestions.indices.contains(currentAISuggestionIndex)
            ? latestAISuggestions[currentAISuggestionIndex]
            : nil
    }

    func cycleAISuggestion(inReverse: Bool = false) {
        guard !latestAISuggestions.isEmpty else { return }
        if inReverse {
            currentAISuggestionIndex = (currentAISuggestionIndex - 1 + latestAISuggestions.count) % latestAISuggestions.count
        } else {
            currentAISuggestionIndex = (currentAISuggestionIndex + 1) % latestAISuggestions.count
        }
    }
    
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
    
    func generateAISuggestions(for entry: JournalEntry, completion: @escaping ([AISuggestion]?) -> Void) {
        isGeneratingAISuggestions = true
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second debounce
            guard let self else { return }
            do {
                let recentNotes = Array(entry.notes.suffix(3)).map(\.text)
                let suggestions = try await self.gptClient.generateNewNotes(basedOn: recentNotes)
                await MainActor.run {
                    var aiSuggestions: [AISuggestion] = []
                    for (index, tone) in JournalTone.allCases.enumerated() {
                        guard suggestions.indices.contains(index) else { continue }
                        let aiSuggestion = AISuggestion(tone: tone, text: "✨ " + suggestions[index])
                        aiSuggestions.append(aiSuggestion)
                    }
                    self.latestAISuggestions = aiSuggestions
                    self.currentAISuggestionIndex = 0
                    self.isGeneratingAISuggestions = false
                    completion(aiSuggestions)
                }
            } catch {
                print("Failed to generate AI suggestions: \(error)")
                await MainActor.run {
                    self.isGeneratingAISuggestions = false
                    completion(nil)
                }
            }
        }
    }
}
