//
//  JournalChatViewModel.swift
//  JournalApp
//
//  Created by Andrei Marincas on 07.04.2025.
//

import Foundation
import SwiftData
import SwiftUI

@MainActor
class JournalChatViewModel: ObservableObject {
    @Published private(set) var messages: [ChatMessage] = []
    @Published var isTyping: Bool
    private var typingStartTime: Date?
    private(set) var isUsingPreviewContext: Bool
    @Published var lastGreetedEntryID: UUID?
    @Published var lastGreetingTimestamp: Date?

    private let gptClient = GPTClientProvider.shared
    private var dataSource: ChatMessageDataSource
    private let paginator = ChatPaginator()
    
    private(set) var lastAnimatedMessageID: UUID?
    
    weak var focusModel: JournalFocusModel?
    
    init(dataSource: ChatMessageDataSource, focusModel: JournalFocusModel? = nil, isPreview: Bool = false) {
        self.dataSource = dataSource
        self.focusModel = focusModel
        self.isUsingPreviewContext = isPreview
        self.isTyping = false
        self.messages = []
    }
    
    func replaceDataSource(with newDataSource: ChatMessageDataSource) {
        self.dataSource = newDataSource
        self.isUsingPreviewContext = false
        self.messages = newDataSource.fetchMessages(before: Date())
    }
    
    func loadOlderMessages() {
        paginator.fetchNextPage(using: dataSource, into: &messages)
    }
    
    func showTypingIndicator() {
        isTyping = true
        typingStartTime = Date()
    }
    
    func hideTypingIndicator(completion: (() -> Void)? = nil) {
        let minimumTypingDuration: TimeInterval = 1.2
        let elapsed = Date().timeIntervalSince(typingStartTime ?? Date())
        let remainingTime = max(0, minimumTypingDuration - elapsed)

        DispatchQueue.main.asyncAfter(deadline: .now() + remainingTime) {
            self.isTyping = false
            self.typingStartTime = nil
            completion?()
        }
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
            showTypingIndicator()
            do {
                let isDefaultTitle = title?.trimmingCharacters(in: .whitespacesAndNewlines) == "Journal Entry"
                let contextualTitle = isDefaultTitle ? nil : title

                let greeting: String
                if notes.isEmpty {
                    greeting = try await gptClient.generateGeneralChatGreeting(title: contextualTitle)
                } else {
                    greeting = try await gptClient.generateContextualChatGreeting(title: contextualTitle, notes: notes)
                }
                hideTypingIndicator { [weak self] in
                    guard let self else { return }
                    let greetingMessage = ChatMessage(text: greeting, isUser: false, entryID: entryID)
                    self.dataSource.insertMessage(greetingMessage, previousMessage: self.messages.last)
                    self.messages.append(greetingMessage)
                    self.lastAnimatedMessageID = greetingMessage.id
                    
                    self.lastGreetedEntryID = entryID
                    self.lastGreetingTimestamp = Date()
                }
            } catch {
                hideTypingIndicator { [weak self] in
                    self?.messages.append(ChatMessage(text: "Error: \(error.localizedDescription)", isUser: false))
                }
            }
        }
    }

    func clearExistingChat() {
        messages.forEach { dataSource.removeMessage($0) }
        messages.removeAll()
    }
    
    func insertSystemMessage(_ text: String) {
        let systemMessage = ChatMessage(text: text, isUser: false, isSystem: true)
        dataSource.insertMessage(systemMessage)
        messages.append(systemMessage)
    }
    
    func sendFocusedNoteToGPT(message: String, context: ChatNoteContext?, pinnedNoteID: UUID?, syncWithCanvas: Bool = false) {
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        let userMessage = ChatMessage(text: trimmed, isUser: true)
        dataSource.insertMessage(userMessage, previousMessage: messages.last)
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

            showTypingIndicator()
            do {
                let response = try await gptClient.send(messages: gptMessages)
                hideTypingIndicator { [weak self] in
                    guard let self else { return }
                    let assistantMessage = ChatMessage(text: response, isUser: false)
                    self.dataSource.insertMessage(assistantMessage, previousMessage: userMessage)
                    self.messages.append(assistantMessage)
                    self.lastAnimatedMessageID = assistantMessage.id
                    
                    if syncWithCanvas {
                        self.focusModel?.pendingCanvasMergeUserMessage = trimmed
                        self.focusModel?.pendingCanvasMergeAssistantReply = response
                    }
                }
            } catch {
                hideTypingIndicator { [weak self] in
                    self?.messages.append(ChatMessage(text: "Error: \(error.localizedDescription)", isUser: false))
                }
            }
        }
    }
    
    func sendInputUserMessage(text: String, syncWithCanvas: Bool = false) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        let userMessage = ChatMessage(text: trimmed, isUser: true)
        dataSource.insertMessage(userMessage, previousMessage: messages.last)
        messages.append(userMessage)
        
        Task {
            let gptMessages: [GPTMessage] = messages.filter { !$0.isSystem }.map {
                GPTMessage(role: $0.isUser ? "user" : "assistant", content: $0.text)
            }
            
            showTypingIndicator()
            do {
                let response = try await gptClient.send(messages: gptMessages)
                hideTypingIndicator { [weak self] in
                    guard let self else { return }
                    let assistantMessage = ChatMessage(text: response, isUser: false)
                    self.dataSource.insertMessage(assistantMessage, previousMessage: userMessage)
                    self.messages.append(assistantMessage)
                    self.lastAnimatedMessageID = assistantMessage.id
                    
                    if syncWithCanvas {
                        self.focusModel?.pendingCanvasMergeUserMessage = trimmed
                        self.focusModel?.pendingCanvasMergeAssistantReply = response
                    }
                }
            } catch {
                hideTypingIndicator { [weak self] in
                    self?.messages.append(ChatMessage(text: "Error: \(error.localizedDescription)", isUser: false))
                }
            }
        }
    }
}

final class ChatMessageDataSource {
    let modelContext: ModelContext
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    func insertMessage(_ message: ChatMessage, previousMessage: ChatMessage? = nil) {
        if let previous = previousMessage {
            message.timeIntervalSincePrevious = message.timestamp.timeIntervalSince(previous.timestamp)
        }
        modelContext.insert(message)
        do {
            try modelContext.save()
        } catch {
            fatalError(error.localizedDescription)
        }
    }
    
    func fetchMessages(before date: Date?, limit: Int = 10) -> [ChatMessage] {
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

final class ChatPaginator {
    private(set) var isFetching = false
    private(set) var hasMore = true
    private let pageSize: Int = 10

    func fetchNextPage(using dataSource: ChatMessageDataSource, into messages: inout [ChatMessage]) {
        guard !isFetching, hasMore else { return }

        isFetching = true
        let cutoff = messages.first?.timestamp ?? Date()
        let olderMessages = dataSource.fetchMessages(before: cutoff, limit: pageSize)

        if olderMessages.isEmpty || olderMessages.count < pageSize {
            hasMore = false
        }

        messages.insert(contentsOf: olderMessages, at: 0)
        isFetching = false
    }

    func reset() {
        isFetching = false
        hasMore = true
    }
}
