//
//  JournalEntryView.swift
//  JournalApp
//
//  Created by Andrei Marincas on 01.04.2025.
//

import SwiftUI
import SwiftData

struct JournalEntryView: View {
    private(set) var entry: JournalEntry
    @EnvironmentObject private var focusModel: JournalFocusModel
    @State private var editedTexts: [UUID: String] = [:]
    
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
    }

    private var notesHeader: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("Notes")
                .font(.title)
                .bold()
                .foregroundStyle(.primary)
            Spacer()
            Text(entry.date.formatted(date: .long, time: .shortened))
                .font(.subheadline)
                .foregroundStyle(.secondary)
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
                        noteView(for: note)
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
            get: { editedTexts[note.id] ?? note.text },
            set: { if $0 != editedTexts[note.id] { editedTexts[note.id] = $0 }}
        ))
            .environmentObject(focusModel)
    }

    private struct NoteRow: View {
        let note: JournalNote
        let entry: JournalEntry
        let shouldFocus: Bool
        @Binding var editedText: String
        @EnvironmentObject private var focusModel: JournalFocusModel
        @State private var isHovering = false
        @State private var height: CGFloat = 22
        
        init(note: JournalNote, entry: JournalEntry, shouldFocus: Bool, editedText: Binding<String>) {
            self.note = note
            self.entry = entry
            self.shouldFocus = shouldFocus
            self._editedText = editedText
        }

        var body: some View {
            ZStack(alignment: .bottomTrailing) {
                VStack(alignment: .leading) {
                    HStack(alignment: .top, spacing: 8) {
                        VStack {
                            Text("\(note.number).")
                                .font(.system(size: 15, weight: .light))
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                        TextViewWrapper(text: $editedText, height: $height, shouldFocus: shouldFocus, id: note.id)
                            .frame(height: height)
                    }
                    .padding(.vertical, 4)
                    .padding(.top, 8)
                    Divider()
                        .frame(height: 0.5)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 4)
                        .padding(.leading, 26)
                }

                Button(action: {
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
                }) {
                    Image(systemName: "trash")
                        .imageScale(.medium)
                        .fontWeight(.thin)
                        .padding(8)
                }
                .buttonStyle(.plain)
                .padding(6)
                .opacity(isHovering ? 1 : 0)
            }
            .onHover { hovering in
                isHovering = hovering
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
    @EnvironmentObject var focusModel: JournalFocusModel
    
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
        textView.isEditable = true
        textView.isRichText = false
        textView.font = NSFont.systemFont(ofSize: 15, weight: .light)
        textView.drawsBackground = false
        textView.textContainerInset = NSSize(width: 0, height: 2)
        textView.textContainer?.widthTracksTextView = true
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.delegate = context.coordinator
        
        if shouldFocus {
            DispatchQueue.main.async {
                textView.window?.makeFirstResponder(textView)
            }
        }
        
        return textView
    }

    func updateNSView(_ nsView: NSTextView, context: Context) {
        if nsView.window?.firstResponder !== nsView, nsView.string != text {
            nsView.string = text
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
        }
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
        
        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
        }
    }
}

class FocusableTextView: NSTextView {
    var onFocusGained: (() -> Void)?
    var onFocusLost: (() -> Void)?

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
}
