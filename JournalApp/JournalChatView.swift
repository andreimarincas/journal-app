//
//  JournalChatView.swift
//  JournalApp
//
//  Created by Andrei Marincas on 05.04.2025.
//

import SwiftUI

struct JournalChatView: View {
    let entry: JournalEntry
    @State private var messages: [String] = [
        "Hi, how are you feeling today?",
        "Would you like to explore a thought or memory?"
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
                        NSApp.keyWindow?.close()
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

            ChatInputView(isInputFocused: _isInputFocused)
        }
        .background(Color("ChatViewBackground"))
    }

//    func popOutWindow() {
//        if NSApp.keyWindow != nil {
//            let newWindow = NSWindow(
//                contentRect: NSRect(x: 0, y: 0, width: 420, height: 640),
//                styleMask: [.titled, .closable, .resizable],
//                backing: .buffered,
//                defer: false
//            )
//            newWindow.title = "AI Companion"
//            newWindow.contentView = NSHostingView(rootView: JournalChatView(entry: entry, isInOwnWindow: true))
//            newWindow.makeKeyAndOrderFront(nil)
//        }
//    }
}

// Add this below MessagesView
struct MessagesView: View {
    let messages: [String]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(0..<messages.count, id: \.self) { index in
                    MessageBubble(text: messages[index])
                }
            }
            .padding(.vertical, 8)
        }
    }
}

struct MessageBubble: View {
    let text: String

    var body: some View {
        HStack(alignment: .top) {
            Text(text)
                .font(.system(size: 15, weight: .regular, design: .rounded))
                .foregroundColor(.primary.opacity(0.9))
                .lineSpacing(3)
                .padding(12)
                .background(Color.gray.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .frame(maxWidth: 380, alignment: .leading)
            Spacer()
        }
        .padding(.horizontal, 16)
    }
}

struct ChatInputView: View {
    @State private var inputText: String = ""
    @FocusState var isInputFocused: Bool

    var body: some View {
        HStack(alignment: .bottom, spacing: 4) {
            TextEditor(text: $inputText)
                .font(.system(size: 15, weight: .regular, design: .rounded))
                .foregroundColor(.primary.opacity(0.85))
                .padding(8)
                .frame(minHeight: 48, maxHeight: 80)
                .scrollContentBackground(.hidden)
                .focused($isInputFocused)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.gray.opacity(0.4), lineWidth: 1)
                )
                .background(Color(white: 0.96))
                .clipShape(RoundedRectangle(cornerRadius: 10))

            Button {
                // Handle sending message
                inputText = ""
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
