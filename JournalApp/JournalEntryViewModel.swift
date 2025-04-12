//
//  JournalEntryViewModel.swift
//  JournalApp
//
//  Created by Andrei Marincas on 06.04.2025.
//

import Foundation
import SwiftData

class JournalEntryViewModel: ObservableObject {
    @Published private(set) var entry: JournalEntry
    @Published var isGeneratingAISuggestions: Bool = false
    private let gptClient = GPTClientProvider.shared
    private var generateTitleTask: Task<Void, Never>?
    private var enhanceNoteTasks: [UUID: Task<Void, Never>] = [:]
    
    @Published var latestAISuggestions: [AISuggestion] = []
    @Published var currentAISuggestionIndex: Int = 0
    
    private var dataSource: NotesDataSource
    private(set) var isUsingPreviewContext: Bool
    @Published private(set) var notes: [JournalNote] = []
    
    init(entry: JournalEntry, dataSource: NotesDataSource, isPreview: Bool = false) {
        self.entry = entry
        self.dataSource = dataSource
        self.isUsingPreviewContext = isPreview
    }
    
    func loadNotes() {
        let fetched = dataSource.fetchNotes(for: entry)
        self.notes = fetched
        self.entry.notes = fetched
    }
    
    func replaceDataSource(with newDataSource: NotesDataSource) {
        self.dataSource = newDataSource
        self.isUsingPreviewContext = false
        loadNotes()
    }
    
    var canvasBody: String {
        notes.map { $0.text }.joined(separator: "\n")
    }
    
    func persistCanvasText(_ canvasText: String) {
        let paragraphs = canvasText
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        // Build new notes
        let updatedNotes = paragraphs.enumerated().map { index, text in
            JournalNote(
                number: index + 1,
                text: text,
                entry: entry
            )
        }

        // Replace the notes in SwiftData
        dataSource.replaceNotes(for: entry, with: updatedNotes)
        loadNotes()
    }
    
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
    
    func updateEntry(_ newEntry: JournalEntry) {
        generateTitleTask?.cancel()
        enhanceNoteTasks.values.forEach { $0.cancel() }
        enhanceNoteTasks.removeAll()
        self.entry = newEntry
        loadNotes()
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
    
    func generateAISuggestions(completion: @escaping ([AISuggestion]?) -> Void) {
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
    
    func isAINote(text: String) -> Bool {
        return text.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("✨")
    }
    
    @discardableResult
    func addNote(text: String = "") -> JournalNote {
        let newNumber = (entry.notes.map(\.number).max() ?? 0) + 1
        let newNote = JournalNote(number: newNumber, text: text, entry: entry)
        
        // Replace the last note if it is AI generated and user has not decided yet upon its tone
        if isAINote(text: newNote.text) && latestAISuggestions.contains(where: { $0.text == newNote.text }) {
            if let lastNote = notes.last, isAINote(text: lastNote.text) && latestAISuggestions.first(where: { $0.text == lastNote.text }) == nil {
                dataSource.remove(lastNote, from: entry)
                newNote.number -= 1
            }
        }
        
        dataSource.insert(newNote, into: entry)
        loadNotes()
        return newNote
    }
    
    func updateNote(_ note: JournalNote, text: String) {
        dataSource.update(note, with: text)
        loadNotes()
    }
    
    func updateNote(_ note: JournalNote, number: Int) {
        dataSource.update(note, with: number)
        loadNotes()
    }

    func deleteNote(_ noteToDelete: JournalNote) {
        dataSource.remove(noteToDelete, from: entry)
        for note in notes {
            if note.number > noteToDelete.number {
                dataSource.update(note, with: note.number - 1)
            }
        }
        loadNotes()
    }
}

final class NotesDataSource {
    let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // Fetch all notes for a given entry, sorted by note number
    func fetchNotes(for entry: JournalEntry) -> [JournalNote] {
        let entryID = entry.id
        let descriptor = FetchDescriptor<JournalNote>(
            predicate: #Predicate { note in
                note.entry.id == entryID
            },
            sortBy: [SortDescriptor(\.number)]
        )
        do {
            return try modelContext.fetch(descriptor)
        } catch {
            print("Failed to fetch notes from SwiftData: \(error)")
            return []
        }
    }

    // Insert a new note into an entry
    func insert(_ note: JournalNote, into entry: JournalEntry) {
        entry.notes.append(note)
        save()
    }

    // Remove a note from an entry and delete it from the context
    func remove(_ note: JournalNote, from entry: JournalEntry) {
        entry.notes.removeAll(where: { $0.id == note.id })
        modelContext.delete(note)
        save()

    }

    // Update the text of a given note
    func update(_ note: JournalNote, with text: String) {
        note.text = text
        save()
    }
    
    // Update the number of a given note
    func update(_ note: JournalNote, with number: Int) {
        note.number = number
        save()
    }

    // Replace all notes in an entry with a new list of paragraph-based notes
    func replaceAllNotes(in entry: JournalEntry, with paragraphs: [String]) {
        entry.notes.removeAll()
        for (index, paragraph) in paragraphs.enumerated() {
            let newNote = JournalNote(number: index + 1, text: paragraph, entry: entry)
            entry.notes.append(newNote)
        }
        save()
    }
    
    func replaceNotes(for entry: JournalEntry, with newNotes: [JournalNote]) {
        do {
            let entryID = entry.id
            try modelContext.transaction {
                // Delete old notes
                let request = FetchDescriptor<JournalNote>(
                    predicate: #Predicate { $0.entry.id == entryID }
                )
                let existingNotes = try modelContext.fetch(request)
                for note in existingNotes {
                    modelContext.delete(note)
                }

                // Add new ones
                for note in newNotes {
                    note.entry = entry
                    modelContext.insert(note)
                    entry.notes.append(note)
                }
            }
        } catch {
            print("Failed to replace notes: \(error)")
        }
    }

    // Save helper
    private func save() {
        do {
            try modelContext.save()
        } catch {
            fatalError("Failed to save notes: \(error.localizedDescription)")
        }
    }
}
