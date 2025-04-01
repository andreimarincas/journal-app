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
    @State private var renamingEntry: JournalEntry?
    @FocusState private var isRenamingFocused: Bool

    var body: some View {
        NavigationSplitView() {
            List(selection: $selectedEntry) {
                ForEach(entries) { entry in
                    NavigationLink(value: entry) {
                        entryLabel(for: entry)
                    }
                    .contextMenu {
                        Button("Rename") {
                            renamingEntry = entry
                        }
                        Button("Delete", role: .destructive) {
                            deleteEntry(entry)
                        }
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
            .onAppear {
                if entries.isEmpty {
                    insertInitialEntry()
                }
            }
        } detail: {
            Group {
                if entries.isEmpty {
                    ZStack {
                        Color(nsColor: .windowBackgroundColor)
                            .ignoresSafeArea()
                        VStack(spacing: 16) {
                            Image(systemName: "book.closed")
                                .font(.system(size: 48))
                                .foregroundColor(.secondary)
                            Text("No journal entries yet.")
                                .font(.title3)
                                .fontWeight(.semibold)
                            Text("Click the + button above to create your first entry.")
                                .foregroundColor(.secondary)
                            Button {
                                addEntry()
                            } label: {
                                Label("Create a New Entry", systemImage: "plus")
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(Color.accentColor)
                                    .foregroundColor(.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            .buttonStyle(.plain)
                        }
                        .multilineTextAlignment(.center)
                    }
                } else if let entry = selectedEntry {
                    JournalEntryView(entry: entry)
                } else {
                    ZStack {
                        Color(nsColor: .windowBackgroundColor)
                            .ignoresSafeArea()
                        Text("Select a journal entry to view its notes.")
                            .font(.title3)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
            .id(UUID())
        }
        .navigationTitle(selectedEntry?.title.isEmpty == false ? selectedEntry!.title : "Journal Entry")
        .toolbar {
            ToolbarItem(placement: .automatic) {
                if let entry = selectedEntry {
                    HStack {
                        Spacer()
                        Text("Entry date: " + entry.date.formatted(date: .long, time: .shortened))
                            .font(.body)
                            .fontWeight(.light)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
        }
        .navigationDestination(for: JournalEntry.self) { entry in
            JournalEntryView(entry: entry)
        }
    }

    @ViewBuilder
    private func entryLabel(for entry: JournalEntry) -> some View {
        if renamingEntry == entry {
            let titleBinding = Binding<String>(
                get: { entry.title },
                set: { newValue in entry.title = newValue }
            )
            TextField("Title", text: titleBinding)
                .textFieldStyle(.plain)
                .font(.title3)
                .focused($isRenamingFocused)
                .onAppear {
                    isRenamingFocused = true
                }
                .onSubmit {
                    renamingEntry = nil
                }
        } else {
            ZStack {
                HStack {
                    Text(entry.title.isEmpty ? "Journal Entry" : entry.title)
                        .font(.title3)
                        .lineLimit(1)
                    Spacer()
                }
                VStack {
                    Rectangle()
                        .foregroundColor(.clear)
                        .border(Color.clear, width: 0)
                        .contentShape(Rectangle())
                        .onTapGesture(count: 2) {
                            renamingEntry = entry
                        }
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
        DispatchQueue.main.async {
            selectedEntry = entry
        }
    }
    
    private func addEntry() {
        let notes = [
            JournalNote(number: 1, text: "This is your new journal entry."),
            JournalNote(number: 2, text: "You can write freely here.\nMultiple lines work just fine."),
            JournalNote(number: 3, text: "Each note is numbered and can hold as much text as you want, and if longer it will word wrap to fit the screen.")
        ]
        let newEntry = JournalEntry(date: Date(), title: "Journal Entry", notes: notes)
        modelContext.insert(newEntry)
        DispatchQueue.main.async {
            selectedEntry = newEntry
        }
    }
    
    private func deleteEntry(_ entry: JournalEntry) {
        if let currentIndex = entries.firstIndex(of: entry) {
            modelContext.delete(entry)
            DispatchQueue.main.async {
                if entries.isEmpty {
                    selectedEntry = nil
                } else if entries.indices.contains(currentIndex) {
                    selectedEntry = entries[currentIndex]
                } else {
                    selectedEntry = entries.last
                }
            }
        }
    }
}
