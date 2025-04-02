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
        NoteRow(note: note, entry: entry)
    }

    private struct NoteRow: View {
        let note: JournalNote
        let entry: JournalEntry
        @State private var isHovering = false
        @State private var editedText: String
        
        init(note: JournalNote, entry: JournalEntry) {
            self.note = note
            self.entry = entry
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
                        TextEditor(text: $editedText)
                            .textEditorStyle(.plain)
                            .font(.system(size: 15, weight: .light))
                            .padding(.vertical, 0)
                            .frame(minHeight: 22, alignment: .top)
                            .scrollIndicators(.hidden)
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
                    let newNote = JournalNote(number: nextNumber, text: "Newly added note.")
                    entry.notes.append(newNote)
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
