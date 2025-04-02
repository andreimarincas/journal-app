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
                ForEach(entry.notes.sorted(by: { $0.number < $1.number })) { note in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("\(note.number).")
                            .font(.system(size: 15, weight: .light))
                            .foregroundColor(.secondary)
                        Text(note.text)
                            .font(.system(size: 15, weight: .light))
                            .lineSpacing(6)
                            .multilineTextAlignment(.leading)
                            .foregroundStyle(.primary)
                    }
                    .padding(.vertical, 4)
                }
                Spacer()
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }
}
