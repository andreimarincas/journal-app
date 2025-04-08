//
//  JournalChatViewModel.swift
//  JournalApp
//
//  Created by Andrei Marincas on 07.04.2025.
//

import Foundation

@MainActor
class JournalChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var isTyping = false

    private let gptClient = GPTClientProvider.shared

    func startChat() {
        Task {
            isTyping = true
            do {
                let greeting = try await gptClient.generateGeneralChatGreeting(title: nil)
                messages.append(ChatMessage(text: greeting, isUser: false))
            } catch {
                messages.append(ChatMessage(text: "Error: \(error.localizedDescription)", isUser: false))
            }
            isTyping = false
        }
    }

    func startChat(title: String?, notes: [String]) {
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
                messages.append(ChatMessage(text: greeting, isUser: false))
            } catch {
                messages.append(ChatMessage(text: "Error: \(error.localizedDescription)", isUser: false))
            }
            isTyping = false
        }
    }
    
    func clearExistingChat() {
        messages.removeAll()
    }
    
    func sendFocusedNoteToGPT(message: String, context: ChatNoteContext?, pinnedNoteID: UUID?) {
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        messages.append(ChatMessage(text: trimmed, isUser: true))
        
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

            gptMessages.append(contentsOf: messages.map {
                GPTMessage(role: $0.isUser ? "user" : "assistant", content: $0.text)
            })

            isTyping = true
            do {
                let response = try await gptClient.send(messages: gptMessages)
                isTyping = false
                messages.append(ChatMessage(text: response, isUser: false))
            } catch {
                isTyping = false
                messages.append(ChatMessage(text: "Error: \(error.localizedDescription)", isUser: false))
            }
        }
    }
    
    func sendInputUserMessage(text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        messages.append(ChatMessage(text: trimmed, isUser: true))
        
        Task {
            let gptMessages: [GPTMessage] = messages.map {
                GPTMessage(role: $0.isUser ? "user" : "assistant", content: $0.text)
            }
            
            isTyping = true
            do {
                let response = try await gptClient.send(messages: gptMessages)
                isTyping = false
                messages.append(ChatMessage(text: response, isUser: false))
            } catch {
                isTyping = false
                messages.append(ChatMessage(text: "Error: \(error.localizedDescription)", isUser: false))
            }
        }
    }
}
