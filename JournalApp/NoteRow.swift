//
//  NoteRow.swift
//  JournalApp
//
//  Created by Andrei Marincas on 12.04.2025.
//

import SwiftUI

struct NoteRow: View {
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
    @State private var height: CGFloat = JournalLayoutConstants.noteRowMinHeight
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
    
    init(note: JournalNote,
         entry: JournalEntry,
         shouldFocus: Bool,
         shouldFocusInChat: Bool,
         editedText: Binding<String>,
         isChatVisible: Binding<Bool>,
         containerWidth: CGFloat,
         isSummaryPanelVisible: Binding<Bool>
    ) {
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
            viewModel.updateUndoRedoAvailability(focusedNoteID: focusModel.focusedNoteID, viewMode: .notes, canvasUndoManager: CustomUndoManager())
        }
        .onAppear {
            viewModel.registerUndoManager(for: note.id, undoManager)
            if undoManager.undoStack.isEmpty {
                undoManager.registerChange(previous: editedText, current: editedText) {
                    DispatchQueue.main.async { [weak viewModel] in
                        viewModel?.updateUndoRedoAvailability(focusedNoteID: focusModel.focusedNoteID, viewMode: .notes, canvasUndoManager: CustomUndoManager())
                    }
                }
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
                            .foregroundStyle(viewModel.currentAISuggestion?.tone.color ?? Color.secondary)
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
                        undoManager.registerChange(previous: previousText, current: enhancedText) { [weak viewModel] in
                            DispatchQueue.main.async {
                                viewModel?.updateUndoRedoAvailability(focusedNoteID: focusModel.focusedNoteID, viewMode: .notes, canvasUndoManager: CustomUndoManager())
                            }
                        }
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
                    viewModel.updateUndoRedoAvailability(focusedNoteID: focusModel.focusedNoteID, viewMode: .notes, canvasUndoManager: CustomUndoManager())
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
                    viewModel.updateUndoRedoAvailability(focusedNoteID: focusModel.focusedNoteID, viewMode: .notes, canvasUndoManager: CustomUndoManager())
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
                viewModel.deleteNote(note, viewMode: .notes, canvasUndoManager: CustomUndoManager())
                if focusModel.pinnedNoteID == note.id {
                    focusModel.clearChatFocus()
                }
            }
            Button("Cancel", role: .cancel) {}
        }
    }
}
