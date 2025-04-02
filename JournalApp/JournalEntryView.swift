//
//  JournalEntryView.swift
//  JournalApp
//
//  Created by Andrei Marincas on 01.04.2025.
//

import SwiftUI
import SwiftData

struct JournalEntryView: View {
    var entry: JournalEntry

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
        let isLast = note.id == entry.notes.last?.id && note.text.isEmpty
        return NoteRow(note: note, entry: entry, shouldFocus: isLast)
    }

    private struct NoteRow: View {
        let note: JournalNote
        let entry: JournalEntry
        let shouldFocus: Bool
        @State private var isHovering = false
        @State private var editedText: String
        @State private var height: CGFloat = 22
        
        init(note: JournalNote, entry: JournalEntry, shouldFocus: Bool) {
            self.note = note
            self.entry = entry
            self.shouldFocus = shouldFocus
            _editedText = State(initialValue: note.text)
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
                        TextViewWrapper(text: $editedText, height: $height, shouldFocus: shouldFocus)
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
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        // Focus the newly added note
                    }
                }) {
                    Image(systemName: "plus")
                        .imageScale(.large)
                        .font(.system(size: 20, weight: .medium))
                        .padding(14)
                        .background(.thinMaterial, in: Circle())
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

    func makeNSView(context: Context) -> NSTextView {
        let textView = NSTextView()
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
        if nsView.string != text {
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
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: TextViewWrapper

        init(_ parent: TextViewWrapper) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
        }
    }
}
