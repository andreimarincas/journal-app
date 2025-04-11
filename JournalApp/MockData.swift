//
//  MockData.swift
//  JournalApp
//
//  Created by Andrei Marincas on 03.04.2025.
//

import SwiftData
import Foundation

enum MockData {
    static func insertTestEntries(into context: ModelContext) {
        let baseDate = Calendar.current.date(byAdding: .day, value: -90, to: Date())!
        var dayOffset = 0

        let entries: [(title: String, notes: [String])] = [
            // Depression phase
            ("Waking Up Empty", [
                "I opened my eyes and wished I hadn’t.",
                "Silence isn’t peace. It’s just… absence."
            ]),
            ("Grey Window", [
                "Everything outside the glass feels far away.",
                "No one would notice if I disappeared today."
            ]),
            ("Breathless Days", [
                "Breathing happens, but I don’t feel it.",
                "Time doesn’t pass. It hangs."
            ]),

            // Melancholy phase
            ("Stillness", [
                "The trees didn’t move. Neither did I.",
                "There’s a kind of safety in waiting."
            ]),
            ("Shadows on Snow", [
                "The snow melted and revealed nothing new.",
                "Even my sadness has become quiet."
            ]),
            ("A Room With Light", [
                "The light was cold, but it stayed.",
                "I didn’t close the curtains this time."
            ]),

            // Hopeful phase
            ("Blue Air", [
                "The sky wasn’t clear, but it wasn’t heavy.",
                "I walked without checking my phone."
            ]),
            ("Something Stirred", [
                "I remembered a song I liked once.",
                "My coffee tasted warm today."
            ]),
            ("Open Window", [
                "I let the air in.",
                "It felt like the morning might open too."
            ])
        ]

        for (_, entryData) in entries.enumerated() {
            let entryDate = Calendar.current.date(byAdding: .day, value: dayOffset, to: baseDate)!
            let entry = JournalEntry(date: entryDate, title: entryData.title, notes: [])
            let notes = entryData.notes.enumerated().map { idx, text in
                JournalNote(number: idx + 1, text: text, entry: entry)
            }
            entry.notes.append(contentsOf: notes)
            context.insert(entry)
            dayOffset += Int.random(in: 3...7)
        }
    }
}
