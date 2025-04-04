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

struct JournalEntryView: View {
    private(set) var entry: JournalEntry
    @EnvironmentObject private var focusModel: JournalFocusModel
    @State private var editedTexts: [UUID: String] = [:]
    @State private var aiSuggestions: [JournalTone: String] = [:]
    
    init(entry: JournalEntry) {
        self.entry = entry
    }
    
    var body: some View {
        ZStack {
            Color("EntryBackground")
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 12) {
                notesHeader
                notesList
                notesFooter
            }
            .padding()
            .contentShape(Rectangle()) // Ensures the full area is tappable
            .onTapGesture {
                if let oldID = focusModel.focusedNoteID,
                   let newText = editedTexts[oldID],
                   let index = entry.notes.firstIndex(where: { $0.id == oldID }) {
                    if newText != entry.notes[index].text {
                        entry.notes[index].text = newText
                    }
                }
                if let window = NSApplication.shared.keyWindow {
                    window.makeFirstResponder(nil)
                }
            }
            .onAppear {
                focusModel.entry = entry
            }
        }
        .onChange(of: editedTexts) { oldValue, newValue in
            print(newValue)
        }
    }

    private var notesHeader: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("Notes")
                .font(.title)
                .bold()
                .foregroundStyle(.primary)
            Spacer()
//            Text("Created: " + entry.date.formatted(date: .long, time: .shortened))
//                .font(.subheadline)
//                .foregroundStyle(.secondary)
        }
        .padding(.bottom, 4)
    }

    @ViewBuilder
    private var notesList: some View {
        if entry.notes.isEmpty {
            emptyNotesView
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(entry.notes.sorted(by: { $0.number < $1.number })) { note in
                        ZStack {
                            noteView(for: note)
                        }
                    }
                }
                .padding(.trailing, 12)
            }
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
        if let newText = editedTexts[note.id], newText != note.text {
            note.text = newText
        }
        let shouldFocus = focusModel.focusedNoteID == note.id
        return NoteRow(note: note, entry: entry, shouldFocus: shouldFocus, editedText: Binding(
            get: {
                let result = editedTexts[note.id] ?? note.text
                print(result)
                return result
            },
            set: {
                print($0)
                if $0 != editedTexts[note.id] { editedTexts[note.id] = $0 }
            }
        ), aiSuggestions: $aiSuggestions).environmentObject(focusModel)
    }

    private struct NoteRow: View {
        let note: JournalNote
        let entry: JournalEntry
        let shouldFocus: Bool
        @Binding var editedText: String
        @State private var isFinalized = false
        @State private var aiToneIndex = 0
        @Binding var aiSuggestions: [JournalTone: String]
        @State private var aiEdits: [JournalTone: String] = [:]
        
        var isAINote: Bool {
            !isFinalized && note.text.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("✨")
        }
        
        @EnvironmentObject private var focusModel: JournalFocusModel
        @State private var isHovering = false
        @State private var height: CGFloat = 22
        @State private var showDeleteAlert = false
        
        @State private var isHoveringTrash = false
        @State private var isHoveringDone = false
        @State private var isHoveringPrev = false
        @State private var isHoveringNext = false
        
        init(note: JournalNote, entry: JournalEntry, shouldFocus: Bool, editedText: Binding<String>, aiSuggestions: Binding<[JournalTone: String]>) {
            self.note = note
            self.entry = entry
            self.shouldFocus = shouldFocus
            self._editedText = editedText
            self._aiSuggestions = aiSuggestions
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
                        .opacity(focusModel.focusedNoteID == note.id ? 1 : 0)
                        .offset(y: 2)
                        VStack {
                            Text("\(note.number).")
                                .font(.system(size: 15, weight: .light))
                                .foregroundColor(.secondary)
                                .padding(.top, 1)
                            Spacer()
                        }
        TextViewWrapper(text: $editedText, height: $height, shouldFocus: shouldFocus, id: note.id, isDimmed: isAINote, isHovered: isHovering, toneCycleLeft: {
                if let current = JournalTone.allCases[safe: aiToneIndex] {
                    aiEdits[current] = editedText
                }
                if aiToneIndex > 0 {
                    aiToneIndex -= 1
                    if let previous = JournalTone.allCases[safe: aiToneIndex] {
                        editedText = aiEdits[previous] ?? aiSuggestions[previous] ?? ""
                    }
                }
            }, toneCycleRight: {
                if let current = JournalTone.allCases[safe: aiToneIndex] {
                    aiEdits[current] = editedText
                }
                if aiToneIndex < JournalTone.allCases.count - 1 {
                    aiToneIndex += 1
                    if let next = JournalTone.allCases[safe: aiToneIndex] {
                        editedText = aiEdits[next] ?? aiSuggestions[next] ?? ""
                    }
                }
            })
            .frame(height: height)
                    }
                    .padding(.vertical, 4)
                    .padding(.top, 8)
                    
                    Spacer().frame(height: 16)
                    
                    Divider()
                        .frame(height: 0.5)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 4)
                        .padding(.leading, 24)
                }

                HStack(spacing: 0) {
                    toneCycleButtons
                    doneButton
                    trashButton
                }
            }
            .padding(.horizontal, 2)
            .contentShape(Rectangle())
            .onTapGesture {
                focusModel.focusedNoteID = note.id
            }
            .onHover { hovering in
                isHovering = hovering
            }
            
            if isAINote && !isFinalized {
                ZStack() {
                    HStack() {
                        VStack {
                            Spacer()
                            Text(JournalTone.allCases[safe: aiToneIndex]?.label ?? "")
                                .font(.callout)
                                .italic()
                                .foregroundStyle((JournalTone.allCases[safe: aiToneIndex]?.color ?? .secondary).opacity(0.8))
                                .padding(.leading, 40)
                                .padding(.top, 12)
                                .padding(.bottom, 8)
                        }
                        Spacer()
                    }
                }
            }
        }
        
        private var doneButton: some View {
            Button(action: {
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
        
        private var toneCycleButtons: some View {
        HStack(spacing: 4) {
                    Button(action: {
                        if let current = JournalTone.allCases[safe: aiToneIndex] {
                            aiEdits[current] = editedText
                        }
                        if aiToneIndex > 0 {
                            aiToneIndex -= 1
                            if let previous = JournalTone.allCases[safe: aiToneIndex] {
                                editedText = aiEdits[previous] ?? aiSuggestions[previous] ?? ""
                            }
                        }
                    }) {
                    Image(systemName: "chevron.left")
                        .imageScale(.medium)
                        .fontWeight(.medium)
                        .frame(minWidth: 32, minHeight: 32)
                        .contentShape(Rectangle())
                    }
            .buttonStyle(.plain)
            .disabled(aiToneIndex == 0)
            .foregroundColor(isHoveringPrev ? .primary : .secondary)
            .onHover { isHoveringPrev = $0 }

            Text("\(aiToneIndex + 1)/\(JournalTone.allCases.count)")
                .font(.callout)
                .foregroundColor(.secondary)
                .frame(width: 20)
                .multilineTextAlignment(.center)

                    Button(action: {
                        if let current = JournalTone.allCases[safe: aiToneIndex] {
                            aiEdits[current] = editedText
                        }
                        if aiToneIndex < JournalTone.allCases.count - 1 {
                            aiToneIndex += 1
                            if let next = JournalTone.allCases[safe: aiToneIndex] {
                                editedText = aiEdits[next] ?? aiSuggestions[next] ?? ""
                            }
                        }
                    }) {
                Image(systemName: "chevron.right")
                    .imageScale(.medium)
                    .fontWeight(.medium)
                    .frame(minWidth: 32, minHeight: 32)
                    .contentShape(Rectangle())
                
            }
            .buttonStyle(.plain)
            .disabled(aiToneIndex == JournalTone.allCases.count - 1)
            .foregroundColor(isHoveringNext ? .primary : .secondary)
            .onHover { isHoveringNext = $0 }
        }
            .buttonStyle(.plain)
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
            .opacity(isHovering ? 1 : 0)
            .alert("Delete this note?", isPresented: $showDeleteAlert) {
                Button("Delete", role: .destructive) {
                    if let index = entry.notes.firstIndex(where: { $0.id == note.id }) {
                        entry.notes.remove(at: index)
                        entry.notes = entry.notes.map { note in
                            let newNote = note
                            if note.number > self.note.number {
                                newNote.number -= 1
                            }
                            return newNote
                        }
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
                    let nextNumber = (entry.notes.map(\.number).max() ?? 0) + 1
                    let newNote = JournalNote(number: nextNumber, text: "")
                    entry.notes.append(newNote)
                    focusModel.focusedNoteID = newNote.id
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
                    aiSuggestions = Dictionary(uniqueKeysWithValues: JournalTone.allCases.map { ($0, $0.text) })
                    let aiToneIndex = 0
                    let selectedTone = JournalTone.allCases[aiToneIndex]
                    let nextNumber = (entry.notes.map(\.number).max() ?? 0) + 1
//                    let newNote = JournalNote(number: nextNumber, text: "✨ The air felt heavy with things unsaid.")
                    let newNote = JournalNote(number: nextNumber, text: aiSuggestions[selectedTone] ?? "")
                    entry.notes.append(newNote)
                    if let window = NSApplication.shared.keyWindow {
                        window.makeFirstResponder(nil)
                    }
                    focusModel.focusedNoteID = nil
                }) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 18, weight: .bold))
                        .frame(width: 44, height: 44)
                        .background(Color("AIButtonColor"))
                        .clipShape(Circle())
                        .shadow(radius: 3)
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(Color("SparklesYellow"), Color("SparklesOrange"))
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
            HStack {
                Spacer()
                Text("\(entry.notes.count) note\(entry.notes.count == 1 ? "" : "s")")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.top, 12)
                Spacer()
            }
        }
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
    @EnvironmentObject var focusModel: JournalFocusModel
    @StateObject private var undoManager = CustomUndoManager()
    
    func makeNSView(context: Context) -> NSTextView {
        let textView = FocusableTextView()
        textView.onFocusGained = {
            if focusModel.focusedNoteID != id {
                focusModel.focusedNoteID = id
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
        textView.font = NSFont.systemFont(ofSize: 15, weight: .light)
        textView.drawsBackground = false
        textView.textContainerInset = NSSize(width: 0, height: 2)
        textView.textContainer?.widthTracksTextView = true
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.delegate = context.coordinator
        textView.toneCycleLeft = toneCycleLeft
        textView.toneCycleRight = toneCycleRight
        textView.isHoveredNote = isHovered
        textView.isActiveAINote = isDimmed
        
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
        }

        if let layoutManager = nsView.layoutManager,
           let textContainer = nsView.textContainer {
            layoutManager.ensureLayout(for: textContainer)
            let usedRect = layoutManager.usedRect(for: textContainer)
            DispatchQueue.main.async {
                height = usedRect.height
            }
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
        let fontDescriptor = NSFont.systemFont(ofSize: 15, weight: .light).fontDescriptor
        let italicDescriptor = dimmed ? fontDescriptor.withSymbolicTraits(.italic) : fontDescriptor
        let font = NSFont(descriptor: italicDescriptor, size: 15) ?? NSFont.systemFont(ofSize: 15, weight: .light)
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: textColor]
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
                if let entryView = parent.focusModel.entry {
                    let notes = entryView.notes
                    if let index = notes.firstIndex(where: { $0.id == parent.id }) {
                        var notes = entryView.notes
                        notes.remove(at: index)
                        notes = notes.enumerated().map { (i, note) in
                            note.number = i + 1
                            return note
                        }
                        entryView.notes = notes
                        parent.focusModel.focusedNoteID = nil
                    }
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
            }
        }
    }
}

class FocusableTextView: NSTextView {
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
                } else if event.charactersIgnoringModifiers == "\r" || event.charactersIgnoringModifiers == "s" {
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
}
