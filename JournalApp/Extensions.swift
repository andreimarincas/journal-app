//
//  Extensions.swift
//  JournalApp
//
//  Created by Andrei Marincas on 04.04.2025.
//

extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
