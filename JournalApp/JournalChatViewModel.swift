//
//  JournalChatViewModel.swift
//  JournalApp
//
//  Created by Andrei Marincas on 07.04.2025.
//

import Foundation

@MainActor
class JournalChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = [
        ChatMessage(text: "Hi, how are you feeling today?", isUser: false),
        ChatMessage(text: "Would you like to explore a thought or memory?", isUser: false)
    ]
    @Published var isTyping = false

    private let gptClient = GPTClientProvider.shared

    func insertUserMessage(_ text: String, context: ChatNoteContext?, pinnedNoteID: UUID?) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        messages.append(ChatMessage(text: trimmed, isUser: true))
        sendToGPT(context: context, pinnedNoteID: pinnedNoteID)
    }

    func sendToGPT(context: ChatNoteContext?, pinnedNoteID: UUID?) {
        Task {
            var gptMessages: [GPTMessage] = []

            if let context = context, context.entryNotes.count > 1 {
                let allNotes = context.entryNotes.enumerated().map { "\($0 + 1). \($1)" }.joined(separator: "\n")
                let systemPrompt = """
                You are talking to someone who just wrote this journal entry:

                \(allNotes)

                They’ve selected note #\(context.noteIndex + 1):
                “\(context.userMessage)”

                These notes may contain emotional symbols or memories. Feel free to reference earlier notes if they relate.
                Respond warmly and reflectively, with awareness of the full entry, but focusing on that selected note.
                """
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
}
