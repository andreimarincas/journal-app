//
//  FocusableTextView.swift
//  JournalApp
//
//  Created by Andrei Marincas on 13.04.2025.
//

import SwiftUI

class FocusableTextView: NSTextView {
    var pasteAsPlainText: Bool = false
    var onFocusGained: (() -> Void)?
    var onFocusLost: (() -> Void)?
    var undoAction: (() -> Void)?
    var redoAction: (() -> Void)?
    var toneCycleLeft: (() -> Void)?
    var toneCycleRight: (() -> Void)?
    var isHoveredNote: Bool = false
    var isActiveAINote: Bool = false
    
    override func becomeFirstResponder() -> Bool {
        let became = super.becomeFirstResponder()
        if became {
            onFocusGained?()
        }
        return became
    }
    
    override func resignFirstResponder() -> Bool {
        let resigns = super.resignFirstResponder()
        if resigns {
            onFocusLost?()
        }
        return resigns
    }
    
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.modifierFlags.contains(.command) {
            if self == self.window?.firstResponder {
                if event.charactersIgnoringModifiers == "z" {
                    undoAction?()
                    return true
                } else if event.charactersIgnoringModifiers == "Z" {
                    redoAction?()
                    return true
                } else if event.charactersIgnoringModifiers == "s" {
                    self.window?.makeFirstResponder(nil)
                    return true
                } else if event.charactersIgnoringModifiers == "\r" {
                    self.window?.makeFirstResponder(nil)
                    return true
                }
            }
        } else if isHoveredNote && isActiveAINote && self.window?.firstResponder !== self {
            if event.keyCode == 123 {
                toneCycleLeft?()
                return true
            } else if event.keyCode == 124 {
                toneCycleRight?()
                return true
            }
        }
        return super.performKeyEquivalent(with: event)
    }
    
    override func paste(_ sender: Any?) {
        if pasteAsPlainText, let string = NSPasteboard.general.string(forType: .string) {
            self.insertText(string, replacementRange: self.selectedRange())
        } else {
            super.paste(sender)
        }
    }
}
