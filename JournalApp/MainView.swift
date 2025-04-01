//
//  MainView.swift
//  JournalApp
//
//  Created by Andrei Marincas on 01.04.2025.
//

import SwiftUI
import SwiftData

struct MainView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\JournalEntry.date, order: .reverse)]) private var entries: [JournalEntry]
    @State private var selectedEntry: JournalEntry?

    var body: some View {
        NavigationSplitView() {
            List(selection: $selectedEntry) {
                ForEach(entries) { entry in
                    NavigationLink(value: entry) {
                        Text(entry.title.isEmpty ? "Journal Entry" : entry.title)
                            .font(.title3)
                            .lineLimit(1)
                    }
                }
            }
            .listRowSeparator(.hidden)
            .listRowInsets(.init(top: 6, leading: 4, bottom: 6, trailing: 4))
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: addEntry) {
                        Label("New Entry", systemImage: "plus")
                    }
                }
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 220)
            .navigationDestination(for: JournalEntry.self) { entry in
                JournalEntryView(entry: entry)
            }
            .onAppear {
                if entries.isEmpty {
                    insertInitialEntry()
                }
            }
        } detail: {
            if let entry = selectedEntry {
                NavigationStack {
                    JournalEntryView(entry: entry)
                }
            } else {
                Text("Select a journal entry to view its notes.")
                    .font(.title3)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle(selectedEntry?.title.isEmpty == false ? selectedEntry!.title : "Journal Entry")
        .toolbar {
            ToolbarItem(placement: .automatic) {
                if let entry = selectedEntry {
                    HStack {
                        Spacer()
                        Text(entry.date.formatted(date: .long, time: .shortened))
                            .font(.body)
                            .italic()
                            .fontWeight(.light)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
        }
    }

    private func insertInitialEntry() {
        let notes = [
            JournalNote(number: 1, text: "Welcome to your journal."),
            JournalNote(number: 2, text: "You can add a new entry using the + button."),
            JournalNote(number: 3, text: "Each note inside an entry will be numbered.")
        ]

        let entry = JournalEntry(date: Date(), title: "Journal Entry", notes: notes)
        modelContext.insert(entry)
    }
    
    private func addEntry() {
        let newEntry = JournalEntry(date: Date(), title: "Journal Entry", notes: [])
        modelContext.insert(newEntry)
        selectedEntry = newEntry
    }
}
