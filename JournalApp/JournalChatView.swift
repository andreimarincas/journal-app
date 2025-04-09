//
//  JournalChatView.swift
//  JournalApp
//
//  Created by Andrei Marincas on 05.04.2025.
//

import SwiftUI
import AppKit
import MarkdownUI
import SwiftData

extension Theme {
    static let custom = Theme()
        .text {
            FontFamily(.system(.rounded))
            FontSize(15)
        }
        // Add other style customizations here
}

struct JournalChatView: View {
    let entry: JournalEntry
    @Binding var isChatVisible: Bool
    
    @State private var selectedMessageIndex = 0
    @FocusState private var isInputFocused: Bool
    @State private var isHoveringHide = false
    @State private var isHoveringPopOut = false
    @State private var isHoveringDock = false
    @State private var isHoveringPinnedMessage = false
    @Binding var isInOwnWindow: Bool
    var popOutWindow: (() -> Void)?
    
    @Binding private var isSummaryPanelVisible: Bool
    
    @StateObject private var chatViewModel: JournalChatViewModel = {
        // Preview fallback with in-memory modelContext
        let schema = Schema([ChatMessage.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: schema, configurations: [config])
        return JournalChatViewModel(dataSource: ChatMessageDataSource(modelContext: container.mainContext))
    }()
    
    @EnvironmentObject private var focusModel: JournalFocusModel
    
    @Environment(\.modelContext) private var modelContext
    
    init(entry: JournalEntry, isInOwnWindow: Binding<Bool> = .constant(false), isChatVisible: Binding<Bool> = .constant(true), popOutWindow: (() -> Void)? = nil, isSummaryPanelVisible: Binding<Bool> = .constant(false)) {
        self.entry = entry
        self._isInOwnWindow = isInOwnWindow
        self._isChatVisible = isChatVisible
        self.popOutWindow = popOutWindow
        self._isSummaryPanelVisible = isSummaryPanelVisible
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
            
            MessagesView(messages: chatViewModel.messages, isTyping: chatViewModel.isTyping)
                .contentShape(Rectangle())
                .onTapGesture {
                    isInputFocused = false
                    isSummaryPanelVisible = false
                }

            Spacer()

            ChatInputView(
                isInputFocused: _isInputFocused,
                sendMessage: { message in
                    chatViewModel.sendInputUserMessage(text: message)
                },
                isSummaryPanelVisible: $isSummaryPanelVisible
            )
        }
        .background(Color("ChatViewBackground"))
        .onChange(of: focusModel.pinnedNoteID) { _, newValue in
            if let message = focusModel.pendingChatMessage {
                chatViewModel.sendFocusedNoteToGPT(message: message, context: focusModel.pendingChatMessageContext, pinnedNoteID: focusModel.pinnedNoteID)
            }
        }
        .onAppear {
            if chatViewModel.isUsingPreviewContext {
                chatViewModel.replaceDataSource(with: ChatMessageDataSource(modelContext: modelContext))
            }
            chatViewModel.startChat(title: entry.title, notes: entry.notes.map(\.text))
        }
        .onChange(of: entry.id) { _, newID in
            chatViewModel.startChat(title: entry.title, notes: entry.notes.map(\.text))
            chatViewModel.messages.append(ChatMessage(text: "Switched to: \(entry.title)", isUser: false, isSystem: true))
        }
    }
}

struct ResizingTextView: NSViewRepresentable {
    @Binding var text: String
    @Binding var height: CGFloat
    var onCommit: (() -> Void)?

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false

        if let textView = scrollView.documentView as? NSTextView {
            textView.delegate = context.coordinator
            textView.font = NSFont.systemFont(ofSize: 15)
            textView.isEditable = true
            textView.isSelectable = true
            textView.isHorizontallyResizable = false
            textView.isVerticallyResizable = true
            textView.textContainer?.widthTracksTextView = true
            textView.backgroundColor = .clear
            textView.textContainerInset = NSSize(width: 4, height: 8)
        }

        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        if let textView = nsView.documentView as? NSTextView {
            if textView.string != text {
                textView.string = text
            }

            guard let layoutManager = textView.layoutManager,
                  let container = textView.textContainer else { return }

            layoutManager.ensureLayout(for: container)
            let usedRect = layoutManager.usedRect(for: container)
            let calculatedHeight = usedRect.height + 16
            let clampedHeight = min(max(calculatedHeight, 36), 92)

            DispatchQueue.main.async {
                self.height = clampedHeight
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, onCommit: onCommit)
    }

    class Coordinator: NSObject, NSTextViewDelegate {
        @Binding var text: String
        var onCommit: (() -> Void)?

        init(text: Binding<String>, onCommit: (() -> Void)? = nil) {
            _text = text
            self.onCommit = onCommit
        }

        func textDidChange(_ notification: Notification) {
            if let textView = notification.object as? NSTextView {
                self.text = textView.string
            }
        }

        func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                if NSEvent.modifierFlags.contains(.shift) {
                    return false // allow new line
                } else {
                    onCommit?()
                    return true // prevent default enter behavior
                }
            }
            return false
        }
    }
}

struct ChatInputView: View {
    @State private var inputText: String = ""
    @State private var inputHeight: CGFloat = 36
    @FocusState var isInputFocused: Bool
    let sendMessage: (String) -> Void
    let isSummaryPanelVisible: Binding<Bool>

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
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
        .onChange(of: isInputFocused) { _, focused in
            if focused {
                isSummaryPanelVisible.wrappedValue = false
            }
        }
    }
}

struct TypingIndicator: View {
    @State private var currentDot: Int = -1

    let timer = Timer.publish(every: 0.25, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<3) { index in
                Circle()
                    .frame(width: 5, height: 5)
                    .offset(y: currentDot == index ? -5 : 0)
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

extension Notification.Name {
    static let textViewHeightDidChange = Notification.Name("textViewHeightDidChange")
}

struct MessagesView: View {
    @EnvironmentObject private var focusModel: JournalFocusModel
    let messages: [ChatMessage]
    let isTyping: Bool
    
    var body: some View {
        ScrollViewReader { scrollProxy in
            ScrollView {
                messagesContentView
                    .padding(.vertical, 8)
                    .onChange(of: messages.count) {
                        withAnimation {
                            scrollProxy.scrollTo("bottom", anchor: .bottom)
                        }
                    }
            }
        }
        .environmentObject(focusModel)
    }
    
    var messagesContentView: some View {
        VStack(alignment: .leading, spacing: 16) {
            let pinnedNoteID = focusModel.pinnedNoteID
            let pendingText = focusModel.pendingChatMessageContext?.userMessage
            let matchingMessages = messages.filter { $0.text == pendingText && $0.isUser }
            let lastMatchingMessageID = matchingMessages.last?.id
            
            let processedMessages = messages.reduce(into: [(ChatMessage, Bool)]()) { result, message in
                let ts = message.timestamp
                let showDivider: Bool
                if let last = result.last?.0.timestamp {
                    showDivider = ts.timeIntervalSince(last) > 300
                } else {
                    showDivider = true
                }
                result.append((message, showDivider))
            }
            
            ForEach(processedMessages, id: \.0.id) { message, showDivider in
                Group {
                    if showDivider {
                        TimestampDividerView(date: message.timestamp)
                    }
                    
                    if message.isSystem {
                        SystemMessageView(text: message.text)
                    } else {
                        let isFocusedMessage = pinnedNoteID != nil && message.id == lastMatchingMessageID
                        MessageBubble(
                            text: message.text,
                            isUser: message.isUser,
                            isFocused: isFocusedMessage,
                            timestamp: message.timestamp
                        )
                    }
                }
            }
            if isTyping {
                TypingIndicator()
            }
            Color.clear.frame(height: 1).id("bottom")
        }
    }
}

struct SystemMessageView: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 13))
            .italic()
            .foregroundColor(.gray)
            .padding(.horizontal, 16)
            .padding(.top, 8)
    }
}

struct TimestampDividerView: View {
    let date: Date

    var body: some View {
        Text(Self.formatter.string(from: date))
            .font(.caption2)
            .foregroundColor(.gray)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
    }

    static var formatter: DateFormatter {
        let df = DateFormatter()
        df.timeStyle = .short
        df.dateStyle = .none
        return df
    }
}

struct MessageBubble: View {
    let text: String
    let isUser: Bool
    var isFocused: Bool = false
    let timestamp: Date?

    var body: some View {
        HStack {
            if !isUser {
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
                    .padding(12)
                    .foregroundColor(.primary)
                    .background(Color.gray.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .frame(maxWidth: 380, alignment: isUser ? .trailing : .leading)
                    .multilineTextAlignment(isUser ? .trailing : .leading)
                Spacer()
            } else {
                Spacer()
                Text(text)
                    .font(.system(size: 15, weight: .regular, design: .rounded))
                    .textSelection(.enabled)
                    .foregroundColor(isUser ? .white : .primary)
                    .lineSpacing(3)
                    .padding(12)
                    .background(isFocused ? Color.accentColor : Color("UserMessageBubble"))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .frame(maxWidth: 380, alignment: isUser ? .trailing : .leading)
                    .multilineTextAlignment(isUser ? .trailing : .leading)
            }
        }
        .padding(.horizontal, 16)
    }
    
    static var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }
}
