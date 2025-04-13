//
//  CanvasView.swift
//  JournalApp
//
//  Created by Andrei Marincas on 12.04.2025.
//

import SwiftUI

struct CanvasView: View {
    @Binding var draftCanvasText: String
    var updateUndoRedo: (() -> Void)? = nil
    var persistText: (() -> Void)? = nil
    var undoManager: CustomUndoManager
    
    var body: some View {
        GeometryReader { geometry in
            CanvasTextEditor(
                text: $draftCanvasText,
                containerWidth: geometry.size.width,
                onEditingChanged: {
                    updateUndoRedo?()
                },
                onEditingEnded: {
                    persistText?()
                },
                undoManager: undoManager
            )
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color("EntryBackground"))
            )
            .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
