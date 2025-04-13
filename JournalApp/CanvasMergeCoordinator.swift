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
        --- Canvas ---
        \(currentCanvas)

        --- New Message ---
        \(userMessage)
        """

        let messages = [
            GPTMessage(role: "system", content: GPTPrompts.canvasMergePrompt),
            GPTMessage(role: "user", content: context)
        ]

        return try await gptClient.send(messages: messages)
    }
}
