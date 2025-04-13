//
//  Notifications.swift
//  JournalApp
//
//  Created by Andrei Marincas on 10.04.2025.
//

import Foundation

extension Notification.Name {
    static let scrollToNote = Notification.Name("scrollToNote")
    static let noteCreatedFromChat = Notification.Name("noteCreatedFromChat")
    static let stopTypewriterAnimation = Notification.Name("stopTypewriterAnimation")
    static let textViewHeightDidChange = Notification.Name("textViewHeightDidChange")
    static let updateUndoRedoAvailability = Notification.Name("updateUndoRedoAvailability")
}
