//
//  JournalModels.swift
//  JournalApp
//
//  Created by Andrei Marincas on 01.04.2025.
//

import Foundation
import SwiftData

@Model
final class JournalEntry {
    var id: UUID
    var date: Date
    @Attribute var title: String
    var notes: [JournalNote]

    init(id: UUID = UUID(), date: Date = .now, title: String = "", notes: [JournalNote] = []) {
        self.id = id
        self.date = date
        self.title = title
        self.notes = notes
    }
}

@Model
class JournalNote {
    var id: UUID
    var number: Int
    var text: String
    var entry: JournalEntry

    init(id: UUID = UUID(), number: Int, text: String, entry: JournalEntry) {
        self.id = id
        self.number = number
        self.text = text
        self.entry = entry
    }
}

struct AISuggestion: Identifiable {
    let id = UUID()
    let tone: JournalTone
    let text: String
}

@Model
class ChatMessage {
    @Attribute(.unique) var id: UUID
    var text: String
    var isUser: Bool
    var isSystem: Bool
    var timestamp: Date
    var entryID: UUID?
    var timeIntervalSincePrevious: TimeInterval? = nil

    init(id: UUID = UUID(), text: String, isUser: Bool, isSystem: Bool = false, timestamp: Date = Date(), entryID: UUID? = nil) {
        self.id = id
        self.text = text
        self.isUser = isUser
        self.isSystem = isSystem
        self.timestamp = timestamp
        self.entryID = entryID
    }
}
