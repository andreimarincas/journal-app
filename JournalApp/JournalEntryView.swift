//
//  JournalEntryView.swift
//  JournalApp
//
//  Created by Andrei Marincas on 01.04.2025.
//

import SwiftUI
import SwiftData

struct JournalEntryView: View {
    @State private var viewModel: JournalEntryViewModel
    @Binding var isSummaryPanelVisible: Bool
    @EnvironmentObject private var focusModel: JournalFocusModel
    @State private var aiSuggestions: [JournalTone: String] = [:]
    @State private var containerWidth: CGFloat = 0
    @Binding var isChatVisible: Bool
    @State private var isHoveringNoteHorizon : Bool = false
    @State private var isShowChatHovering = false
    @State private var isHoveringUndoButton : Bool = false
    @State private var isHoveringRedoButton : Bool = false
    @State private var selectedViewMode: ViewMode = .notes
    @State private var draftCanvasText = CanvasText()
    @State private var canvasUndoAllowed: Bool = false
    @State private var canvasUndoManager: CustomUndoManager
    @State private var isMerging: Bool = false
//    @State private var progressOffset: CGFloat = 30
    @State private var dotPulseIndex = 0
    @State private var dotPulseTimer: Timer?
    
    enum ViewMode: String {
        case notes, canvas
    }

    @AppStorage("viewMode") private var viewModeRawValue: String = "notes"
    
    private var viewMode: ViewMode {
        ViewMode(rawValue: viewModeRawValue) ?? .notes
    }
    
    private func setViewMode(_ newValue: ViewMode) {
        viewModeRawValue = newValue.rawValue
    }
    
    init(viewModel: JournalEntryViewModel, isSummaryPanelVisible: Binding<Bool>, isChatVisible: Binding<Bool>, canvasUndoManager: CustomUndoManager) {
        self.viewModel = viewModel
        self._isSummaryPanelVisible = isSummaryPanelVisible
        self._isChatVisible = isChatVisible
        self.canvasUndoManager = canvasUndoManager
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
                    
//                    canvasView
                    
//                    ZStack(alignment: .topLeading) {
//                        canvasView
//                        if isMerging {
//                            progressLine
//                                .padding(.top, 8) // slight space under the title "Canvas"
//                        }
//                    }
                    
                    ZStack(alignment: .topLeading) {
                        canvasView
                        
                        if isMerging {
                            HStack {
                                Spacer()
                                threeDotIndicator
                                Spacer()
                            }
                            .offset(y: -6)
                        }
                    }
                }
                notesFooter
            }
            .padding()
            .contentShape(Rectangle()) // Ensures the full area is tappable
            .onTapGesture {
                if let oldID = focusModel.focusedNoteID,
                   let newText = viewModel.editedTexts[oldID],
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
                canvasUndoAllowed = true
                draftCanvasText = CanvasText(text: viewModel.canvasBody, source: .saved)
            }
            .onChange(of: selectedViewMode) { _, newValue in
                setViewMode(newValue)
                focusModel.viewMode = newValue
                if let window = NSApplication.shared.keyWindow {
                    window.makeFirstResponder(nil)
                }
                if newValue == .canvas {
                    draftCanvasText = CanvasText(text: viewModel.canvasBody, source: .saved)
                }
            }
            .onChange(of: focusModel.pendingCanvasMergeAssistantReply) { _, newValue in
                guard let userMessage = focusModel.pendingCanvasMergeUserMessage,
                      let assistantReply = newValue,
                      selectedViewMode == .canvas else { return }
                isMerging = true
                Task {
                    try? await Task.sleep(nanoseconds: UInt64(2 * 1_000_000_000))
                    let merged = await viewModel.mergeCanvasFromChat(userMessage: userMessage, assistantReply: assistantReply)
                    await MainActor.run {
                        focusModel.pendingCanvasMergeUserMessage = nil
                        focusModel.pendingCanvasMergeAssistantReply = nil
                        if let merged {
                            draftCanvasText = CanvasText(text: merged, source: .draft)
                        } else {
                            draftCanvasText = CanvasText(text: viewModel.canvasBody, source: .saved)
                        }
                        isMerging = false
                    }
                }
            }
            .onChange(of: draftCanvasText) { oldValue, newValue in
                if selectedViewMode == .canvas && focusModel.pendingCanvasMergeUserMessage != nil {
                    canvasUndoManager.registerChange(previous: oldValue.text, current: newValue.text)
                    viewModel.updateUndoRedoAvailability(focusedNoteID: focusModel.focusedNoteID, viewMode: .canvas, canvasUndoManager: canvasUndoManager)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .updateUndoRedoAvailability)) { notification in
                guard
                    selectedViewMode == .canvas,
                    let undoManager = notification.object as? CustomUndoManager
                else { return }

                viewModel.updateUndoRedoAvailability(
                    focusedNoteID: focusModel.focusedNoteID,
                    viewMode: .canvas,
                    canvasUndoManager: undoManager
                )
            }
        }
        .onChange(of: viewModel.notes) {
            draftCanvasText = CanvasText(text: viewModel.canvasBody, source: .saved)
        }
    }
    
    private var threeDotIndicator: some View {
        HStack(spacing: 6) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: 6, height: 6)
//                    .shadow(color: Color.accentColor.opacity(0.5), radius: 3, x: 0, y: 0) // ✨ soft glow
                    .opacity(dotPulseIndex == index ? 1.0 : 0.3)
                    .animation(
                        .easeInOut(duration: 0.6).delay(Double(index) * 0.2),
                        value: dotPulseIndex
                    )
            }
        }
        .onAppear {
            startDotPulse()
        }
        .onDisappear {
            stopDotPulse()
        }
    }
    
    private func startDotPulse() {
        dotPulseTimer?.invalidate()
        dotPulseTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { _ in
            dotPulseIndex = (dotPulseIndex + 1) % 3
        }
    }

    private func stopDotPulse() {
        dotPulseTimer?.invalidate()
        dotPulseTimer = nil
    }
    
//    private var progressLine: some View {
//        GeometryReader { geometry in
//            ZStack(alignment: .leading) {
//                Rectangle()
//                    .fill(Color.blue)
//                    .frame(width: 80, height: 3)
//                    .offset(x: progressOffset)
//                    .onAppear {
//                        let travelDistance = geometry.size.width - 90
//                        withAnimation(Animation.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
//                            progressOffset = travelDistance
//                        }
//                    }
//            }
//        }
//        .frame(height: 3)
//    }

    private var canvasView: some View {
        CanvasView(
            draftCanvasText: $draftCanvasText,
            canRegisterUndo: $canvasUndoAllowed,
            updateUndoRedo: {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    viewModel.updateUndoRedoAvailability(focusedNoteID: focusModel.focusedNoteID, viewMode: .canvas, canvasUndoManager: canvasUndoManager)
                }
            },
            persistText: {
                viewModel.persistCanvasText(draftCanvasText.text)
            },
            undoManager: canvasUndoManager
        )
        .padding(.leading, -18)
        .padding(.trailing, -38)
        .padding(.top, -18)
        .padding(.bottom, -18)
    }
    
    private var notesHeader: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(viewMode == .notes ? "Notes" : "Canvas")
                .font(.title)
                .bold()
                .foregroundStyle(.primary)

            Spacer()
            
            undoButton
            redoButton
            
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
    
    private var undoButton: some View {
        Button(action: {
            if viewMode == .canvas {
                if let restored = canvasUndoManager.undo(current: draftCanvasText.text) {
                    draftCanvasText.text = restored
                    viewModel.updateUndoRedoAvailability(focusedNoteID: focusModel.focusedNoteID, viewMode: viewMode, canvasUndoManager: canvasUndoManager)
                }
            } else {
                viewModel.performUndo(focusedNoteID: focusModel.focusedNoteID, viewMode: viewMode, canvasUndoManager: canvasUndoManager)
            }
        }) {
            ZStack {
                Image(systemName: "arrow.uturn.backward")
                    .font(.system(size: 16, weight: .regular))
            }
            .frame(width: 28, height: 28)
            .padding(6)
            .background(
                Circle()
                    .fill(isHoveringUndoButton
                          ? Color.secondary.opacity(0.15)
                          : Color(NSColor.controlBackgroundColor))
                    .scaleEffect(0.85)
                    .opacity(viewModel.isUndoAvailable && isHoveringUndoButton ? 1 : 0)
            )
            .clipShape(Circle())
        }
        .buttonStyle(.borderless)
        .offset(x: 3)
        .disabled(!viewModel.isUndoAvailable)
        .onHover { hovering in
            isHoveringUndoButton = hovering
        }
    }
    
    private var redoButton: some View {
        Button(action: {
            if viewMode == .canvas {
                if let restored = canvasUndoManager.redo(current: draftCanvasText.text) {
                    draftCanvasText.text = restored
                    viewModel.updateUndoRedoAvailability(focusedNoteID: focusModel.focusedNoteID, viewMode: viewMode, canvasUndoManager: canvasUndoManager)
                }
            } else {
                viewModel.performRedo(focusedNoteID: focusModel.focusedNoteID, viewMode: viewMode, canvasUndoManager: canvasUndoManager)
            }
        }) {
            ZStack {
                Image(systemName: "arrow.uturn.forward")
                    .font(.system(size: 16, weight: .regular))
            }
            .frame(width: 28, height: 28)
            .padding(6)
            .background(
                Circle()
                    .fill(isHoveringRedoButton
                          ? Color.secondary.opacity(0.15)
                          : Color(NSColor.controlBackgroundColor))
                    .scaleEffect(0.85)
                    .opacity(viewModel.isRedoAvailable && isHoveringRedoButton ? 1 : 0)
            )
            .clipShape(Circle())
        }
        .buttonStyle(.borderless)
        .offset(x: -3)
        .disabled(!viewModel.isRedoAvailable)
        .onHover { hovering in
            isHoveringRedoButton = hovering
        }
    }
    
    @ViewBuilder
    private var notesList: some View {
        if viewModel.notes.isEmpty {
            ZStack {
                emptyNotesView
                VStack {
                    NoteHorizonView(isHoveringNoteHorizon: $isHoveringNoteHorizon)
                        .environmentObject(viewModel)
                        .environmentObject(focusModel)
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
                        NoteHorizonView(isHoveringNoteHorizon: $isHoveringNoteHorizon)
                            .environmentObject(viewModel)
                            .environmentObject(focusModel)
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
        if let newText = viewModel.editedTexts[note.id], newText != note.text {
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
                    viewModel.editedTexts[note.id] ?? note.text
                },
                set: {
                    if $0 != viewModel.editedTexts[note.id] {
                        viewModel.editedTexts[note.id] = $0
                        viewModel.lastEditedNoteID = note.id
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
