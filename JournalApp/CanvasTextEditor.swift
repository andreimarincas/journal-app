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
            .paragraphStyle: paragraphStyle
        ]
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let textView = NSTextView()
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
        let attrText = NSAttributedString(string: text, attributes: textAttributes)
        textView.textStorage?.setAttributedString(attrText)

        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        if let textView = nsView.documentView as? NSTextView {
            if textView.string != text {
                let attrText = NSAttributedString(string: text, attributes: textAttributes)
                textView.textStorage?.setAttributedString(attrText)
                textView.selectedRange = NSMakeRange(0, 0)
            }
            textView.layoutManager?.ensureLayout(for: textView.textContainer!)
        }
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
