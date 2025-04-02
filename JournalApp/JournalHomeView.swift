//
//  JournalHomeView.swift
//  JournalApp
//
//  Created by Andrei Marincas on 01.04.2025.
//

import SwiftUI

struct JournalHomeView: View {
    @State private var entry: JournalEntry

    var body: some View {
        VStack(alignment: .leading) {
            ForEach(entry.notes.indices, id: \.self) { index in
                VStack(alignment: .leading, spacing: 4) {
                    TextEditor(text: $entry.notes[index].text)
                    Divider()
                        .background(Color.secondary.opacity(0.5))
                        .padding(.vertical, 4)
                }
            }
        }
    }
}
