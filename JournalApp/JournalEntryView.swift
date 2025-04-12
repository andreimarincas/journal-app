//
//  JournalEntryView.swift
//  JournalApp
//
//  Created by Andrei Marincas on 01.04.2025.
//

import SwiftUI
import SwiftData

enum JournalTone: CaseIterable {
    case reflective, hopeful, melancholy

    var text: String {
        switch self {
        case .reflective: return "✨ I kept walking, not toward anything — just away from stillness."
        case .hopeful: return "✨ There’s something beautiful forming, just past what I can see."
        case .melancholy: return "✨ The sky carried weight I couldn’t name, only feel."
        }
    }
    
    var label: String {
        switch self {
        case .reflective: return "—Reflective"
        case .hopeful: return "—Hopeful"
        case .melancholy: return "—Melancholy"
        }
    }
    
    var color: Color {
        switch self {
        case .reflective: return Color("ToneReflective")
        case .hopeful: return Color("ToneHopeful")
        case .melancholy: return Color("ToneMelancholy")
        }
    }
}

private struct ScrollViewFlasher: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let scrollView = findScrollView(from: view) {
                scrollView.flashScrollers()
            }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}

    private func findScrollView(from view: NSView) -> NSScrollView? {
        var superview = view.superview
        while superview != nil {
            if let scrollView = superview as? NSScrollView {
                return scrollView
            }
            superview = superview?.superview
        }
        return nil
    }
}

struct JournalEntryView: View {
    @State private var viewModel: JournalEntryViewModel
    @Binding var isSummaryPanelVisible: Bool
    @EnvironmentObject private var focusModel: JournalFocusModel
    @State private var editedTexts: [UUID: String] = [:]
    @State private var aiSuggestions: [JournalTone: String] = [:]
    @State private var containerWidth: CGFloat = 0
    @Binding var isChatVisible: Bool
    @State private var isHoveringNoteHorizon : Bool = false
    @State private var isShowChatHovering = false
    @State private var draftCanvasText: String = ""
    private let canvasFontSize: CGFloat = 15.5
    @State private var selectedViewMode: ViewMode = .notes
    
    private enum ViewMode: String {
        case notes, canvas
    }

    @AppStorage("viewMode") private var viewModeRawValue: String = "notes"
    
    private var viewMode: ViewMode {
        ViewMode(rawValue: viewModeRawValue) ?? .notes
    }
    
    private func setViewMode(_ newValue: ViewMode) {
        viewModeRawValue = newValue.rawValue
    }
    
    init(viewModel: JournalEntryViewModel, isSummaryPanelVisible: Binding<Bool>, isChatVisible: Binding<Bool>) {
        self.viewModel = viewModel
        self._isSummaryPanelVisible = isSummaryPanelVisible
        self._isChatVisible = isChatVisible
    }
    
    var body: some View {
        ZStack {
            Color("EntryBackground")
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 12) {
                notesHeader
                if viewMode == .notes {
                    notesList
                        .padding(.trailing, -22)
                } else {
                    canvasView
                        .padding(.leading, -18)
                        .padding(.trailing, -38)
                        .padding(.top, -18)
                        .padding(.bottom, -18)
                }
                notesFooter
            }
            .padding()
            .contentShape(Rectangle()) // Ensures the full area is tappable
            .onTapGesture {
                if let oldID = focusModel.focusedNoteID,
                   let newText = editedTexts[oldID],
                   let note = viewModel.notes.first(where: { $0.id == oldID }) {
                    if newText != note.text {
                        viewModel.updateNote(note, text: newText)
                    }
                }
                if let window = NSApplication.shared.keyWindow {
                    window.makeFirstResponder(nil)
                }
                isSummaryPanelVisible = false
            }
            .onAppear {
                selectedViewMode = viewMode
                focusModel.entry = viewModel.entry
                viewModel.loadNotes()
                draftCanvasText = viewModel.canvasBody
            }
            .onChange(of: selectedViewMode) { _, newValue in
                setViewMode(newValue)
                if let window = NSApplication.shared.keyWindow {
                    window.makeFirstResponder(nil)
                }
                if newValue == .canvas {
                    draftCanvasText = viewModel.canvasBody
                }
            }
        }
        .onChange(of: editedTexts) { oldValue, newValue in
//            print(newValue)
        }
        .onChange(of: viewModel.notes) {
            draftCanvasText = viewModel.canvasBody
        }
    }

    private var notesHeader: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(viewMode == .notes ? "Notes" : "Canvas")
                .font(.title)
                .bold()
                .foregroundStyle(.primary)

            Spacer()

            Picker("", selection: $selectedViewMode) {
                Image(systemName: "list.number")
                    .help("Notes")
                    .tag(ViewMode.notes)
                Image(systemName: "doc.plaintext")
                    .help("Canvas")
                    .tag(ViewMode.canvas)
            }
            .pickerStyle(.segmented)
            .frame(width: 80)
            
            chatToggleButton
        }
        .padding(.trailing, -28)
        .padding(.bottom, 4)
    }
    
    private var chatToggleButton: some View {
        Button(action: {
            if !isChatVisible {
                focusModel.clearNoteFocus()
            }
            isChatVisible.toggle()
        }) {
            ZStack {
                Image(systemName: "bubble.left")
                    .font(.system(size: 16, weight: .regular))
                
                if isChatVisible {
                    Rectangle()
                        .fill(Color.primary)
                        .frame(width: 22, height: 1)
                        .rotationEffect(.degrees(45))
                        .offset(x: -1, y: -1)
                }
            }
            .frame(width: 28, height: 28)
            .padding(6)
            .background(
                Circle()
                    .fill(isShowChatHovering
                          ? Color.secondary.opacity(0.15)
                          : Color(NSColor.controlBackgroundColor))
                    .scaleEffect(0.85)
            )
            .clipShape(Circle())
            .opacity(isShowChatHovering ? 1.0 : 0.5)
        }
        .buttonStyle(.borderless)
        .padding(.top, 6)
        .padding(.trailing, 12)
        .onHover { hovering in
            isShowChatHovering = hovering
        }
    }

    @ViewBuilder
    private var notesList: some View {
        if viewModel.notes.isEmpty {
            ZStack {
                emptyNotesView
                VStack {
                    noteHorizon
                    Spacer()
                }
            }
        } else {
            ScrollViewReader { scrollProxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(viewModel.notes.sorted(by: { $0.number < $1.number })) { note in
                            ZStack {
                                noteView(for: note)
                                    .id(note.id)
                                    .environmentObject(viewModel)
                            }
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                        }
                        noteHorizon
                    }
                    .padding(.trailing, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        GeometryReader { proxy in
                            Color.clear
                                .onChange(of: proxy.size.width) { _, newWidth in
                                    containerWidth = newWidth
                                }
                        }
                    )
                    .background(ScrollViewFlasher())
                    .scrollIndicatorsFlash(onAppear: true)
                }
                .onReceive(NotificationCenter.default.publisher(for: .scrollToNote)) { notification in
                    guard let note = notification.object as? JournalNote else { return }
                    withAnimation(.easeInOut) {
                        scrollProxy.scrollTo(note.id, anchor: .top)
                    }
                }
            }
//            .padding()
//            .background(
//                RoundedRectangle(cornerRadius: 12)
//                    .stroke(Color.secondary.opacity(0.25), lineWidth: 1)
//            )
        }
    }
    
    private var canvasView: some View {
        CanvasTextEditor(text: $draftCanvasText, onEditingEnded: {
            viewModel.persistCanvasText(self.draftCanvasText)
        })
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color("EntryBackground"))
        )
        .foregroundStyle(.primary)
    }
    
    private var emptyNotesView: some View {
        VStack(spacing: 16) {
            Image(systemName: "square.and.pencil")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("No notes yet.")
                .font(.title3)
                .fontWeight(.semibold)
            Text("Click the + button below to add your first note.")
                .foregroundColor(.secondary)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func noteView(for note: JournalNote) -> some View {
        if let newText = editedTexts[note.id], newText != note.text {
            note.text = newText
        }
        let shouldFocus = focusModel.focusedNoteID == note.id
        let shouldFocusInChat = focusModel.pinnedNoteID == note.id
        return NoteRow(
            note: note,
            entry: viewModel.entry,
            shouldFocus: shouldFocus,
            shouldFocusInChat: shouldFocusInChat,
            editedText: Binding(
                get: {
                    let result = editedTexts[note.id] ?? note.text
                    print(result)
                    return result
                },
                set: {
                    print($0)
                    if $0 != editedTexts[note.id] {
                        editedTexts[note.id] = $0
                        if focusModel.pinnedNoteID == note.id {
                            focusModel.clearChatFocus()
                        }
                    }
                }
            ),
            isChatVisible: $isChatVisible,
            containerWidth: containerWidth,
            isSummaryPanelVisible: $isSummaryPanelVisible
        ).environmentObject(focusModel)
    }

    private struct NoteRow: View {
        let note: JournalNote
        let entry: JournalEntry
        let shouldFocus: Bool
        let shouldFocusInChat: Bool
        @Binding var editedText: String
        @State private var isFinalized = false
        @Binding var isSummaryPanelVisible: Bool
        @StateObject private var undoManager = CustomUndoManager()
        @EnvironmentObject var viewModel: JournalEntryViewModel
        @Binding var isChatVisible: Bool
        
        var isAINote: Bool {
            !isFinalized && note.text.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("✨")
        }
        
        @EnvironmentObject private var focusModel: JournalFocusModel
        @State private var isHovering = false
        @State private var height: CGFloat = 22
        @State private var showDeleteAlert = false
        
        let containerWidth: CGFloat
        
        @State private var isHoveringTrash = false
        @State private var isHoveringTransform = false
        @State private var isHoveringDone = false
        @State private var isHoveringPrev = false
        @State private var isHoveringNext = false
        @State private var isHoveringUndo = false
        @State private var isHoveringRedo = false
        @State private var isHoveringChat = false
        
        @State private var isEnhancing = false
        
        init(note: JournalNote, entry: JournalEntry, shouldFocus: Bool, shouldFocusInChat: Bool, editedText: Binding<String>, isChatVisible: Binding<Bool>, containerWidth: CGFloat, isSummaryPanelVisible: Binding<Bool>) {
            self.note = note
            self.entry = entry
            self.shouldFocus = shouldFocus
            self.shouldFocusInChat = shouldFocusInChat
            self._editedText = editedText
            self._isChatVisible = isChatVisible
            self.containerWidth = containerWidth
            self._isSummaryPanelVisible = isSummaryPanelVisible
        }

        var body: some View {
            ZStack(alignment: .bottomTrailing) {
                VStack(alignment: .leading) {
                    HStack(alignment: .top, spacing: 8) {
                        LinearGradient(
                            gradient: Gradient(stops: [
                                .init(color: (isAINote ? Color.purple : Color.accentColor).opacity(0.8), location: 0),
                                .init(color: (isAINote ? Color.purple : Color.accentColor).opacity(0.0), location: 1)
                            ]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(width: 4)
                        .mask(
                            RoundedRectangle(cornerRadius: 2)
                                .frame(width: 4)
                        )
                        .opacity(shouldFocus || shouldFocusInChat ? 1 : 0)
                        .offset(y: 2)
                        VStack {
                            Text("\(note.number).")
                                .font(.system(size: 15, weight: .light))
                                .foregroundColor(.secondary)
                                .padding(.top, 9)
                            Spacer()
                        }
                        noteTextView
                    }
                    .padding(.vertical, 4)
                    .padding(.top, 8)
                    
                    Spacer().frame(height: 16)
                    
                    Rectangle()
                        .fill(Color("NotesDividerColor"))
                        .frame(height: 1)
                        .padding(.vertical, 4)
                        .padding(.horizontal, 22)
                }

                HStack(spacing: 0) {
                    if viewModel.latestAISuggestions.count > 1 {
                        toneCycleButtons
                    }
                    doneButton
                    undoButton
                    redoButton
                    transformButton
                    chatButton
                    trashButton
                }
                .padding(.trailing, 22)
            }
            .padding(.horizontal, 2)
            .contentShape(Rectangle())
//            .background(
//                RoundedRectangle(cornerRadius: 8, style: .continuous)
//                    .fill(Color(NSColor.windowBackgroundColor))
//                    .fill(focusModel.focusedNoteID == note.id ? Color(hex: "#F7F7F7") : Color.clear)
//                    .fill(focusModel.focusedNoteID == note.id ? Color.accentColor : Color("BubbleUser"))
//                    .background(isFocusfocusModel.focusedNoteID = note.ided ? Color.accentColor : Color("BubbleUser"))
//                    .shadow(color: Color.black.opacity(0.05), radius: 1, x: 0, y: 1)
//            )
            .onTapGesture {
                focusModel.focusedNoteID = note.id
                if focusModel.pinnedNoteID != note.id {
                    focusModel.clearChatFocus()
                }
            }
            .onHover { hovering in
                isHovering = hovering
            }
            .onChange(of: focusModel.focusedNoteID) { _, newValue in
                if newValue == note.id {
                    isSummaryPanelVisible = false
                }
            }
            
            if isAINote && !isFinalized {
                ZStack() {
                    HStack() {
                        VStack {
                            Spacer()
                            Text(viewModel.currentAISuggestion?.tone.label ?? "")
                                .font(.callout)
                                .italic()
                                .foregroundStyle((viewModel.currentAISuggestion?.tone.color ?? .secondary).opacity(0.8))
                                .padding(.leading, 40)
                                .padding(.top, 12)
                                .padding(.bottom, 8)
                        }
                        Spacer()
                    }
                }
            }
        }
        
        private var noteTextView: some View {
            TextViewWrapper(
                text: $editedText,
                height: $height,
                shouldFocus: shouldFocus,
                id: note.id,
                isDimmed: isAINote,
                isHovered: isHovering,
                toneCycleLeft: {
                    viewModel.cycleAISuggestion(inReverse: true)
                    if let newText = viewModel.currentAISuggestion?.text {
                        editedText = newText
                    }
                },
                toneCycleRight: {
                    viewModel.cycleAISuggestion()
                    if let newText = viewModel.currentAISuggestion?.text {
                        editedText = newText
                    }
                },
                viewModel: viewModel,
                undoManager: undoManager
            )
            .frame(maxWidth: .infinity, minHeight: height, maxHeight: height)
            .clipped()
            .id(containerWidth)
            .onChange(of: height) { _, _ in }
        }
        
        private var doneButton: some View {
            Button(action: {
                viewModel.generateTitle()
                if let responder = NSApp.keyWindow?.firstResponder as? NSTextView {
                    responder.window?.makeFirstResponder(nil)
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    if editedText.trimmingCharacters(in: .whitespaces).hasPrefix("✨") {
                        if let range = editedText.range(of: "✨") {
                            editedText.removeSubrange(range)
                            editedText = editedText.trimmingCharacters(in: .whitespaces)
                        }
                    }
                    isFinalized = true
                }
            }) {
            Image(systemName: "checkmark")
                    .imageScale(.medium)
                    .fontWeight(.medium)
                    .frame(minWidth: 32, minHeight: 32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundColor(isHoveringDone ? .primary : .secondary)
            .onHover { isHoveringDone = $0 }
            .opacity(isAINote && isHovering ? 1 : 0)
        }
        
        private var chatButton: some View {
            Group {
                if !isAINote {
                    Button(action: {
                        guard !shouldFocusInChat else {
                            focusModel.clearChatFocus()
                            return
                        }
                        if let responder = NSApp.keyWindow?.firstResponder as? NSTextView {
                            responder.window?.makeFirstResponder(nil)
                        }
                        let sortedNotes = viewModel.notes.sorted(by: { $0.number < $1.number })
                        guard let index = sortedNotes.firstIndex(where: { $0.id == note.id }) else { return }
                        let allNoteTexts = sortedNotes.map { $0.text }
                        
                        focusModel.pendingChatMessageContext = ChatNoteContext(
                            entryNotes: allNoteTexts,
                            entryTitle: entry.title,
                            noteIndex: index,
                            userMessage: note.text
                        )
                        
                        focusModel.pendingChatMessage = note.text
                        isChatVisible = true
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                            focusModel.pinnedNoteID = note.id
                        }
                    }) {
                        Image(systemName: shouldFocusInChat ? "bubble.left.fill" : "bubble.left")
                            .foregroundColor(shouldFocusInChat ? .accentColor : .secondary)
                            .imageScale(.medium)
                            .fontWeight(.medium)
                            .frame(minWidth: 32, minHeight: 32)
                            .contentShape(Rectangle())
                    }
                    .onHover { isHoveringChat = $0 }
                    .buttonStyle(.plain)
                    .foregroundColor(isHoveringChat ? .primary : .secondary)
                    .opacity(isHovering || shouldFocusInChat ? 1 : 0)
                }
            }
        }
        
        private var transformButton: some View {
            Group {
                if !isAINote {
                    Button(action: {
                        if let responder = NSApp.keyWindow?.firstResponder as? NSTextView {
                            responder.window?.makeFirstResponder(nil)
                        }
                        focusModel.focusedNoteID = nil
                        let previousText = editedText
                        isEnhancing = true
                        viewModel.enhance(note: note) { enhancedText in
                            isEnhancing = false
                            guard let enhancedText else { return }
                            editedText = enhancedText
                            undoManager.registerChange(previous: previousText, current: enhancedText)
                        }
                    }) {
                        Image(systemName: "wand.and.stars")
                            .imageScale(.medium)
                            .fontWeight(.medium)
                            .frame(minWidth: 32, minHeight: 32)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(isHoveringTransform ? .primary : .secondary)
                    .onHover { isHoveringTransform = $0 }
                    .opacity(isHovering || shouldFocusInChat ? 1 : 0)
                    .disabled(isEnhancing)
                }
            }
        }
        
        private var undoButton: some View {
            Group {
                if !isAINote {
                    Button(action: {
                        if let restored = undoManager.undo(current: editedText) {
                            editedText = restored
                        }
                    }) {
                        Image(systemName: "arrow.uturn.backward")
                            .imageScale(.medium)
                            .fontWeight(.medium)
                            .frame(minWidth: 32, minHeight: 32)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(isHoveringUndo ? .primary : .secondary)
                    .onHover { isHoveringUndo = $0 }
                    .opacity(isHovering || shouldFocusInChat ? 1 : 0)
                    .disabled(undoManager.undoStack.isEmpty)
                }
            }
        }
        
        private var redoButton: some View {
            Group {
                if !isAINote {
                    Button(action: {
                        if let restored = undoManager.redo(current: editedText) {
                            editedText = restored
                        }
                    }) {
                        Image(systemName: "arrow.uturn.forward")
                            .imageScale(.medium)
                            .fontWeight(.medium)
                            .frame(minWidth: 32, minHeight: 32)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(isHoveringRedo ? .primary : .secondary)
                    .onHover { isHoveringRedo = $0 }
                    .disabled(undoManager.redoStack.isEmpty)
                    .opacity(isHovering || shouldFocusInChat ? 1 : 0)
                }
            }
        }

        private var toneCycleButtons: some View {
            HStack(spacing: 4) {
                Button(action: {
                    viewModel.cycleAISuggestion(inReverse: true)
                    if let newText = viewModel.currentAISuggestion?.text {
                        editedText = newText
                    }
                }) {
                    Image(systemName: "chevron.left")
                        .imageScale(.medium)
                        .fontWeight(.medium)
                        .frame(minWidth: 32, minHeight: 32)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundColor(isHoveringPrev ? .primary : .secondary)
                .onHover { isHoveringPrev = $0 }

                Text("\(viewModel.currentAISuggestionIndex + 1)/\(JournalTone.allCases.count)")
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .frame(width: 20)
                    .multilineTextAlignment(.center)

                Button(action: {
                    viewModel.cycleAISuggestion()
                    if let newText = viewModel.currentAISuggestion?.text {
                        editedText = newText
                    }
                }) {
                    Image(systemName: "chevron.right")
                        .imageScale(.medium)
                        .fontWeight(.medium)
                        .frame(minWidth: 32, minHeight: 32)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundColor(isHoveringNext ? .primary : .secondary)
                .onHover { isHoveringNext = $0 }
            }
            .opacity(isAINote && isHovering ? 1 : 0)
        }
        
        private var trashButton: some View {
            Button(action: {
                if let window = NSApplication.shared.keyWindow {
                    window.makeFirstResponder(nil)
                }
                focusModel.focusedNoteID = nil
                showDeleteAlert = true
            }) {
                Image(systemName: "trash")
                    .imageScale(.medium)
                    .fontWeight(.medium)
                    .frame(minWidth: 32, minHeight: 32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundColor(isHoveringTrash ? .primary : .secondary)
            .onHover { isHoveringTrash = $0 }
            .opacity(isHovering || shouldFocusInChat ? 1 : 0)
            .alert("Delete this note?", isPresented: $showDeleteAlert) {
                Button("Delete", role: .destructive) {
                    guard let _ = viewModel.notes.firstIndex(where: { $0.id == note.id }) else { return }
                    viewModel.deleteNote(note)
                    if focusModel.pinnedNoteID == note.id {
                        focusModel.clearChatFocus()
                    }
                }
                Button("Cancel", role: .cancel) {}
            }
        }
    }

    private var notesFooter: some View {
        ZStack {
            HStack {
                Spacer()
                Button(action: {
                    let newNote = viewModel.addNote(text: "")
                    focusModel.focusedNoteID = newNote.id
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        NotificationCenter.default.post(name: .scrollToNote, object: newNote)
                    }
                }) {
                    Image(systemName: "plus")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(Color(NSColor.controlAccentColor))
                        .clipShape(Circle())
                        .shadow(radius: 3)
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
                .padding(.trailing, 8)
                
                Button(action: {
                    guard !viewModel.isGeneratingAISuggestions else { return }
                    if let window = NSApplication.shared.keyWindow {
                        window.makeFirstResponder(nil)
                    }
                    focusModel.focusedNoteID = nil
                    viewModel.generateAISuggestions { aiSuggestions in
                        guard let aiSuggestions, !aiSuggestions.isEmpty,
                                aiSuggestions.count == JournalTone.allCases.count else { return }
                        let newNote = viewModel.addNote(text: viewModel.currentAISuggestion?.text ?? "")
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            NotificationCenter.default.post(name: .scrollToNote, object: newNote)
                        }
                    }
                }) {
                    ZStack {
                        if viewModel.isGeneratingAISuggestions {
                            LottieView(filename: "magic_burst", loop: true)
                                .frame(width: 44, height: 44)
                                .scaleEffect(0.4)
                                .background(Color("AIButtonColor"))
                                .clipShape(Circle())
                                .shadow(radius: 3)
                                .foregroundStyle(Color("SparklesYellow"), Color("SparklesOrange"))
                        } else {
                            Image(systemName: "sparkles")
                                .font(.system(size: 18, weight: .bold))
                                .frame(width: 44, height: 44)
                                .background(Color("AIButtonColor"))
                                .clipShape(Circle())
                                .shadow(radius: 3)
                                .symbolRenderingMode(.palette)
                                .foregroundStyle(Color("SparklesYellow"), Color("SparklesOrange"))
                        }
                    }
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
            HStack {
                Spacer()
                Text("\(viewModel.notes.count) note\(viewModel.notes.count == 1 ? "" : "s")")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.top, 12)
                Spacer()
            }
        }
    }
}

extension JournalEntryView {
    private var noteHorizon: some View {
        guard !viewModel.isGeneratingAISuggestions else {
            return AnyView(
                Color.clear.frame(height: 64)
            )
        }
        return AnyView(
            VStack(alignment: .leading) {
                Color.clear
                    .frame(height: 56)
                    .contentShape(Rectangle())
                    .padding(.top, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color("EntryBackground"))
                            .padding(.leading, 10)
                            .opacity(isHoveringNoteHorizon ? 1 : 0)
                    )
                    .onHover { hovering in
                        isHoveringNoteHorizon = hovering
                    }
                    .overlay(
                        HStack {
                            Divider()
                                .frame(height: 1)
                                .background(Color.secondary.opacity(0.06))
                            Text("Start writing your thoughts here...")
                                .font(.system(size: 14, weight: .thin))
                                .italic()
                                .foregroundColor(.primary.opacity(0.8))
                            Divider()
                                .frame(height: 1)
                                .background(Color.secondary.opacity(0.3))
                        }
                        .padding(.leading, 16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .opacity(isHoveringNoteHorizon ? 0.7 : 0)
                        .allowsHitTesting(false)
                    )
                    .onTapGesture {
                        let newNote = viewModel.addNote(text: "")
                        focusModel.focusedNoteID = newNote.id
                    }
                Divider()
                    .frame(height: 0.5)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 4)
                    .padding(.leading, 11)
                    .offset(y: -8)
                    .opacity(isHoveringNoteHorizon ? 1 : 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding([.leading])
        )
    }
}

struct TextViewWrapper: NSViewRepresentable {
    @Binding var text: String
    @Binding var height: CGFloat
    let shouldFocus: Bool
    let id: UUID
    let isDimmed: Bool
    let isHovered: Bool
    let toneCycleLeft: (() -> Void)?
    let toneCycleRight: (() -> Void)?
    let viewModel: JournalEntryViewModel
    @EnvironmentObject private var focusModel: JournalFocusModel
    let undoManager: CustomUndoManager
    private let paragraphSpacing: CGFloat = 6
    private let fixedHeight: CGFloat = 56
    private let notesFontSize: CGFloat = 15.5
    
    func makeNSView(context: Context) -> NSTextView {
        let textView = FocusableTextView()
        textView.onFocusGained = {
            if focusModel.focusedNoteID != id {
                focusModel.focusedNoteID = id
            }
            if focusModel.pinnedNoteID != id {
                focusModel.clearChatFocus()
            }
        }
        textView.onFocusLost = {
            if focusModel.focusedNoteID == id {
                focusModel.focusedNoteID = nil
            }
        }
        textView.undoAction = {
            if let restored = undoManager.undo(current: text) {
                text = restored
                setAttrText(restored, to: textView)
            }
        }
        textView.redoAction = {
            if let restored = undoManager.redo(current: text) {
                text = restored
                setAttrText(restored, to: textView)
            }
        }
        textView.isEditable = true
        textView.isRichText = false
        setAttrText(text, to: textView)
        textView.font = NSFont.systemFont(ofSize: 15, weight: .regular)
        textView.drawsBackground = false
        textView.textContainerInset = NSSize(width: 22, height: 2)
        textView.textContainer?.widthTracksTextView = true
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.delegate = context.coordinator
        textView.pasteAsPlainText = true
        textView.toneCycleLeft = toneCycleLeft
        textView.toneCycleRight = toneCycleRight
        textView.isHoveredNote = isHovered
        textView.isActiveAINote = isDimmed
        textView.importsGraphics = false
        textView.allowsImageEditing = false
        textView.isRichText = false
        textView.smartInsertDeleteEnabled = false
        textView.usesRuler = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        
        if shouldFocus {
            DispatchQueue.main.async {
                textView.window?.makeFirstResponder(textView)
            }
        }
        
        return textView
    }

    func updateNSView(_ nsView: NSTextView, context: Context) {
        if let textView = nsView as? FocusableTextView {
            textView.isHoveredNote = isHovered
            textView.isActiveAINote = isDimmed
        }
        if nsView.string != text {
            setAttrText(text, to: nsView)
            nsView.layoutManager?.ensureLayout(for: nsView.textContainer!)
        }
        
        if let layoutManager = nsView.layoutManager,
           let textContainer = nsView.textContainer {
            layoutManager.ensureLayout(for: textContainer)
            let usedRect = layoutManager.usedRect(for: textContainer)
            DispatchQueue.main.async {
                height = shouldFocus ? max(usedRect.height + paragraphSpacing, fixedHeight) : fixedHeight
            }
        }
        DispatchQueue.main.async {
            nsView.invalidateIntrinsicContentSize()
            nsView.setNeedsDisplay(nsView.bounds)
        }
        
        DispatchQueue.main.async {
            if let firstResponder = nsView.window?.firstResponder, firstResponder == nsView {
                if focusModel.focusedNoteID != id {
                    focusModel.focusedNoteID = id
                }
            } else if shouldFocus {
                nsView.window?.makeFirstResponder(nsView)
            }
            if isDimmed {
                let fullRange = NSRange(location: 0, length: nsView.string.utf16.count)
                let textColor = nsView.window?.firstResponder !== nsView && !isHovered ? NSColor.systemGray : NSColor.labelColor
                nsView.textStorage?.addAttribute(.foregroundColor, value: textColor, range: fullRange)
            }
        }
    }
    
    func setAttrText(_ text: String, to nsView: NSTextView) {
        let dimmed = isDimmed// && nsView.window?.firstResponder != nsView
        let textColor = dimmed ? NSColor.darkGray : NSColor.labelColor
        let fontDescriptor = NSFont.systemFont(ofSize: notesFontSize, weight: .regular).fontDescriptor
        let italicDescriptor = dimmed ? fontDescriptor.withSymbolicTraits(.italic) : fontDescriptor
        let font = NSFont(descriptor: italicDescriptor, size: notesFontSize) ?? NSFont.systemFont(ofSize: notesFontSize, weight: .regular)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineHeightMultiple = 1.3
        paragraphStyle.paragraphSpacing = 6

        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: textColor,
            .paragraphStyle: paragraphStyle
        ]
        let attributed = NSAttributedString(string: text, attributes: attrs)
        nsView.textStorage?.setAttributedString(attributed)
        nsView.typingAttributes = attrs
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, NSTextViewDelegate {
    var parent: TextViewWrapper

        init(_ parent: TextViewWrapper) {
            self.parent = parent
            super.init()
        }
        
        deinit {
            NotificationCenter.default.removeObserver(self)
        }
        
        @objc func textDidEndEditing(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            let trimmedText = textView.string.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedText.isEmpty {
                if let note = parent.viewModel.notes.first(where: { $0.id == parent.id }) {
                    parent.viewModel.deleteNote(note)
                    parent.focusModel.focusedNoteID = nil
                }
            } else {
                parent.text = trimmedText
            }
        }
        
        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            
            let oldText = parent.text
            let newText = textView.string
            
            if oldText != newText {
                parent.undoManager.registerChange(previous: oldText, current: newText)
                parent.text = newText
                
                // This forces the newly updated or pasted text to be immediately styled with your standard note font, spacing, and color, overriding any residual rich text attributes that might have been pasted or triggered during editing.
                parent.setAttrText(newText, to: textView)
            }
        }
    }
}

class FocusableTextView: NSTextView {
    var pasteAsPlainText: Bool = false
    var onFocusGained: (() -> Void)?
    var onFocusLost: (() -> Void)?
    var undoAction: (() -> Void)?
    var redoAction: (() -> Void)?
    var toneCycleLeft: (() -> Void)?
    var toneCycleRight: (() -> Void)?
    var isHoveredNote: Bool = false
    var isActiveAINote: Bool = false
    
    override func becomeFirstResponder() -> Bool {
        let became = super.becomeFirstResponder()
        if became {
            onFocusGained?()
        }
        return became
    }
    
    override func resignFirstResponder() -> Bool {
        let resigns = super.resignFirstResponder()
        if resigns {
            onFocusLost?()
        }
        return resigns
    }
    
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.modifierFlags.contains(.command) {
            if self == self.window?.firstResponder {
                if event.charactersIgnoringModifiers == "z" {
                    undoAction?()
                    return true
                } else if event.charactersIgnoringModifiers == "Z" {
                    redoAction?()
                    return true
                } else if event.charactersIgnoringModifiers == "s" {
                    self.window?.makeFirstResponder(nil)
                    return true
                } else if event.charactersIgnoringModifiers == "\r" {
                    self.window?.makeFirstResponder(nil)
                    return true
                }
            }
        } else if isHoveredNote && isActiveAINote && self.window?.firstResponder !== self {
            if event.keyCode == 123 {
                toneCycleLeft?()
                return true
            } else if event.keyCode == 124 {
                toneCycleRight?()
                return true
            }
        }
        return super.performKeyEquivalent(with: event)
    }
    
    override func paste(_ sender: Any?) {
        if pasteAsPlainText, let string = NSPasteboard.general.string(forType: .string) {
            self.insertText(string, replacementRange: self.selectedRange())
        } else {
            super.paste(sender)
        }
    }
}
