//
//  JournalModels.swift
//  JournalApp
//
//  Created by Andrei Marincas on 01.04.2025.
//

import Foundation
import SwiftData

@Model
class JournalEntry {
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

    init(id: UUID = UUID(), number: Int, text: String) {
        self.id = id
        self.number = number
        self.text = text
    }
}
