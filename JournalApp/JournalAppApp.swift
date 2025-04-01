//
//  JournalAppApp.swift
//  JournalApp
//
//  Created by Andrei Marincas on 01.04.2025.
//

import SwiftUI
import SwiftData

@main
struct JournalAppApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            JournalNote.self, JournalEntry.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            MainView()
                .navigationTitle("")
        }
        .modelContainer(sharedModelContainer)
    }
}
