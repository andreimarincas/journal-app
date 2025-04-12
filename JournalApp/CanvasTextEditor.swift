//
//  CanvasTextEditor.swift
//  JournalApp
//
//  Created by Andrei Marincas on 11.04.2025.
//

import SwiftUI
import AppKit

struct CanvasTextEditor: NSViewRepresentable {
    @Binding var text: String
    var containerWidth: CGFloat? = nil
    var onEditingEnded: (() -> Void)? = nil
    let font: NSFont = .systemFont(ofSize: JournalLayoutConstants.canvasFontSize, weight: .regular)
    
    private var textAttributes: [NSAttributedString.Key : Any] {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 7
        paragraphStyle.paragraphSpacing = 9
        paragraphStyle.firstLineHeadIndent = 18
        paragraphStyle.paragraphSpacingBefore = 0
        paragraphStyle.alignment = .justified
        return [
            .font: font,
            .foregroundColor: NSColor.labelColor,
            .paragraphStyle: paragraphStyle
        ]
    }
    
    private func makeAttributedText(_ text: String) -> NSAttributedString {
        let attributedText = NSMutableAttributedString(string: text)
        let fullRange = NSRange(location: 0, length: attributedText.length)
        attributedText.addAttributes(textAttributes, range: fullRange)

        let paragraphs = text.components(separatedBy: .newlines)
        var position = 0
        for paragraph in paragraphs {
            let trimmed = paragraph.trimmingCharacters(in: .whitespaces)
            let length = (paragraph as NSString).length
            let range = NSRange(location: position, length: length)
            if trimmed.hasPrefix("✨") {
                let italicFont = NSFontManager.shared.convert(font, toHaveTrait: .italicFontMask)
                attributedText.addAttribute(.font, value: italicFont, range: range)
                attributedText.addAttribute(.foregroundColor, value: NSColor.secondaryLabelColor, range: range)
            }
            position += length + 1
        }
        return attributedText
    }
    
    private func scrollToEnd(_ textView: NSTextView) {
        if let scrollView = textView.enclosingScrollView {
            let contentHeight = textView.bounds.height
            let visibleHeight = scrollView.contentView.bounds.height
            let maxY = max(0, contentHeight - visibleHeight)
            let newOrigin = NSPoint(x: 0, y: maxY)
            scrollView.contentView.animator().setBoundsOrigin(newOrigin)
            scrollView.reflectScrolledClipView(scrollView.contentView)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let textView = PlaceholderTextView()
        textView.delegate = context.coordinator
        textView.isEditable = true
        textView.isSelectable = true
        textView.isRichText = false
        textView.usesRuler = false
        textView.drawsBackground = false
        textView.allowsUndo = true
         textView.textContainerInset = NSSize(width: 20, height: 26)

        textView.font = font
        
        textView.textContainer?.widthTracksTextView = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]

        textView.defaultParagraphStyle = textAttributes[.paragraphStyle] as? NSParagraphStyle
        textView.typingAttributes = textAttributes

        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.drawsBackground = false
        scrollView.documentView = textView
        
        scrollView.autoresizingMask = [.width, .height]

        context.coordinator.textView = textView
        
        textView.textStorage?.setAttributedString(makeAttributedText(text))
        
        NotificationCenter.default.addObserver(forName: .scrollToNote, object: nil, queue: .main) { notification in
            if let newNote = notification.object as? JournalNote {
                scrollToEnd(textView)
                // Only auto-focus the text view if the new note is empty.
                // This avoids stealing focus when the note comes from chat-based text generation.
                if newNote.text == "" {
                    DispatchQueue.main.async {
                        textView.window?.makeFirstResponder(textView)
                        textView.setSelectedRange(NSRange(location: textView.string.count, length: 0))
                    }
                }
            }
        }
        
        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? NSTextView else { return }
        
        if let viewWidth = containerWidth {
            let maxTextWidth: CGFloat = JournalLayoutConstants.maxCanvasTextWidth
            let horizontalInset = max((viewWidth - maxTextWidth) / 2, 20)
            textView.textContainerInset = NSSize(width: horizontalInset, height: 26)
        }

        if textView.string != text {
            textView.textStorage?.setAttributedString(makeAttributedText(text))
            if !context.coordinator.hasInitializedScroll {
                context.coordinator.hasInitializedScroll = true
                DispatchQueue.main.async {
                    textView.scroll(NSPoint(x: 0, y: 0))
                }
            }
        }

        textView.layoutManager?.ensureLayout(for: textView.textContainer!)
        
        if context.coordinator.needsInitialScrollToTop {
            context.coordinator.needsInitialScrollToTop = false
            DispatchQueue.main.async {
                textView.scroll(NSPoint(x: 0, y: 0))
            }
        }
    }

    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: CanvasTextEditor
        weak var textView: NSTextView?
        var hasInitializedScroll = false
        var needsInitialScrollToTop = true

        init(_ parent: CanvasTextEditor) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = textView else { return }
            let selectedRange = textView.selectedRange()
            parent.text = textView.string
            DispatchQueue.main.async {
                textView.textStorage?.setAttributedString(self.parent.makeAttributedText(textView.string))
                textView.setSelectedRange(selectedRange)
            }
        }
        
        func textDidEndEditing(_ notification: Notification) {
            parent.onEditingEnded?()
        }
    }
}

final class PlaceholderTextView: NSTextView {
    var placeholder: String = "Start writing your thoughts here..."

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        if string.isEmpty, let font = self.font {
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.firstLineHeadIndent = 18

            let attributes: [NSAttributedString.Key: Any] = [
                .foregroundColor: NSColor.tertiaryLabelColor,
                .font: NSFontManager.shared.convert(font, toHaveTrait: .italicFontMask),
                .paragraphStyle: paragraphStyle
            ]

            let inset = self.textContainerInset
            let rect = NSRect(x: inset.width + 4,
                              y: inset.height,
                              width: bounds.width - 2 * inset.width,
                              height: bounds.height - 2 * inset.height)
            (placeholder as NSString).draw(in: rect, withAttributes: attributes)
        }
    }
    
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.modifierFlags.contains(.command) {
            if self == self.window?.firstResponder {
                if event.charactersIgnoringModifiers == "s" {
                    self.window?.makeFirstResponder(nil)
                    return true
                }
            }
        }
        return super.performKeyEquivalent(with: event)
    }
}
