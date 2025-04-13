//
//  MainView.swift
//  JournalApp
//
//  Created by Andrei Marincas on 01.04.2025.
//

import SwiftUI
import SwiftData
import AppKit
import Combine

struct ChatNoteContext {
    let entryNotes: [String]
    let entryTitle: String?
    let noteIndex: Int
    let userMessage: String
}

struct MainView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\JournalEntry.date, order: .reverse)]) private var entries: [JournalEntry]
    @State private var selectedEntry: JournalEntry?
    @State private var renamingEntry: JournalEntry?
    @FocusState private var isRenamingFocused: Bool
    @State private var justAddedEntryID: UUID?
    @State private var focusModel = JournalFocusModel()
    @State private var entryToDelete: JournalEntry?
    @State private var summaryPanelWidth: CGFloat = 350
    @State private var chatPanelWidth: CGFloat = 400
    @State private var isChatPoppedOut: Bool = false
    @State private var poppedOutWindow: NSWindow?
    @State private var isSummaryPanelVisible: Bool = false
    @State private var undoManagers: [UUID: CustomUndoManager] = [:]
    
    @StateObject private var summaryViewModel = SummaryPanelViewModel(entry: JournalEntry(date: Date(), title: "", notes: []))
    
    @StateObject private var entryViewModel: JournalEntryViewModel = {
        // Preview fallback with in-memory modelContext
        let schema = Schema([ChatMessage.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: schema, configurations: [config])
        return JournalEntryViewModel(
            entry: JournalEntry(date: Date(), title: "", notes: []),
            dataSource: NotesDataSource(modelContext: container.mainContext),
            isPreview: true
        )
    }()
    
    @StateObject private var chatViewModel: JournalChatViewModel = {
        // Preview fallback with in-memory modelContext
        let schema = Schema([ChatMessage.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: schema, configurations: [config])
        return JournalChatViewModel(dataSource: ChatMessageDataSource(modelContext: container.mainContext), isPreview: true)
    }()
    
    @AppStorage("chatPanelWidth") private var chatPanelWidthRaw: Double = 300
    @AppStorage("isChatVisible") private var isChatVisible: Bool = true
    
    var body: some View {
        navigationSplitView
            .onAppear {
                DispatchQueue.main.async {
                    if entryViewModel.isUsingPreviewContext {
                        entryViewModel.replaceDataSource(with: NotesDataSource(modelContext: modelContext))
                        focusModel.entryViewModel = entryViewModel
                    }
                    if chatViewModel.isUsingPreviewContext {
                        chatViewModel.replaceDataSource(with: ChatMessageDataSource(modelContext: modelContext))
                        chatViewModel.focusModel = focusModel
                    }
                }
            }
    }
    
    private var navigationSplitView: some View {
        NavigationSplitView {
            ScrollViewReader { proxy in
                sidebarView(proxy: proxy)
            }.background(Color("SidebarBackground"))
        } detail: {
            detailView
                .background(Color("DetailViewBackground"))
                .overlay(alignment: .trailing) {
                    if isSummaryPanelVisible {
                        SummaryPanel(viewModel: summaryViewModel)
                            .frame(width: summaryPanelWidth)
                            .background(Color("SummaryPanelBackground"))
                            .transition(.move(edge: .trailing))
                            .onAppear {
                                isSummaryPanelVisible = true
                            }
                            .onDisappear {
                                isSummaryPanelVisible = false
                            }
                            .overlay(alignment: .leading) {
                                Rectangle()
                                    .fill(Color.clear)
                                    .frame(width: 6)
                                    .background(Color("SummaryPanelBackground"))
                                    .gesture(
                                        DragGesture(minimumDistance: 5)
                                            .onChanged { value in
                                                let newWidth = summaryPanelWidth + (-value.translation.width)
                                                summaryPanelWidth = min(max(newWidth, 300), 600)
                                            }
                                    )
                                    .offset(x: -3)
                                    .onHover { hovering in
                                        if hovering {
                                            NSCursor.resizeLeftRight.push()
                                        } else {
                                            NSCursor.pop()
                                        }
                                    }
                            }
                    }
                }
                .animation(.easeInOut(duration: 0.2), value: isSummaryPanelVisible)
        }
        .navigationTitle(selectedEntry?.title.isEmpty == false ? selectedEntry!.title : "Journal Entry")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    isSummaryPanelVisible.toggle()
                } label: {
                    Label("AI Summary", systemImage: "doc.text.magnifyingglass")
                }
            }
        }
    }
    
    private var addEntryButton: some View {
        Button(action: addEntry) {
            Label("New Entry", systemImage: "square.and.pencil")
                .foregroundColor(.primary)
        }
    }
    
    private var numberOfEntriesLabel: some View {
        HStack {
            Spacer()
            Text("\(entries.count) entr\(entries.count == 1 ? "y" : "ies")")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 2)
        .padding(.bottom, 26)
        .background(Color("SidebarBackground"))
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
                        entryToDelete = entry
                    }
                }
            }
        }
        .onChange(of: selectedEntry) { oldEntry, newEntry in
            if let entry = selectedEntry, justAddedEntryID == entry.id {
                proxy.scrollTo(entry.id, anchor: .top)
                justAddedEntryID = nil
            }
            focusModel.entry = selectedEntry
            focusModel.focusedNoteID = nil
            focusModel.clearChatFocus()
            if let newEntry {
                entryViewModel.updateEntry(newEntry)
                summaryViewModel.updateEntry(newEntry)
                if isSummaryPanelVisible {
                    summaryViewModel.maybeSummarize()
                }
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
                addEntryButton
            }
        }
        .alert("Delete this entry?", isPresented: Binding(
            get: { entryToDelete != nil },
            set: { if !$0 { entryToDelete = nil } }
        )) {
            Button("Delete", role: .destructive) {
                if let entry = entryToDelete {
                    deleteEntry(entry)
                }
                entryToDelete = nil
            }
            Button("Cancel", role: .cancel) {
                entryToDelete = nil
            }
        } message: {
            Text("This will permanently delete the entry and its notes.")
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            numberOfEntriesLabel
        }
        .navigationSplitViewColumnWidth(min: 300, ideal: 400, max: 500)
        .onAppear {
            if chatPanelWidthRaw == 0 {
                chatPanelWidthRaw = 300
            }
            chatPanelWidth = CGFloat(chatPanelWidthRaw)
#if DEBUG
            if entries.isEmpty {
                MockData.insertTestEntries(into: modelContext)
            }
#endif
            DispatchQueue.main.async {
                selectedEntry = entries.first
                if let entry = selectedEntry {
                    summaryViewModel.updateEntry(entry)
                }
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
                GeometryReader { geometry in
                    HStack(spacing: 0) {
                        ZStack(alignment: .topTrailing) {
                            JournalEntryView(
                                viewModel: entryViewModel,
                                isSummaryPanelVisible: $isSummaryPanelVisible,
                                isChatVisible: $isChatVisible,
                                canvasUndoManager: undoManagers[entry.id, default: {
                                    let manager = CustomUndoManager()
                                    undoManagers[entry.id] = manager
                                    return manager
                                }()]
                            )
                            .environmentObject(focusModel)
                        }
                        
                        if !isChatPoppedOut && isChatVisible {
                            ZStack {
                                // Drag area
                                Color.clear
                                    .contentShape(Rectangle())
                                    .frame(width: 16)
                                    .gesture(
                                        DragGesture(minimumDistance: 5)
                                            .onChanged { value in
                                                let maxAllowed = geometry.size.width / 2
                                                chatPanelWidth = max(320, min(chatPanelWidth - value.translation.width, maxAllowed))
                                                chatPanelWidthRaw = Double(chatPanelWidth)
                                            }
                                    )
                                    .onHover { hovering in
                                        if hovering {
                                            NSCursor.resizeLeftRight.push()
                                        } else {
                                            NSCursor.pop()
                                        }
                                    }
                                
                                // Visible divider
                                Rectangle()
                                    .fill(Color("ChatNotesSeparator"))
                                    .frame(width: 1)
                            }
                            
                            JournalChatView(chatViewModel: chatViewModel, entry: entry, isInOwnWindow: $isChatPoppedOut, isChatVisible: $isChatVisible, popOutWindow: {
                                self.isChatPoppedOut = true
                            }, isSummaryPanelVisible: $isSummaryPanelVisible).environmentObject(focusModel)
                                .frame(width: chatPanelWidth)
                                .background(Color("ChatViewBackground"))
                                .transition(.move(edge: .trailing))
                        }
                    }
                    .animation(.easeInOut(duration: 0.2), value: isChatVisible)
                    .onChange(of: isChatPoppedOut) { _, poppedOut in
                        if poppedOut {
                            let window = NSWindow(
                                contentRect: NSRect(x: 0, y: 0, width: 500, height: 600),
                                styleMask: [.titled, .closable, .resizable],
                                backing: .buffered,
                                defer: false
                            )
                            window.title = "AI Companion"
                            window.contentView = NSHostingView(rootView: JournalChatView(chatViewModel: chatViewModel, entry: entry, isInOwnWindow: $isChatPoppedOut))
                            window.isReleasedWhenClosed = false
                            window.makeKeyAndOrderFront(nil)
                            poppedOutWindow = window
                            
                            NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: window, queue: .main) { _ in
                                isChatPoppedOut = false
                            }
                        } else {
                            poppedOutWindow?.close()
                            poppedOutWindow = nil
                        }
                    }
                }
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
        //.id(UUID()) // comment out the id addition because it reloads the view too often and interferes with editing note
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
                    .onExitCommand {
                        renamingEntry = nil
                    }
                Spacer().frame(height: 28)
            }
        } else {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.title.isEmpty ? "Journal Entry" : entry.title)
                        .font(.headline)
                        .fontWeight(.regular)
                        .lineLimit(1)
                    Text(entry.notes.first(where: { $0.number == 1 })?.text ?? " ")
                        .font(.subheadline)
                        .italic()
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    HStack {
                        Spacer()
                        Text(entry.date.formatted(date: .abbreviated, time: .omitted))
                            .font(.caption2)
                            .foregroundColor(.secondary.opacity(0.6))
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
    
    private func addEntry() {
        let newEntryID = UUID()
        let newEntry = JournalEntry(id: newEntryID, date: Date(), title: "Journal Entry", notes: [])
        modelContext.insert(newEntry)
        DispatchQueue.main.async {
            selectedEntry = newEntry
            justAddedEntryID = newEntry.id
            focusModel.focusedNoteID = nil
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
