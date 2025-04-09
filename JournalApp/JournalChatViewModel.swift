//
//  JournalChatViewModel.swift
//  JournalApp
//
//  Created by Andrei Marincas on 07.04.2025.
//

import Foundation
import SwiftData
import SwiftUICore

@MainActor
class JournalChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var isTyping = false
    private(set) var isUsingPreviewContext: Bool = true
    @Published var lastGreetedEntryID: UUID?
    @Published var lastGreetingTimestamp: Date?

    private let gptClient = GPTClientProvider.shared
    private var dataSource: ChatMessageDataSource
    
    init(dataSource: ChatMessageDataSource, messages: [ChatMessage] = [], isTyping: Bool = false) {
        self.dataSource = dataSource
        self.messages = messages.isEmpty ? dataSource.fetchMessages(before: Date()) : messages
        self.isTyping = isTyping
        self.isUsingPreviewContext = dataSource.modelContext.container.configurations.first?.isStoredInMemoryOnly ?? false
    }
    
    func replaceDataSource(with newDataSource: ChatMessageDataSource) {
        self.dataSource = newDataSource
        self.isUsingPreviewContext = newDataSource.modelContext.container.configurations.first?.isStoredInMemoryOnly ?? false
        self.messages = newDataSource.fetchMessages(before: Date())
    }
    
    func shouldGreet(for entryID: UUID?) -> Bool {
        let now = Date()
        guard let entryID = entryID else { return false }

        let hasAssistantMessages = messages.contains(where: { !$0.isUser && $0.entryID == entryID })

        if !hasAssistantMessages {
            return true
        }

        if lastGreetedEntryID == entryID,
           let lastGreetingTimestamp,
           now.timeIntervalSince(lastGreetingTimestamp) > 12 * 3600 {
            return true
        }

        return false
    }

    func startChat(title: String?, notes: [String], entryID: UUID?) {
        guard shouldGreet(for: entryID) else { return }

        Task {
            isTyping = true
            do {
                let isDefaultTitle = title?.trimmingCharacters(in: .whitespacesAndNewlines) == "Journal Entry"
                let contextualTitle = isDefaultTitle ? nil : title

                let greeting: String
                if notes.isEmpty {
                    greeting = try await gptClient.generateGeneralChatGreeting(title: contextualTitle)
                } else {
                    greeting = try await gptClient.generateContextualChatGreeting(title: contextualTitle, notes: notes)
                }
                let greetingMessage = ChatMessage(text: greeting, isUser: false, entryID: entryID)
                dataSource.insertMessage(greetingMessage)
                messages.append(greetingMessage)

                lastGreetedEntryID = entryID
                lastGreetingTimestamp = Date()
            } catch {
                messages.append(ChatMessage(text: "Error: \(error.localizedDescription)", isUser: false))
            }
            isTyping = false
        }
    }

    func clearExistingChat() {
        messages.forEach { dataSource.removeMessage($0) }
        messages.removeAll()
    }
    
    func sendFocusedNoteToGPT(message: String, context: ChatNoteContext?, pinnedNoteID: UUID?) {
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        let userMessage = ChatMessage(text: trimmed, isUser: true)
        dataSource.insertMessage(userMessage)
        messages.append(userMessage)
        
        Task {
            var gptMessages: [GPTMessage] = []

            if let context = context {
                let systemPrompt: String
                if context.entryNotes.count > 1 {
                    let recentNotes: [String]
                    if context.noteIndex == 0 {
                        // If the selected note is the first one, use the next 1–3 notes as context if available
                        let endIndex = min(context.entryNotes.count, context.noteIndex + 4)
                        recentNotes = Array(context.entryNotes[(context.noteIndex + 1)..<endIndex])
                    } else {
                        let startIndex = max(0, context.noteIndex - 3)
                        recentNotes = Array(context.entryNotes[startIndex..<context.noteIndex])
                    }
                    systemPrompt = GPTPrompts.noteContextChatPrompt(
                        recentNotes: recentNotes,
                        selectedNote: context.userMessage,
                        noteIndex: context.noteIndex
                    )
                } else {
                    let isDefaultTitle = context.entryTitle?.trimmingCharacters(in: .whitespacesAndNewlines) == "Journal Entry"
                    let contextualTitle = isDefaultTitle ? nil : context.entryTitle
                    systemPrompt = GPTPrompts.generalChatGreetingPromptWithTitleOnly(title: contextualTitle)
                }
                gptMessages.append(GPTMessage(role: "system", content: systemPrompt))
            }

            gptMessages.append(contentsOf: messages.filter { !$0.isSystem }.map {
                GPTMessage(role: $0.isUser ? "user" : "assistant", content: $0.text)
            })

            isTyping = true
            do {
                let response = try await gptClient.send(messages: gptMessages)
                isTyping = false
                let assistantMessage = ChatMessage(text: response, isUser: false)
                dataSource.insertMessage(assistantMessage)
                messages.append(assistantMessage)
            } catch {
                isTyping = false
                messages.append(ChatMessage(text: "Error: \(error.localizedDescription)", isUser: false))
            }
        }
    }
    
    func sendInputUserMessage(text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        let userMessage = ChatMessage(text: trimmed, isUser: true)
        dataSource.insertMessage(userMessage)
        messages.append(userMessage)
        
        Task {
            let gptMessages: [GPTMessage] = messages.filter { !$0.isSystem }.map {
                GPTMessage(role: $0.isUser ? "user" : "assistant", content: $0.text)
            }
            
            isTyping = true
            do {
                let response = try await gptClient.send(messages: gptMessages)
                isTyping = false
                let assistantMessage = ChatMessage(text: response, isUser: false)
                dataSource.insertMessage(assistantMessage)
                messages.append(assistantMessage)
            } catch {
                isTyping = false
                messages.append(ChatMessage(text: "Error: \(error.localizedDescription)", isUser: false))
            }
        }
    }
}

final class ChatMessageDataSource {
    let modelContext: ModelContext
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    func insertMessage(_ message: ChatMessage) {
        modelContext.insert(message)
        do {
            try modelContext.save()
        } catch {
            fatalError(error.localizedDescription)
        }
    }
    
    func fetchMessages(before date: Date?, limit: Int = 50) -> [ChatMessage] {
        var descriptor = FetchDescriptor<ChatMessage>(
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        if let date = date {
            descriptor.predicate = #Predicate { $0.timestamp < date }
        }
        return Array((try? modelContext.fetch(descriptor))?.reversed() ?? [])
    }
    
    func removeMessage(_ message: ChatMessage) {
        modelContext.delete(message)
    }
}
