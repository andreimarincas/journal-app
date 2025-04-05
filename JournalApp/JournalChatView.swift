//
//  JournalChatView.swift
//  JournalApp
//
//  Created by Andrei Marincas on 05.04.2025.
//

import SwiftUI

struct ChatMessage: Identifiable, Equatable {
    let id = UUID()
    let text: String
    let isUser: Bool
}

struct JournalChatView: View {
    let entry: JournalEntry
    @Binding var isChatVisible: Bool
    @State private var messages: [ChatMessage] = [
        ChatMessage(text: "Hi, how are you feeling today?", isUser: false),
        ChatMessage(text: "Would you like to explore a thought or memory?", isUser: false)
    ]
    @State private var selectedMessageIndex = 0
    @FocusState private var isInputFocused: Bool
    @State private var isHoveringHide = false
    @State private var isHoveringPopOut = false
    @State private var isHoveringDock = false
    @Binding var isInOwnWindow: Bool
    var popOutWindow: (() -> Void)?
    
    @State private var gptClient = GPTClient(apiKey: Bundle.main.object(forInfoDictionaryKey: "OpenAI_API_Key") as? String ?? "")
    @State private var isTyping = false

    init(entry: JournalEntry, isInOwnWindow: Binding<Bool> = .constant(false), isChatVisible: Binding<Bool> = .constant(true), popOutWindow: (() -> Void)? = nil) {
        self.entry = entry
        self._isInOwnWindow = isInOwnWindow
        self._isChatVisible = isChatVisible
        self.popOutWindow = popOutWindow
    }

    private func sendToGPT() {
        Task {
            let gptMessages = messages.map {
                GPTMessage(role: $0.isUser ? "user" : "assistant", content: $0.text)
            }
            isTyping = true
            do {
                let response = try await gptClient.send(messages: gptMessages)
                isTyping = false
                messages.append(ChatMessage(text: response, isUser: false))
            } catch {
                isTyping = false
                messages.append(ChatMessage(text: "Error: \(error.localizedDescription)", isUser: false))
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Spacer()
                Button(action: {
                    isChatVisible = false
                }) {
                    Image(systemName: "eye.slash")
                        .frame(width: 28, height: 28)
                        .font(.system(size: 16, weight: .regular))
                        .padding(6)
                        .background(Color(NSColor.controlBackgroundColor))
                        .clipShape(Circle())
                        .opacity(isHoveringHide ? 1.0 : 0.5)
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.top, 6)
                .padding(.trailing, 0)
                .onHover { hovering in
                    isHoveringHide = hovering
                }
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
                            .opacity(isHoveringPopOut ? 1.0 : 0.5)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.top, 6)
                    .padding(.trailing, 0)
                    .onHover { hovering in
                        isHoveringPopOut = hovering
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
                            .opacity(isHoveringDock ? 1.0 : 0.5)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.top, 6)
                    .padding(.trailing, 0)
                    .onHover { hovering in
                        isHoveringDock = hovering
                    }
                }
            }

            MessagesView(messages: messages, isTyping: isTyping)
                .contentShape(Rectangle())
                .onTapGesture {
                    isInputFocused = false
                }

            Spacer()

            ChatInputView(isInputFocused: _isInputFocused, sendMessage: { message in
                messages.append(ChatMessage(text: message, isUser: true))
                sendToGPT()
            })
        }
        .background(Color("ChatViewBackground"))
    }
}

// Add this below MessagesView
struct MessagesView: View {
    let messages: [ChatMessage]
    let isTyping: Bool

    var body: some View {
        ScrollViewReader { scrollProxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(messages) { message in
                        if message.isUser {
                            MessageBubble(text: message.text, isUser: message.isUser)
                                .transition(.move(edge: .bottom))
                        } else {
                            MessageBubble(text: message.text, isUser: message.isUser)
                                .transition(.opacity)
                        }
                    }
                    if isTyping {
                        TypingIndicator()
                    }
                    Color.clear.frame(height: 1).id("bottom")
                }
                .padding(.vertical, 8)
                .animation(.easeInOut(duration: 0.2), value: messages)
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
                .foregroundColor(Color("ChatInputText"))
                .padding(8)
                .frame(minWidth: 56, maxHeight: 56)
                .scrollContentBackground(.hidden)
                .focused($isInputFocused)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.gray.opacity(0.4), lineWidth: 1)
                )
                .background(Color("ChatInputBackground"))
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
                    .foregroundStyle(.white, Color.accentColor)
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

struct TypingIndicator: View {
    @State private var currentDot: Int = -1

    let timer = Timer.publish(every: 0.25, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<3) { index in
                Circle()
                    .frame(width: 6, height: 6)
                    .offset(y: currentDot == index ? -6 : 0)
                    .animation(.easeInOut(duration: 0.35), value: currentDot)
            }
        }
        .foregroundColor(.gray)
        .padding(12)
        .background(Color.gray.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 16)
        .onReceive(timer) { _ in
            withAnimation {
                currentDot = (currentDot + 1) % 5
            }
        }
    }
}
