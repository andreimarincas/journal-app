//
//  ChatInputView.swift
//  JournalApp
//
//  Created by Andrei Marincas on 13.04.2025.
//

import SwiftUI

struct ChatInputView: View {
    @State private var inputText: String = ""
    @State private var inputHeight: CGFloat = 36
    @FocusState var isInputFocused: Bool
    let sendMessage: (String) -> Void
    let isSummaryPanelVisible: Binding<Bool>
    let isDisabled: Bool
    @State private var isPulsating = false

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            HStack(alignment: .bottom, spacing: 4) {
                ResizingTextView(text: $inputText, height: $inputHeight, onCommit: {
                    let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty {
                        sendMessage(trimmed)
                        inputText = ""
                    }
                })
                .frame(height: inputHeight)
                .animation(nil, value: inputHeight)
                .background(Color("ChatInputBackground"))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.gray.opacity(0.4), lineWidth: 1)
                )

                if isDisabled {
                    Button(action: {
                        // Placeholder for stop action logic
                        NotificationCenter.default.post(name: .stopTypewriterAnimation, object: nil)
                    }) {
                        ZStack {
                            Circle()
                                .fill(Color.accentColor)
                                .frame(width: 28, height: 28)

                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                .fill(Color.white)
                                .frame(width: 11, height: 11)
//                                .scaleEffect(isPulsating ? 1.05 : 0.95)
//                                .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: isPulsating)
                                .onAppear {
                                    isPulsating = true
                                }
                                .onDisappear {
                                    isPulsating = false
                                }
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(.bottom, 4)
                    .padding(.leading, 2)
                    .offset(x: 8)
                } else {
                    Button {
                        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !trimmed.isEmpty {
                            sendMessage(trimmed)
                            inputText = ""
                        }
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .resizable()
                            .frame(width: 28, height: 28)
                            .foregroundStyle(.white, Color.accentColor)
                    }
                    .buttonStyle(.plain)
                    .padding(.bottom, 4)
                    .padding(.leading, 2)
                    .offset(x: 8)
                    .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
        .onChange(of: isInputFocused) { _, focused in
            if focused {
                isSummaryPanelVisible.wrappedValue = false
            }
        }
    }
}
