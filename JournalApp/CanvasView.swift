//
//  CanvasView.swift
//  JournalApp
//
//  Created by Andrei Marincas on 12.04.2025.
//

import SwiftUI

struct CanvasView: View {
    @Binding var draftCanvasText: String
    var persistText: (() -> Void)? = nil
    
    var body: some View {
        GeometryReader { geometry in
            CanvasTextEditor(
                text: $draftCanvasText,
                containerWidth: geometry.size.width,
                onEditingEnded: {
                    persistText?()
                }
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color("EntryBackground"))
        )
        .foregroundStyle(.primary)
    }
}
