//
//  CanvasMergeCoordinator.swift
//  JournalApp
//
//  Created by Andrei Marincas on 13.04.2025.
//

import Foundation

final class CanvasMergeCoordinator {
    private let gptClient: GPTClient
    
    init(gptClient: GPTClient) {
        self.gptClient = gptClient
    }

    func mergeCanvas(currentCanvas: String, userMessage: String, assistantReply: String) async throws -> String {
        let context = """
        The following is a journal entry written by the user:

        \(currentCanvas)

        The user then added a new thought in chat:

        "\(userMessage)"

        Please insert the new thought into the original journal entry in the most natural and emotionally resonant place. Do not reword or remove any existing content.
        """

        let messages = [
            GPTMessage(role: "system", content: GPTPrompts.canvasMergePrompt),
            GPTMessage(role: "user", content: context)
        ]

        return try await gptClient.send(messages: messages)
    }
}
