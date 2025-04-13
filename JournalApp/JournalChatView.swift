//
//  JournalChatView.swift
//  JournalApp
//
//  Created by Andrei Marincas on 05.04.2025.
//

import SwiftUI
import AppKit
import SwiftData

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
    @AppStorage("isCanvasMergeModeEnabled") private var storedCanvasMergeModeEnabled = false
    @State private var isCanvasMergeModeEnabled = false
    
    init(chatViewModel: JournalChatViewModel,
         entry: JournalEntry,
         isInOwnWindow: Binding<Bool> = .constant(false),
         isChatVisible: Binding<Bool> = .constant(true),
         popOutWindow: (() -> Void)? = nil,
         isSummaryPanelVisible: Binding<Bool> = .constant(false)
    ) {
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
                    chatViewModel.sendInputUserMessage(text: message, syncWithCanvas: isCanvasMergeModeEnabled)
                },
                isSummaryPanelVisible: $isSummaryPanelVisible,
                isDisabled: isAnimatingTypewriter
            )
        }
        .background(Color("ChatViewBackground"))
        .onChange(of: focusModel.pinnedNoteID) { _, newValue in
            if let _ = newValue, let message = focusModel.pendingChatMessage {
                chatViewModel.sendFocusedNoteToGPT(message: message, context: focusModel.pendingChatMessageContext, pinnedNoteID: focusModel.pinnedNoteID, syncWithCanvas: isCanvasMergeModeEnabled)
            }
        }
        .onAppear {
            if focusModel.viewMode == .canvas {
                isCanvasMergeModeEnabled = storedCanvasMergeModeEnabled
            } else {
                isCanvasMergeModeEnabled = false
            }
            chatViewModel.startChat(title: entry.title, notes: entry.notes.map(\.text), entryID: entry.id)
        }
        .onChange(of: focusModel.viewMode) { _, newValue in
            if newValue == .canvas {
                isCanvasMergeModeEnabled = storedCanvasMergeModeEnabled
            } else {
                isCanvasMergeModeEnabled = false
            }
        }
        .onChange(of: entry.id) { _, newID in
            chatViewModel.insertSystemMessage("Switched to: \(entry.title)")
            chatViewModel.startChat(title: entry.title, notes: entry.notes.map(\.text), entryID: entry.id)
        }
    }
    
    private var topButtons: some View {
        ZStack {
            HStack() {
                Toggle(isOn: Binding(
                    get: { isCanvasMergeModeEnabled },
                    set: {
                        if focusModel.viewMode == .canvas {
                            isCanvasMergeModeEnabled = $0
                            storedCanvasMergeModeEnabled = $0
                        } else {
                            isCanvasMergeModeEnabled = $0
                            if $0 == true {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                    self.isCanvasMergeModeEnabled = false
                                }
                            }
                        }
                    }
                )) {
                    Text("Sync with Canvas")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                .toggleStyle(SwitchToggleStyle(tint: Color.accentColor))
                .padding(.leading, 24)
                .padding(.top, 8)
                
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
            
            HStack() {
                Spacer()
                ProgressView()
                    .progressViewStyle(.circular)
                    .foregroundStyle(Color.red)
                    .frame(width: 44, height: 44)
                    .scaleEffect(0.7)
                    .padding(.top, 8)
                    .opacity(isLoadingOlderMessages ? 1 : 0)
                    .animation(.easeInOut(duration: 0.3), value: isLoadingOlderMessages)
                    .allowsHitTesting(false)
                Spacer()
            }
            
//            VStack {
//                Rectangle()
//                    .fill(Color.gray.opacity(0.15))
//                    .offset(y: 26)
//                    .frame(height: 1)
//            }
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
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Text(text)
            .font(.system(size: 12))
            .italic()
            .foregroundColor(colorScheme == .dark ? .gray.opacity(0.6) : .gray)
            .padding(.horizontal, 12)
            .padding(.leading, 14)
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
