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
    var onEditingEnded: (() -> Void)? = nil
    let font: NSFont = .systemFont(ofSize: 15.5, weight: .regular)
    
    private var textAttributes: [NSAttributedString.Key : Any] {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 7
        paragraphStyle.paragraphSpacing = 9
        paragraphStyle.firstLineHeadIndent = 18
        paragraphStyle.paragraphSpacingBefore = 0
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
        textView.textContainerInset = NSSize(width: 2.5, height: 6)

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
        
        NotificationCenter.default.addObserver(forName: .scrollToNote, object: nil, queue: .main) { _ in
            scrollToEnd(textView)
        }
        
        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? NSTextView else { return }

        if textView.string != text {
            textView.textStorage?.setAttributedString(makeAttributedText(text))
            textView.selectedRange = NSMakeRange(0, 0)
        }

        textView.layoutManager?.ensureLayout(for: textView.textContainer!)
    }

    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: CanvasTextEditor
        weak var textView: NSTextView?

        init(_ parent: CanvasTextEditor) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = textView else { return }
            parent.text = textView.string
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
}
