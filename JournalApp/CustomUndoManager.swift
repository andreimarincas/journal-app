//
//  CustomUndoManager.swift
//  JournalApp
//
//  Created by Andrei Marincas on 04.04.2025.
//

import Foundation

final class CustomUndoManager: ObservableObject {
    private var undoStack: [String] = []
    private var redoStack: [String] = []
    private var debounceTimer: Timer?
    private var pendingChange: (previous: String, current: String)?
    private let debounceDelay: TimeInterval = 0.1

    func registerChange(previous: String, current: String) {
        guard previous != current else { return }

        pendingChange = (previous, current)
        debounceTimer?.invalidate()

        debounceTimer = Timer.scheduledTimer(withTimeInterval: debounceDelay, repeats: false) { [weak self] _ in
            guard let self = self, let change = self.pendingChange else { return }
            self.undoStack.append(change.previous)
            self.redoStack.removeAll()
            self.pendingChange = nil
        }
    }

    func undo(current: String) -> String? {
        debounceTimer?.invalidate()
        pendingChange = nil

        guard let last = undoStack.popLast() else { return nil }
        redoStack.append(current)
        return last
    }

    func redo(current: String) -> String? {
        debounceTimer?.invalidate()
        pendingChange = nil

        guard let next = redoStack.popLast() else { return nil }
        undoStack.append(current)
        return next
    }

    func reset() {
        debounceTimer?.invalidate()
        pendingChange = nil
        undoStack.removeAll()
        redoStack.removeAll()
    }
}
