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
    @ObservedObject var chatViewModel: JournalChatViewModel
    @EnvironmentObject private var focusModel: JournalFocusModel
    @Environment(\.modelContext) private var modelContext
    
    @State private var canTriggerLoad = true
    @State private var isAnimatingTypewriter: Bool = false
    
    init(chatViewModel: JournalChatViewModel, entry: JournalEntry, isInOwnWindow: Binding<Bool> = .constant(false), isChatVisible: Binding<Bool> = .constant(true), popOutWindow: (() -> Void)? = nil, isSummaryPanelVisible: Binding<Bool> = .constant(false)) {
        self.entry = entry
        self._isInOwnWindow = isInOwnWindow
        self._isChatVisible = isChatVisible
        self.popOutWindow = popOutWindow
        self._isSummaryPanelVisible = isSummaryPanelVisible
        self.chatViewModel = chatViewModel
    }
    
    var isLoadingOlderMessages: Bool { !canTriggerLoad }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            topButtons
            
            MessagesView(chatViewModel: chatViewModel, canTriggerLoad: $canTriggerLoad, isAnimatingTypewriter: $isAnimatingTypewriter)
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
                isSummaryPanelVisible: $isSummaryPanelVisible,
                isDisabled: isAnimatingTypewriter
            )
        }
        .background(Color("ChatViewBackground"))
        .onChange(of: focusModel.pinnedNoteID) { _, newValue in
            if let _ = newValue, let message = focusModel.pendingChatMessage {
                chatViewModel.sendFocusedNoteToGPT(message: message, context: focusModel.pendingChatMessageContext, pinnedNoteID: focusModel.pinnedNoteID)
            }
        }
        .onAppear {
            chatViewModel.startChat(title: entry.title, notes: entry.notes.map(\.text), entryID: entry.id)
        }
        .onChange(of: entry.id) { _, newID in
            chatViewModel.insertSystemMessage("Switched to: \(entry.title)")
            chatViewModel.startChat(title: entry.title, notes: entry.notes.map(\.text), entryID: entry.id)
        }
    }
    
    private var topButtons: some View {
        HStack {
            Spacer()
            ProgressView()
                .progressViewStyle(.circular)
                .foregroundStyle(Color.red)
                .frame(width: 44, height: 44)
                .scaleEffect(0.7)
                .padding(.top, 8)
                .offset(x: 28)
                .opacity(isLoadingOlderMessages ? 1 : 0)
                .animation(.easeInOut(duration: 0.3), value: isLoadingOlderMessages)
            .allowsHitTesting(false)
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
                    NotificationCenter.default.post(name: .stopTypewriterAnimation, object: nil)
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

struct TypingIndicator: View {
    @State private var isVisible: Bool = true

    let timer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

    var body: some View {
        Text("●")
            .font(.system(size: 15))
            .foregroundColor(Color("TypingIndicator"))
            .scaleEffect(isVisible ? 1.1 : 0.8)
            .animation(.easeInOut(duration: 0.4), value: isVisible)
            .padding(12)
            .padding(.leading, 14)
            .onReceive(timer) { _ in
                withAnimation(.easeInOut(duration: 0.4)) {
                    isVisible.toggle()
                }
            }
    }
}

private struct ScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGPoint = .zero
    
    static func reduce(value: inout CGPoint, nextValue: () -> CGPoint) {
    }
}

struct MessagesView: View {
    @ObservedObject var chatViewModel: JournalChatViewModel
    @EnvironmentObject private var focusModel: JournalFocusModel
    @Binding private var canTriggerLoad: Bool
    
    var messages: [ChatMessage] { chatViewModel.messages }
    var isTyping: Bool { chatViewModel.isTyping }
    
    @State private var scrollOffset: CGPoint = .zero
    @State private var contentHeight: CGFloat = 0
    @State private var firstVisibleID: UUID?
    @State private var showScrollIndicator: Bool = true
    @Binding private var isAnimatingTypewriter: Bool
    
    init(chatViewModel: JournalChatViewModel, canTriggerLoad: Binding<Bool>, isAnimatingTypewriter: Binding<Bool>) {
        self.chatViewModel = chatViewModel
        self._canTriggerLoad = canTriggerLoad
        self._isAnimatingTypewriter = isAnimatingTypewriter
    }
    
    var body: some View {
        ZStack {
            ScrollViewReader { scrollProxy in
                ScrollView() {
                    messagesContentView
                        .padding(.vertical, 8)
                        .background(
                            GeometryReader { geometry in
                                Color.clear
                                    .preference(key: ScrollOffsetPreferenceKey.self, value: geometry.frame(in: .named("scroll")).origin)
                            }
                        )
                        .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
                            print("📌 onPreferenceChange: scrollOffset = \(value)")
                            self.scrollOffset = value
                        }
                    
                        .onChange(of: messages.count) {
                            guard canTriggerLoad else { return }
                            showScrollIndicator = false
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                                withAnimation(.interpolatingSpring(mass: 1.6, stiffness: 20, damping: 4, initialVelocity: 0)) {
                                    scrollProxy.scrollTo("bottom", anchor: .bottom)
                                } completion: {
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                        showScrollIndicator = true
                                    }
                                }
                            }
                        }
                        .onAppear {
                            DispatchQueue.main.async {
                                scrollProxy.scrollTo("bottom", anchor: .bottom)
                            }
                        }
                }
                .scrollIndicators(showScrollIndicator ? .visible : .hidden)
                .coordinateSpace(name: "scroll")
                .onChange(of: scrollOffset) {
                    if scrollOffset.y > 5 && canTriggerLoad {
                        print("Trigger load older messages... scrollOffset.y: \(scrollOffset.y)")
                        canTriggerLoad = false
                        firstVisibleID = messages.first?.id
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            chatViewModel.loadOlderMessages()
                            DispatchQueue.main.async {
                                canTriggerLoad = true
                            }
                        }
                    }
                }
                .onChange(of: messages) {
                    if !canTriggerLoad {
                        if let anchorID = self.firstVisibleID {
                            scrollProxy.scrollTo(anchorID, anchor: .zero)
                            DispatchQueue.main.async {
                                scrollProxy.scrollTo(anchorID, anchor: .zero)
                            }
                        }
                        DispatchQueue.main.async {
                            canTriggerLoad = true
                        }
                    }
                }
            }
            .environmentObject(focusModel)
            
            // Overlay blocker
            if !canTriggerLoad {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {} // absorb touches
                    .gesture(DragGesture()) // block scroll gestures
            }
        }
        .onChange(of: canTriggerLoad) { oldValue, newValue in
            print("onchange canTriggerLoad oldValue: \(oldValue), newValue: \(newValue)")
        }
    }
    
    var messagesContentView: some View {
        VStack(alignment: .leading, spacing: 16) {
            let pinnedNoteID = focusModel.pinnedNoteID
            let pendingText = focusModel.pendingChatMessageContext?.userMessage
            let matchingMessages = messages.filter { $0.text == pendingText && $0.isUser }
            let lastMatchingMessageID = matchingMessages.last?.id
            
            let processedMessages = messages.map { message in
                (message, (message.timeIntervalSincePrevious ?? 999) > 5)
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
                        let isLatestAIMessage = message.id == chatViewModel.lastAnimatedMessageID
                        let shouldAnimateTypewriter = isLatestAIMessage && chatViewModel.messages.last?.id == message.id
                        
                        MessageBubble(
                            text: message.text,
                            isUser: message.isUser,
                            isAI: !message.isUser && !message.isSystem,
                            isFocused: isFocusedMessage, //|| isMostRecentUserMessage,
                            timestamp: message.timestamp,
                            animateTypewriter: shouldAnimateTypewriter,
                            onTypewriterStart: { isAnimatingTypewriter = true },
                            onTypewriterEnd: { isAnimatingTypewriter = false }
                        )
                        .environmentObject(focusModel)
                    }
                }
                .id(message.id)
            }
            
            if isTyping {
                TypingIndicator()
            }
            Color.clear.frame(height: 1).id("bottom")
            .onReceive(NotificationCenter.default.publisher(for: .noteCreatedFromChat)) { notification in
                guard let note = notification.object as? JournalNote else { return }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    scrollToNote(note)
                }
            }
        }
    }
    
    private func scrollToNote(_ note: JournalNote) {
        NotificationCenter.default.post(name: .scrollToNote, object: note)
    }
}

struct ContentSizeKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
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
            .padding(.leading, 12)
    }
}

struct TimestampDividerView: View {
    let date: Date
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var focusModel: JournalFocusModel

    var body: some View {
        Text(Self.formatter.string(from: date))
            .font(.caption2)
            .foregroundColor(colorScheme == .dark ? .gray.opacity(0.6) : .gray)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
    }

    static var formatter: DateFormatter {
        let df = DateFormatter()
        df.timeStyle = .short
        df.dateStyle = .medium
        df.locale = .current
        return df
    }
}

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
            .multilineTextAlignment(isUser ? .trailing : .leading)
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
