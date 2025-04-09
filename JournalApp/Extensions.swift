//
//  Extensions.swift
//  JournalApp
//
//  Created by Andrei Marincas on 04.04.2025.
//

import SwiftUI

extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: .whitespacesAndNewlines)
                      .replacingOccurrences(of: "#", with: "")

        var int = UInt64()
        Scanner(string: hex).scanHexInt64(&int)

        let r, g, b, a: UInt64
        switch hex.count {
        case 6: // RGB (no alpha)
            (r, g, b, a) = (
                (int >> 16) & 0xFF,
                (int >> 8) & 0xFF,
                int & 0xFF,
                255
            )
        case 8: // RGBA
            (r, g, b, a) = (
                (int >> 24) & 0xFF,
                (int >> 16) & 0xFF,
                (int >> 8) & 0xFF,
                int & 0xFF
            )
        default:
            (r, g, b, a) = (255, 255, 255, 255)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
