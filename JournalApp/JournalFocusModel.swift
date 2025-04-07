//
//  JournalFocusModel.swift
//  JournalApp
//
//  Created by Andrei Marincas on 07.04.2025.
//

import Foundation
import Combine

class JournalFocusModel: ObservableObject {
    @Published var focusedNoteID: UUID?
    @Published var pinnedNoteID: UUID?
    weak var entry: JournalEntry?
    
    @ObservationIgnored var pendingChatMessage: String? = nil
    @ObservationIgnored var pendingChatMessageContext: ChatNoteContext?
    
    func clearChatFocus() {
        pendingChatMessage = nil
        pendingChatMessageContext = nil
        pinnedNoteID = nil
    }
}
