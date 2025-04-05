//
//  JournalChatView.swift
//  JournalApp
//
//  Created by Andrei Marincas on 05.04.2025.
//

import SwiftUI

struct ChatMessage: Identifiable {
    let id = UUID()
    let text: String
    let isUser: Bool
}

struct JournalChatView: View {
    let entry: JournalEntry
    @State private var messages: [ChatMessage] = [
        ChatMessage(text: "Hi, how are you feeling today?", isUser: false),
        ChatMessage(text: "Would you like to explore a thought or memory?", isUser: false)
    ]
    @State private var selectedMessageIndex = 0
    @FocusState private var isInputFocused: Bool
    @State private var isHovering = false
    @Binding var isInOwnWindow: Bool
    var popOutWindow: (() -> Void)?

    init(entry: JournalEntry, isInOwnWindow: Binding<Bool> = .constant(false), popOutWindow: (() -> Void)? = nil) {
        self.entry = entry
        self._isInOwnWindow = isInOwnWindow
        self.popOutWindow = popOutWindow
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Spacer()
                if !isInOwnWindow {
                    Button(action: {
                        popOutWindow?()
                    }) {
                        Image(systemName: "arrow.up.right.bottomleft.rectangle")
                            .frame(width: 28, height: 28)
                            .font(.system(size: 16, weight: .regular))
                            .padding(6)
                            .background(Color(NSColor.controlBackgroundColor))
                            .clipShape(Circle())
                            .opacity(isHovering ? 1.0 : 0.5)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.top, 6)
                    .padding(.trailing, 0)
                    .onHover { hovering in
                        isHovering = hovering
                    }
                }
                if isInOwnWindow {
                    Button(action: {
                        isInOwnWindow = false
                    }) {
                        Image(systemName: "arrow.down.left.topright.rectangle")
                            .frame(width: 28, height: 28)
                            .font(.system(size: 16, weight: .regular))
                            .padding(6)
                            .background(Color(NSColor.controlBackgroundColor))
                            .clipShape(Circle())
                            .opacity(isHovering ? 1.0 : 0.5)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.top, 6)
                    .padding(.trailing, 0)
                    .onHover { hovering in
                        isHovering = hovering
                    }
                }
            }

            MessagesView(messages: messages)
                .contentShape(Rectangle())
                .onTapGesture {
                    isInputFocused = false
                }

            Spacer()

            ChatInputView(isInputFocused: _isInputFocused, sendMessage: { message in
                messages.append(ChatMessage(text: message, isUser: true))
            })
        }
        .background(Color("ChatViewBackground"))
    }
}

// Add this below MessagesView
struct MessagesView: View {
    let messages: [ChatMessage]

    var body: some View {
        ScrollViewReader { scrollProxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(messages) { message in
                        MessageBubble(text: message.text, isUser: message.isUser)
                    }
                    Color.clear.frame(height: 1).id("bottom")
                }
                .padding(.vertical, 8)
                .onChange(of: messages.count) {
                    withAnimation {
                        scrollProxy.scrollTo("bottom", anchor: .bottom)
                    }
                }
            }
        }
    }
}

struct MessageBubble: View {
    let text: String
    let isUser: Bool

    var body: some View {
        HStack {
            if isUser { Spacer() }

            Text(text)
                .font(.system(size: 15, weight: .regular, design: .rounded))
                .foregroundColor(isUser ? .white : .primary)
                .lineSpacing(3)
                .padding(12)
                .background(isUser ? Color("UserMessageBubble") : Color.gray.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .frame(maxWidth: 380, alignment: isUser ? .trailing : .leading)
                .multilineTextAlignment(isUser ? .trailing : .leading)

            if !isUser { Spacer() }
        }
        .padding(.horizontal, 16)
    }
}

struct ChatInputView: View {
    @State private var inputText: String = ""
    @FocusState var isInputFocused: Bool
    let sendMessage: (String) -> Void

    var body: some View {
        HStack(alignment: .bottom, spacing: 4) {
            TextEditor(text: $inputText)
                .font(.system(size: 15, weight: .regular, design: .rounded))
                .foregroundColor(.primary.opacity(0.85))
                .padding(8)
                .frame(minWidth: 56, maxHeight: 56)
                .scrollContentBackground(.hidden)
                .focused($isInputFocused)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.gray.opacity(0.4), lineWidth: 1)
                )
                .background(Color(white: 0.96))
                .clipShape(RoundedRectangle(cornerRadius: 10))

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
                    .foregroundColor(.accentColor)
            }
            .buttonStyle(.plain)
            .padding(.bottom, 4)
            .padding(.leading, 2)
            .offset(x: 8)
            .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }
}
