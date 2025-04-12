//
//  NoteHorizonView.swift
//  JournalApp
//
//  Created by Andrei Marincas on 12.04.2025.
//

import SwiftUI

struct NoteHorizonView: View {
    @EnvironmentObject var viewModel: JournalEntryViewModel
    @EnvironmentObject var focusModel: JournalFocusModel
    @Binding var isHoveringNoteHorizon: Bool
    
    var body: some View {
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
