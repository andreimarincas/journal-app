//
//  MessageBubble.swift
//  JournalApp
//
//  Created by Andrei Marincas on 13.04.2025.
//

import SwiftUI
import MarkdownUI

struct MessageBubble: View {
    let text: String
    let isUser: Bool
    let isAI: Bool
    var isFocused: Bool = false
    let timestamp: Date?
    var animateTypewriter: Bool = false
    @State private var visibleText: String = ""
    @State private var didCancelTypewriter = false
    var onTypewriterStart: (() -> Void)? = nil
    var onTypewriterEnd: (() -> Void)? = nil
    @State private var isHovering = false
    @State private var isHoveringAddAsNoteButton: Bool = false
    @State private var isHoveringCopyButton: Bool = false
    @State private var didCopy: Bool = false
    
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var focusModel: JournalFocusModel

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(spacing: 0) {
                HStack {
                    if !isUser {
                        ZStack(alignment: .topLeading) {
                            markdownTextView(text)
                                .opacity(0)
                                .allowsHitTesting(false)
                            
                            markdownTextView(visibleText)
                                .onAppear {
                                    handleMarkdownTextOnAppear()
                                }
                        }
                        Spacer()
                    } else {
                        Spacer()
                        plainTextView(text)
                    }
                }
                bottomButtons
            }
        }
        .padding(.horizontal, 16)
//        .padding(.bottom, isUser ? 24 : 0)
        .onHover { hovering in
            isHovering = hovering
        }
        .onReceive(NotificationCenter.default.publisher(for: .stopTypewriterAnimation)) { _ in
            didCancelTypewriter = true
            visibleText = text
            onTypewriterEnd?()
        }
        .onChange(of: animateTypewriter) { _, newValue in
            if !newValue {
                didCancelTypewriter = true
                visibleText = text
                onTypewriterEnd?()
            }
        }
        .onAppear {
            print("👀 Rendering AI bubble with visibleText: \(visibleText)")
        }
    }
    
    private var bottomButtons: some View {
        HStack(spacing: 0) {
            if isUser {
                Spacer()
            }
            if isHovering {
                copyButton
                addAsNoteButton
            }
            if isAI {
                Spacer()
            }
        }
        .frame(height: 32)
        .padding(.top, isUser ? -4 : -12)
        .padding(.leading, isAI ? 4 : 0)
        .padding(.trailing, isUser ? -8 : 0)
    }
    
    private var addAsNoteButton: some View {
        Button(action: {
            guard let viewModel = self.focusModel.entryViewModel else { return }
            let newText = isAI ? "✨ " + text : text
            let newNote = viewModel.addNote(text: newText)
            self.focusModel.focusedNoteID = newNote.id
            NotificationCenter.default.post(name: .noteCreatedFromChat, object: newNote)
        }) {
            Image(systemName: "document.badge.plus")
                .font(.system(size: 14))
                .foregroundColor(.primary)
                .padding(6)
        }
        .buttonStyle(.plain)
        .frame(width: 32, height: 32)
//        .padding(.bottom, -34)
//        .padding(.trailing, -12)
        .help("Add this message as a note")
        .opacity(isHoveringAddAsNoteButton ? 1 : 0.5)
        .onHover { hovering in
            isHoveringAddAsNoteButton = hovering
        }
    }
    
    private var copyButton: some View {
        Button(action: {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
            didCopy = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                didCopy = false
            }
        }) {
            Image(systemName: didCopy ? "checkmark" : "square.on.square")
                .font(.system(size: 14))
                .foregroundColor(.primary)
                .padding(6)
        }
        .buttonStyle(.plain)
        .frame(width: 32, height: 32)
        .help("Copy this message")
        .opacity(isHoveringCopyButton ? 1 : 0.5)
        .onHover { hovering in
            isHoveringCopyButton = hovering
        }
    }
    
    private func handleMarkdownTextOnAppear() {
        if animateTypewriter && visibleText.isEmpty {
            onTypewriterStart?()
            for (index, character) in text.enumerated() {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.01) {
                    if !didCancelTypewriter {
                        if index < text.count - 1 {
                            if index > 0 && visibleText.last == "●" {
                                visibleText.removeLast()
                                visibleText.append(character)
                            } else {
                                visibleText.append(character)
                                visibleText.append("●")
                            }
                        } else {
                            if visibleText.last == "●" {
                                visibleText.removeLast()
                            }
                            visibleText.append(character)
                            onTypewriterEnd?()
                        }
                    }
                }
            }
        } else if !animateTypewriter {
            visibleText = text
        }
    }
    
    private func plainTextView(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 15, weight: .regular, design: .rounded))
            .textSelection(.enabled)
            .foregroundColor(colorScheme == .dark || isFocused ? .white : .black)
            .lineSpacing(6)
            .padding(12)
//                    .background(
//                        LinearGradient(
//                            gradient: Gradient(colors: [
//                                isFocused ? Color(hex: "#339CFF") : Color(hex: "#3B9DFB"),
//                                isFocused ? Color(hex: "#006FE0") : Color(hex: "#007AFF")
//                            ]),
//                            startPoint: .top,
//                            endPoint: .bottom
//                        )
//                    )
            .background(isFocused ? Color.accentColor : Color("BubbleUser"))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .frame(maxWidth: 380, alignment: isUser ? .trailing : .leading)
            .multilineTextAlignment(.leading)
    }
    
    private func markdownTextView(_ text: String) -> some View {
        Markdown(text)
            .markdownTheme(.custom)
            .markdownBlockStyle(\.blockquote) { configuration in
                configuration.label
                    .padding()
                    .markdownTextStyle {
                        FontCapsVariant(.lowercaseSmallCaps)
                        FontWeight(.semibold)
                        BackgroundColor(nil)
                    }
                    .overlay(alignment: .leading) {
                        Rectangle()
                            .fill(Color.teal)
                            .frame(width: 4)
                    }
                    .background(Color.teal.opacity(0.5))
            }
            .textSelection(.enabled)
            .lineSpacing(6)
            .padding(12)
            .foregroundColor(colorScheme == .dark ? Color.primary : Color(hex: "#FAFAFA"))
//                    .background(
//                        LinearGradient(
//                            gradient: Gradient(colors: [
//                                colorScheme == .dark ? Color(hex: "#4C4C4C") : Color(hex: "#ECECEC"),
//                                colorScheme == .dark ? Color(hex: "#3A3A3A") : Color(hex: "#ECECEC")
//                            ]),
//                            startPoint: .top,
//                            endPoint: .bottom
//                        )
//                    )
//                    .clipShape(RoundedRectangle(cornerRadius: 12))
//                    .frame(maxWidth: 380, alignment: isUser ? .trailing : .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .multilineTextAlignment(isUser ? .trailing : .leading)
    }
    
    static var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }
}

extension Theme {
    static let custom = Theme()
        .text {
            FontFamily(.system(.rounded))
            FontSize(15)
        }
        // Add other style customizations here
}
