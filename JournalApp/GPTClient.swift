//
//  GPTClient.swift
//  JournalApp
//
//  Created by Andrei Marincas on 05.04.2025.
//

import Foundation

struct GPTMessage: Codable {
    let role: String // "user", "assistant", or "system"
    let content: String
}

struct GPTRequest: Codable {
    let model: String
    let messages: [GPTMessage]
    let temperature: Double
}

struct GPTChoice: Codable {
    let message: GPTMessage
}

struct GPTResponse: Codable {
    let choices: [GPTChoice]
}

class GPTClient {
    private let apiKey: String
    private let endpoint = URL(string: "https://api.openai.com/v1/chat/completions")!

    init(apiKey: String) {
        self.apiKey = apiKey
    }

    func send(messages: [GPTMessage]) async throws -> String {
        let requestBody = GPTRequest(
            model: "gpt-3.5-turbo",
            messages: messages,
            temperature: 0.7
        )

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(requestBody)

        let (data, _) = try await URLSession.shared.data(for: request)

        if let raw = String(data: data, encoding: .utf8) {
            print("🔍 Raw GPT response:\n\(raw)")
        }

        do {
            let decoded = try JSONDecoder().decode(GPTResponse.self, from: data)
            return decoded.choices.first?.message.content ?? "No content in response."
        } catch {
            throw NSError(domain: "GPTClient", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Failed to decode GPT response: \(error.localizedDescription)"
            ])
        }
    }
    
    func summarizeEntry(notes: String) async throws -> String {
        let messages = [
            GPTMessage(role: "system", content:
                """
                You are a thoughtful assistant that helps users reflect on their journal entries by summarizing them in the user's own voice.
                Write in the **first person**, keeping the tone intimate and emotionally resonant.
                Preserve recurring themes, emotional undertones, and symbolic language from the notes.
                Avoid summarizing as an external narrator — write as if you are the person who wrote the notes, capturing what they might be trying to understand or say to themselves.
                """
//                       •    “Capture what I might be trying to tell myself, gently, beneath the surface of these notes.”
//                       •    “Reflect my internal emotional arc, using the same metaphors or images I used.”
            ),
            GPTMessage(role: "user", content: "Summarize the following journal entry notes:\n\n\(notes)")
        ]

        return try await send(messages: messages)
    }
    
    func generateTitle(for entryText: String) async throws -> String {
        let systemPrompt = "Generate a concise, emotionally aware title (max 10 words) for the following journal entry:"
        let messages = [
            GPTMessage(role: "system", content: systemPrompt),
            GPTMessage(role: "user", content: entryText)
        ]
        return try await send(messages: messages)
    }
    
    func enhanceNote(_ noteText: String) async throws -> String {
        let messages = [
            GPTMessage(role: "system", content:
                """
                You are a thoughtful and expressive assistant that helps users refine and elevate their journal notes.
                Enhance the clarity, emotional depth, and poetic tone of the user's note.
                Keep the note in the first person and retain its original meaning, but gently improve flow, imagery, and resonance.
                Return only the enhanced version of the note, without commentary or explanation.
                """
            ),
            GPTMessage(role: "user", content: noteText)
        ]

        return try await send(messages: messages)
    }
    
    func fetchUsage(startDate: String, endDate: String) async throws -> String {
        guard let url = URL(string: "https://api.openai.com/v1/dashboard/billing/usage?start_date=\(startDate)&end_date=\(endDate)") else {
            throw NSError(domain: "GPTClient", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid usage URL"])
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let (data, _) = try await URLSession.shared.data(for: request)

        if let raw = String(data: data, encoding: .utf8) {
            print("📊 Raw Usage Response:\n\(raw)")
        }

        guard let usageJSON = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
              let totalUsage = usageJSON["total_usage"] as? Double else {
            throw NSError(domain: "GPTClient", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to parse usage data"])
        }

        let usageInDollars = totalUsage / 100.0
        return String(format: "Current usage: $%.2f", usageInDollars)
    }
}
