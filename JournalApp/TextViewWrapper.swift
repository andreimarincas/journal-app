//
//  TextViewWrapper.swift
//  JournalApp
//
//  Created by Andrei Marincas on 12.04.2025.
//

import SwiftUI

struct TextViewWrapper: NSViewRepresentable {
    @Binding var text: String
    @Binding var height: CGFloat
    let shouldFocus: Bool
    let id: UUID
    let isDimmed: Bool
    let isHovered: Bool
    let toneCycleLeft: (() -> Void)?
    let toneCycleRight: (() -> Void)?
    let viewModel: JournalEntryViewModel
    @EnvironmentObject private var focusModel: JournalFocusModel
    let undoManager: CustomUndoManager
    private let paragraphSpacing: CGFloat = 6
    private let fixedHeight: CGFloat = JournalLayoutConstants.noteRowMinHeight
    private let notesFontSize: CGFloat = JournalLayoutConstants.notesFontSize
    
    func makeNSView(context: Context) -> NSTextView {
        let textView = FocusableTextView()
        textView.onFocusGained = {
            if focusModel.focusedNoteID != id {
                focusModel.focusedNoteID = id
            }
            if focusModel.pinnedNoteID != id {
                focusModel.clearChatFocus()
            }
        }
        textView.onFocusLost = {
            if focusModel.focusedNoteID == id {
                focusModel.focusedNoteID = nil
            }
        }
        textView.undoAction = {
            if let restored = undoManager.undo(current: text) {
                text = restored
                setAttrText(restored, to: textView)
            }
        }
        textView.redoAction = {
            if let restored = undoManager.redo(current: text) {
                text = restored
                setAttrText(restored, to: textView)
            }
        }
        textView.isEditable = true
        textView.isRichText = false
        setAttrText(text, to: textView)
        textView.font = NSFont.systemFont(ofSize: 15, weight: .regular)
        textView.drawsBackground = false
        textView.textContainerInset = NSSize(width: 22, height: 2)
        textView.textContainer?.widthTracksTextView = true
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.delegate = context.coordinator
        textView.pasteAsPlainText = true
        textView.toneCycleLeft = toneCycleLeft
        textView.toneCycleRight = toneCycleRight
        textView.isHoveredNote = isHovered
        textView.isActiveAINote = isDimmed
        textView.importsGraphics = false
        textView.allowsImageEditing = false
        textView.isRichText = false
        textView.smartInsertDeleteEnabled = false
        textView.usesRuler = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        
        if shouldFocus {
            DispatchQueue.main.async {
                textView.window?.makeFirstResponder(textView)
            }
        }
        
        return textView
    }

    func updateNSView(_ nsView: NSTextView, context: Context) {
        if let textView = nsView as? FocusableTextView {
            textView.isHoveredNote = isHovered
            textView.isActiveAINote = isDimmed
        }
        if nsView.string != text {
            setAttrText(text, to: nsView)
            nsView.layoutManager?.ensureLayout(for: nsView.textContainer!)
        }
        
        if let layoutManager = nsView.layoutManager,
           let textContainer = nsView.textContainer {
            layoutManager.ensureLayout(for: textContainer)
            let usedRect = layoutManager.usedRect(for: textContainer)
            DispatchQueue.main.async {
                height = shouldFocus ? max(usedRect.height + paragraphSpacing, fixedHeight) : fixedHeight
            }
        }
        DispatchQueue.main.async {
            nsView.invalidateIntrinsicContentSize()
            nsView.setNeedsDisplay(nsView.bounds)
        }
        
        DispatchQueue.main.async {
            if let firstResponder = nsView.window?.firstResponder, firstResponder == nsView {
                if focusModel.focusedNoteID != id {
                    focusModel.focusedNoteID = id
                }
            } else if shouldFocus {
                nsView.window?.makeFirstResponder(nsView)
            }
        }
    }
    
    func setAttrText(_ text: String, to nsView: NSTextView) {
        let dimmed = isDimmed// && nsView.window?.firstResponder != nsView
        let textColor = dimmed ? NSColor.secondaryLabelColor : NSColor.labelColor
        let baseFont = NSFont.systemFont(ofSize: notesFontSize, weight: .regular)
        let font = dimmed
            ? NSFontManager.shared.convert(baseFont, toHaveTrait: .italicFontMask)
            : baseFont
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineHeightMultiple = 1.3
        paragraphStyle.paragraphSpacing = 6

        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: textColor,
            .paragraphStyle: paragraphStyle
        ]
        let attributed = NSAttributedString(string: text, attributes: attrs)
        nsView.textStorage?.setAttributedString(attributed)
        nsView.typingAttributes = attrs
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, NSTextViewDelegate {
    var parent: TextViewWrapper

        init(_ parent: TextViewWrapper) {
            self.parent = parent
            super.init()
        }
        
        deinit {
            NotificationCenter.default.removeObserver(self)
        }
        
        @objc func textDidEndEditing(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            let trimmedText = textView.string.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedText.isEmpty {
                if let note = parent.viewModel.notes.first(where: { $0.id == parent.id }) {
                    parent.viewModel.deleteNote(note)
                    parent.focusModel.focusedNoteID = nil
                }
            } else {
                parent.text = trimmedText
            }
        }
        
        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            
            let oldText = parent.text
            let newText = textView.string
            
            if oldText != newText {
                parent.undoManager.registerChange(previous: oldText, current: newText)
                parent.text = newText
                
                // This forces the newly updated or pasted text to be immediately styled with your standard note font, spacing, and color, overriding any residual rich text attributes that might have been pasted or triggered during editing.
                parent.setAttrText(newText, to: textView)
            }
        }
    }
}
