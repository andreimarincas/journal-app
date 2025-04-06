//
//  MainView.swift
//  JournalApp
//
//  Created by Andrei Marincas on 01.04.2025.
//

import SwiftUI
import SwiftData
import AppKit

class JournalFocusModel: ObservableObject {
    @Published var focusedNoteID: UUID?
    weak var entry: JournalEntry?
}

struct MainView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\JournalEntry.date, order: .reverse)]) private var entries: [JournalEntry]
    @State private var selectedEntry: JournalEntry?
    @State private var renamingEntry: JournalEntry?
    @FocusState private var isRenamingFocused: Bool
    @State private var justAddedEntryID: UUID?
    @StateObject private var focusModel = JournalFocusModel()
    @State private var entryToDelete: JournalEntry?
    @State private var isAISummaryPanelVisible = false
    @State private var summaryPanelWidth: CGFloat = 350
    @AppStorage("chatPanelWidth") private var chatPanelWidthRaw: Double = 400
    @State private var chatPanelWidth: CGFloat = 400
    @AppStorage("isChatVisible") private var isChatVisible: Bool = true
    @State private var isShowChatHovering = false
    @State private var isChatPoppedOut: Bool = false
    @State private var poppedOutWindow: NSWindow?

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
                .background(Color("DetailViewBackground"))
                .overlay(alignment: .trailing) {
                    if isAISummaryPanelVisible {
                        AISummaryPanel()
                            .frame(width: summaryPanelWidth)
                            .background(Color("AIPanelBackground"))
                            .transition(.move(edge: .trailing))
                            .overlay(alignment: .leading) {
                                Rectangle()
                                    .fill(Color.clear)
                                    .frame(width: 6)
                                    .background(Color("AIPanelBackground"))
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
                .animation(.easeInOut(duration: 0.2), value: isAISummaryPanelVisible)
        }
        .navigationTitle(selectedEntry?.title.isEmpty == false ? selectedEntry!.title : "Journal Entry")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    isAISummaryPanelVisible.toggle()
                } label: {
                    Label("AI Summary", systemImage: "doc.text.magnifyingglass")
                }
            }
        }
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
        .onChange(of: selectedEntry) { _, _ in
            if let entry = selectedEntry, justAddedEntryID == entry.id {
                proxy.scrollTo(entry.id, anchor: .top)
                justAddedEntryID = nil
            }
            focusModel.entry = selectedEntry
            focusModel.focusedNoteID = nil
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
                        .foregroundColor(.primary)
                }
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
        .navigationSplitViewColumnWidth(min: 300, ideal: 400, max: 500)
        .onAppear {
            chatPanelWidth = CGFloat(chatPanelWidthRaw)
#if DEBUG
            if entries.isEmpty {
                MockData.insertTestEntries(into: modelContext)
            }
#endif
            DispatchQueue.main.async {
                selectedEntry = entries.first
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
                HStack(spacing: 0) {
                    if !isChatPoppedOut && isChatVisible {
                        JournalChatView(entry: entry, isInOwnWindow: $isChatPoppedOut, isChatVisible: $isChatVisible, popOutWindow: {
                            self.isChatPoppedOut = true
                        })
                            .frame(width: chatPanelWidth)
                            .background(Color("ChatViewBackground"))
                            .transition(.move(edge: .leading))

                        ZStack {
                            // Drag area
                            Color.clear
                                .contentShape(Rectangle()) // expands hit area
                                .frame(width: 16)          // makes drag easier
                                .gesture(
                                    DragGesture(minimumDistance: 5)
                                        .onChanged { value in
                                            chatPanelWidth = max(200, min(chatPanelWidth + value.translation.width, 600))
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
                    }
                    
                    ZStack(alignment: .topTrailing) {
                        JournalEntryView(entry: entry)
                            .environmentObject(focusModel)
                        
                        if !isChatVisible {
                            Button(action: {
                                isChatVisible = true
                            }) {
                                Image(systemName: "bubble.left")
                                    .frame(width: 28, height: 28)
                                    .font(.system(size: 16, weight: .regular))
                                    .padding(6)
                                    .background(Color(NSColor.controlBackgroundColor))
                                    .clipShape(Circle())
                                    .opacity(isShowChatHovering ? 1.0 : 0.5)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .padding(.top, 6)
                            .padding(.trailing, 12)
                            .onHover { hovering in
                                isShowChatHovering = hovering
                            }
                        }
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
                        window.contentView = NSHostingView(rootView: JournalChatView(entry: entry, isInOwnWindow: $isChatPoppedOut))
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
        let note = JournalNote(number: 1, text: "")
        let newEntry = JournalEntry(date: Date(), title: "Journal Entry", notes: [note])
        modelContext.insert(newEntry)
        DispatchQueue.main.async {
            selectedEntry = newEntry
            justAddedEntryID = newEntry.id
            focusModel.focusedNoteID = note.id
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

private struct AISummaryPanel: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Summary")
                    .font(.title)
                    .fontWeight(.semibold)
                    .padding(.leading, 20)
                    .padding(.top, 28)
            }
            Divider().padding(.horizontal, 16)
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("""
This entry explores the user's internal conflict between obligation and autonomy. Themes of guilt, inherited responsibility, and personal boundaries are highlighted throughout the notes.

Key symbols include: the locked door (emotional separation), the unfinished conversation (regret), and the cold sunlight (clarity in solitude). The writing style shifts from reflective to resolute by the end.

AI suggests the emotional arc moves from confusion → resistance → quiet strength.
""")
                        .font(.system(size: 14))
                        .lineSpacing(6)
                        .foregroundColor(.primary)
                }
                .padding(.top, 24)
                .padding(.horizontal, 32)
                .padding(.bottom, 40)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            ZStack(alignment: .leading) {
                Color("AIPanelBackground")
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.white.opacity(0.08),
                        Color.clear
                    ]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: 8)
                .padding(.leading, -4)
            }
        )
    }
}
