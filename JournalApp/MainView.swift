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
    @State private var justAddedEntryID: UUID?

    var body: some View {
        navigationSplitView
    }

    private var navigationSplitView: some View {
        NavigationSplitView {
            ScrollViewReader { proxy in
                sidebarView(proxy: proxy)
            }.background(Color("SidebarBackground"))
        } detail: {
            detailView
                .navigationDestination(for: JournalEntry.self) { entry in
                    JournalEntryView(entry: entry)
                }
        }
        .navigationTitle(selectedEntry?.title.isEmpty == false ? selectedEntry!.title : "Journal Entry")
//        .navigationSubtitle(selectedEntry?.date.formatted(date: .long, time: .shortened) ?? "")
        /*.toolbar {
            ToolbarItem(placement: .automatic) {
                if let entry = selectedEntry {
                    HStack {
                        Spacer()
                        Text("Entry date:")
                            .fontWeight(.medium)
                        Text(entry.date.formatted(date: .long, time: .shortened))
                            .fontWeight(.light)
                    }
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
        }*/
    }

    @ViewBuilder
    private func sidebarView(proxy: ScrollViewProxy) -> some View {
        List(selection: $selectedEntry) {
            ForEach(entries) { entry in
                NavigationLink(value: entry) {
                    entryLabel(for: entry)
                }
                .id(entry.id)
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
        .onChange(of: selectedEntry) { _, _ in
            if let entry = selectedEntry, justAddedEntryID == entry.id {
                proxy.scrollTo(entry.id, anchor: .top)
                justAddedEntryID = nil
            }
        }
        .scrollContentBackground(.hidden)
        .scrollIndicators(.hidden, axes: .horizontal)
        .background(Color("SidebarBackground"))
        .listStyle(.inset)
        .listRowSeparator(.visible)
        .listRowInsets(.init(top: 6, leading: 12, bottom: 6, trailing: 8))
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: addEntry) {
                    Label("New Entry", systemImage: "square.and.pencil")
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            HStack {
                Spacer()
                Text("\(entries.count) entr\(entries.count == 1 ? "y" : "ies")")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, 6)
            .padding(.bottom, 8)
            .background(Color("SidebarBackground"))
        }
        .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 220)
        .onAppear {
            if entries.isEmpty {
                insertInitialEntry()
            }
        }
    }

    @ViewBuilder
    private var detailView: some View {
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
                        Text("Click the + button to create your first entry.")
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
                    VStack(spacing: 16) {
                        Image(systemName: "book")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text("Select a Journal Entry")
                            .font(.title3)
                            .fontWeight(.semibold)
                        Text("Choose one from the list to view its notes.")
                            .foregroundColor(.secondary)
                    }
                    .multilineTextAlignment(.center)
                }
            }
        }
        .id(UUID())
    }

    @ViewBuilder
    private func entryLabel(for entry: JournalEntry) -> some View {
        if renamingEntry == entry {
            let titleBinding = Binding<String>(
                get: { entry.title },
                set: { newValue in entry.title = newValue }
            )
            VStack(alignment: .leading, spacing: 2) {
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
                Spacer().frame(height: 28)
            }
        } else {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.title.isEmpty ? "Journal Entry" : entry.title)
                        .font(.title3)
                        .lineLimit(1)
                    if let firstNote = entry.notes.first(where: { $0.number == 1 }) {
                        Text(firstNote.text)
                            .font(.subheadline)
                            .italic()
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    HStack {
                        Spacer()
                        Text(entry.date.formatted(date: .abbreviated, time: .omitted))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }
            // Remove double-click to rename for now because it interferes with entry selection and navigation
//            .onTapGesture(count: 2) {
//                renamingEntry = entry
//            }
        }
    }

    private func insertInitialEntry() {
        let notes = [
            JournalNote(number: 1, text: "Welcome to your journal."),
            JournalNote(number: 2, text: "You can add a new entry using the + button."),
            JournalNote(number: 3, text: "Each note inside an entry will be numbered."),
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
            justAddedEntryID = newEntry.id
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
