//
//  CanvasView.swift
//  JournalApp
//
//  Created by Andrei Marincas on 12.04.2025.
//

import SwiftUI

struct CanvasText: Equatable {
    enum Source: String {
        case saved
        case draft
    }
    var text: String = ""
    var source: Source = .saved
}

struct CanvasView: View {
    @Binding var draftCanvasText: CanvasText
    @Binding var canRegisterUndo: Bool
    var updateUndoRedo: (() -> Void)? = nil
    var persistText: (() -> Void)? = nil
    var undoManager: CustomUndoManager
    
    @State private var displayedCanvasText = CanvasText()
    
    let animationDuration: Double = 10
    @State private var showsGradient: Bool = false
    @State private var gradientY: CGFloat = 0
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                CanvasTextEditor(
                    canvasText: $draftCanvasText,
                    canRegisterUndo: $canRegisterUndo,
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
                
//                if showsGradient {
//                    Rectangle()
//                        .fill(
//                            LinearGradient(
//                                gradient: Gradient(stops: [
//                                    .init(color: .white.opacity(0.0), location: 0.0),
//                                    .init(color: .white.opacity(1.0), location: 0.45),
//                                    .init(color: .white.opacity(1.0), location: 0.5),
//                                    .init(color: .white.opacity(1.0), location: 0.55),
//                                    .init(color: .white.opacity(0.0), location: 1.0)
//                                ]),
//                                startPoint: .top,
//                                endPoint: .bottom
//                            )
//                        )
//                        .frame(width: geometry.size.width, height: 100)
//                        .position(x: geometry.size.width / 2, y: gradientY)
//                }
            }
//            .onChange(of: draftCanvasText) { oldValue, newValue in
//                guard newValue.source == .draft else {
//                    displayedCanvasText = newValue
//                    return
//                }
//                
//                showsGradient = true
//                gradientY = 0
//                
//                withAnimation(.easeInOut(duration: animationDuration)) {
//                    gradientY = geometry.size.height
//                }
//                
//                DispatchQueue.main.asyncAfter(deadline: .now() + animationDuration) {
//                    displayedCanvasText = newValue
//                    showsGradient = false
//                }
//            }
//            .onChange(of: displayedCanvasText) { oldValue, newValue in
//                print("displayedCanvasText oldValue: \(oldValue)")
//                print("displayedCanvasText newValue: \(newValue)")
//            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
