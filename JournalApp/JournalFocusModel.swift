//
//  JournalFocusModel.swift
//  JournalApp
//
//  Created by Andrei Marincas on 07.04.2025.
//

import Foundation
import Combine
import SwiftUI

class JournalFocusModel: ObservableObject {
    @Published var focusedNoteID: UUID?
    @Published var pinnedNoteID: UUID?
    weak var entry: JournalEntry?
    weak var entryViewModel: JournalEntryViewModel?
    
    @ObservationIgnored var pendingChatMessage: String? = nil
    @ObservationIgnored var pendingChatMessageContext: ChatNoteContext?
    
    func clearChatFocus() {
        pendingChatMessage = nil
        pendingChatMessageContext = nil
        pinnedNoteID = nil
    }
    
    func clearNoteFocus() {
        if let responder = NSApp.keyWindow?.firstResponder as? FocusableTextView {
            responder.window?.makeFirstResponder(nil)
        }
        focusedNoteID = nil
    }
}
